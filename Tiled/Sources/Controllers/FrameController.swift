// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

// MARK: - Error Types

enum FrameControllerError: Error {
    case cannotCloseRootFrame
    case frameNotInParent
    case cannotSplitNonLeafFrame
    case cannotAddWindowWithoutId
}

@MainActor
class FrameController {
    let config: ConfigController
    let styleProvider: StyleProvider
    private let geometry: FrameGeometry
    let frameWindow: FrameWindowProtocol
    let windowStack: WindowStackController
    private let windowFactory: FrameWindowFactory
    private let axHelper: AccessibilityAPIHelper

    // Map WindowId to WindowControllerProtocol for operations that need the controller
    private var windowMap: [WindowId: WindowControllerProtocol] = [:]

    var children: [FrameController] = []
    weak var parent: FrameController? = nil
    var splitDirection: Direction? = nil  // The direction this frame was split (if it has children)
    private var isActive: Bool = false

    func setActive(_ isActive: Bool) {
        self.isActive = isActive
        self.frameWindow.setActive(isActive)
    }

    /// Public initializer for production use
    init(rect: CGRect, config: ConfigController, axHelper: AccessibilityAPIHelper) {
        self.config = config
        self.styleProvider = StyleProvider()
        self.geometry = FrameGeometry(rect: rect, titleBarHeight: config.titleBarHeight)
        self.windowFactory = RealFrameWindowFactory(styleProvider: self.styleProvider)
        self.frameWindow = self.windowFactory.createFrameWindow(geometry: self.geometry)
        self.windowStack = WindowStackController(styleProvider: self.styleProvider)
        self.axHelper = axHelper
    }

    /// Internal initializer for testing with custom window factory
    init(rect: CGRect, config: ConfigController, windowFactory: FrameWindowFactory, axHelper: AccessibilityAPIHelper) {
        self.config = config
        self.styleProvider = StyleProvider()
        self.geometry = FrameGeometry(rect: rect, titleBarHeight: config.titleBarHeight)
        self.windowFactory = windowFactory
        self.frameWindow = windowFactory.createFrameWindow(geometry: self.geometry)
        self.windowStack = WindowStackController(styleProvider: self.styleProvider)
        self.axHelper = axHelper
    }

    /// Internal initializer for child frames created during split
    private init(geometry: FrameGeometry, config: ConfigController, windowFactory: FrameWindowFactory, axHelper: AccessibilityAPIHelper) {
        self.config = config
        self.styleProvider = StyleProvider()
        self.geometry = geometry
        self.windowFactory = windowFactory
        self.frameWindow = windowFactory.createFrameWindow(geometry: geometry)
        self.windowStack = WindowStackController(styleProvider: self.styleProvider)
        self.axHelper = axHelper
    }

    func refreshOverlay() {
        if (self.children.isEmpty) {
            // Convert WindowIds to WindowTabs for UI rendering
            let tabs = self.windowStack.tabs.enumerated().map { (index, windowId) in
                let isActive = index == self.windowStack.activeIndex
                let title = windowId.getCurrentElement().map{ (element) in axHelper.getWindowTitle(element) } ?? "Unknown"
                return WindowTab(title: title, isActive: isActive)
            }
            self.frameWindow.updateOverlay(tabs: tabs)
        } else {
            self.frameWindow.clear()
            for child in self.children {
                child.refreshOverlay()
            }
        }
    }

    func addWindow(_ window: WindowControllerProtocol, shouldFocus: Bool = false) throws {
        // Get WindowId from the window controller
        let windowId = window.windowId

        try self.windowStack.add(windowId, shouldFocus: shouldFocus)
        self.windowMap[windowId] = window

        // resize window to frame size
        let targetRect = self.geometry.contentRect
        try window.resize(size: targetRect.size)
        try window.move(to: targetRect.origin)
    }

    func removeWindow(_ window: WindowControllerProtocol) -> Bool {
        let windowId = window.windowId

        let removed = self.windowStack.remove(windowId)
        if removed {
            self.windowMap.removeValue(forKey: windowId)
        }
        return removed
    }

    func nextWindow() -> WindowId? {
        let windowId = self.windowStack.nextWindow()
        self.refreshOverlay()
        return windowId
    }

    func previousWindow() -> WindowId? {
        let windowId = self.windowStack.previousWindow()
        self.refreshOverlay()
        return windowId
    }

    func moveWindow(_ window: WindowControllerProtocol, toFrame targetFrame: FrameController) throws {
        // Remove from source frame
        guard self.removeWindow(window) else {
            return
        }

        // Add to target frame
        try targetFrame.addWindow(window, shouldFocus: true)

        // Refresh both frames
        self.refreshOverlay()
        targetFrame.refreshOverlay()
    }

    /// Check if a specific window is the active window in this frame
    func isActiveWindow(_ window: WindowControllerProtocol) -> Bool {
        let windowId = window.windowId
        return self.windowStack.isActiveWindow(windowId)
    }

    /// Move the active window to another frame
    func moveActiveWindow(to targetFrame: FrameController) throws {
        guard let activeWindowId = self.windowStack.getActiveWindowId() else { return }
        guard let window = self.windowMap[activeWindowId] else { return }

        try self.moveWindow(window, toFrame: targetFrame)
    }

    /// Raise the active window in this frame
    func raiseActiveWindow() {
        // TODO looks like we're no longer doing anything here
        guard let activeWindowId = self.windowStack.getActiveWindowId() else {
            self.refreshOverlay()
            return
        }
        // Note: We need the actual WindowController to raise it. This will be resolved when
        // we refactor to get windows from FrameManager. For now, call refreshOverlay only.
        self.refreshOverlay()
    }

    func takeWindowsFrom(_ other: FrameController) throws {
        // Transfer windows to this frame's stack
        try self.windowStack.takeAll(from: other.windowStack)

        // Transfer window references from other frame's windowMap
        for (windowId, window) in other.windowMap {
            self.windowMap[windowId] = window
        }
        other.windowMap.removeAll()

        // TODO: After refactoring, we need to:
        // 1. Update frame references for transferred windows
        // 2. Reposition all windows to fit this frame
    }

    func split(direction: Direction) throws -> FrameController {
        guard self.children.isEmpty else {
            throw FrameControllerError.cannotSplitNonLeafFrame
        }

        let (geo1, geo2) = direction == .Horizontal
            ? self.geometry.splitHorizontally()
            : self.geometry.splitVertically()

        let child1 = FrameController(geometry: geo1, config: self.config, windowFactory: self.windowFactory, axHelper: self.axHelper)
        child1.parent = self
        let child2 = FrameController(geometry: geo2, config: self.config, windowFactory: self.windowFactory, axHelper: self.axHelper)
        child2.parent = self
        self.children = [child1, child2]
        self.splitDirection = direction

        try child1.takeWindowsFrom(self)

        // Manage active states
        child1.setActive(true)
        child2.setActive(false)

        // Hide parent frame's window since children now own the space
        self.frameWindow.hide()

        self.refreshOverlay()
        return child1
    }

    /// Close this frame and redistribute its windows
    /// - Returns: The frame that should become active after close
    /// - Throws: If this is the root frame and only frame left
    func closeFrame() throws -> FrameController? {
        // Can't close if this is the root frame
        guard let parent = self.parent else {
            throw FrameControllerError.cannotCloseRootFrame
        }

        // Get all window IDs to redistribute
        let windowIdsToMove = self.windowStack.allWindowIds

        // Find sibling and index of this frame in parent
        let myIndex = parent.children.firstIndex(where: { $0 === self })
        guard let myIndex = myIndex else {
            throw FrameControllerError.frameNotInParent
        }

        // In a binary tree, we should have exactly 2 children (from the split)
        // If tree is inconsistent, recover by merging all children
        if parent.children.count != 2 {
            return recoverFromInconsistentTree(parent: parent)
        }

        let sibling = parent.children[myIndex == 0 ? 1 : 0]

        // Normal case: binary tree with 2 children
        try parent.takeWindowsFrom(self)
        try parent.takeWindowsFrom(sibling)

        // Remove all children from parent (it's no longer split)
        parent.children.removeAll()
        parent.splitDirection = nil

        // Show parent frame and set active
        parent.frameWindow.show()
        parent.setActive(true)

        // TODO: Update frame references for windows
        // Currently we only have WindowIds, not the actual WindowController objects.
        // This will be fixed when FrameController has access to FrameManager.

        // Refresh overlay
        parent.refreshOverlay()

        return parent
    }

    /// Recovery mechanism: when tree is inconsistent, consolidate all children's windows into parent
    /// This ensures the tree returns to a valid state even if corruption occurred.
    private func recoverFromInconsistentTree(parent: FrameController) -> FrameController? {
        // Take windows from this frame (being closed)
        do {
            try parent.takeWindowsFrom(self)
        } catch {
            // If we can't even take windows, the tree is too corrupted to recover
            return nil
        }

        // Take windows from all other children
        for child in parent.children where child !== self {
            do {
                try parent.takeWindowsFrom(child)
            } catch {
                // Log but continue - we've at least saved some windows
                continue
            }
        }

        // Remove all children from parent (including self) and reset split state
        // This properly closes all frames and returns tree to leaf state
        parent.children.removeAll()
        parent.splitDirection = nil

        // Clear self's parent reference to fully detach
        self.parent = nil

        // Show parent frame and set as active
        parent.frameWindow.show()
        parent.setActive(true)

        // Refresh to reflect consolidated state
        parent.refreshOverlay()

        return parent
    }

    func toString() -> String {
        return "Frame(rect=\(self.geometry.frameRect))"
    }

    static func fromScreen(_ screen: NSScreen, config: ConfigController, axHelper: AccessibilityAPIHelper) -> FrameController {
        let geometry = FrameGeometry.fromScreen(screen, titleBarHeight: config.titleBarHeight)
        let frame = FrameController(rect: geometry.frameRect, config: config, axHelper: axHelper)
        frame.setActive(true)
        return frame
    }
}
