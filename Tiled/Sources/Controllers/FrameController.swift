// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices
import Combine

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
    let geometry: FrameGeometry
    let frameWindow: FrameWindowProtocol
    let windowStack: WindowStackController
    var windowIds: [WindowId] {
        return self.windowStack.allWindowIds
    }
    private let windowFactory: FrameWindowFactory
    private let axHelper: AccessibilityAPIHelper

    var children: [FrameController] = []
    weak var parent: FrameController? = nil
    var splitDirection: Direction? = nil  // The direction this frame was split (if it has children)
    private var isActive: Bool = false

    @Published var windowTabs: [WindowTab] = []

    func setActive(_ isActive: Bool) {
        self.isActive = isActive
        self.frameWindow.setActive(isActive)
    }

    /// Compute current window tabs based on frame hierarchy
    /// For leaf frames: returns tabs with window titles
    /// For non-leaf frames: returns empty array (children own the display)
    private func computeWindowTabs() -> [WindowTab] {
        if self.children.isEmpty {
            // Leaf frame: convert WindowIds to WindowTabs for UI rendering
            return self.windowStack.tabs.enumerated().map { (index, windowId) in
                let isActive = index == self.windowStack.activeIndex
                let title = windowId.getCurrentElement().map{ (element) in axHelper.getWindowTitle(element) } ?? "Unknown"
                return WindowTab(title: title, isActive: isActive)
            }
        } else {
            // Non-leaf frame: children own the display
            return []
        }
    }

    /// Update the published windowTabs property based on current state
    private func updateWindowTabs() {
        self.windowTabs = computeWindowTabs()
        // State change is published via @Published; observer handles all UI updates
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
        setupObservers()
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
        setupObservers()
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
        setupObservers()
    }

    /// Setup observer bindings between FrameController and FrameWindow
    private func setupObservers() {
        // Cast to FrameWindow to access setFrameController if it's a real window
        if let frameWindow = self.frameWindow as? FrameWindow {
            frameWindow.setFrameController(self)
        }
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

    func addWindow(_ windowId: WindowId, shouldFocus: Bool = false) throws {
        try self.windowStack.add(windowId, shouldFocus: shouldFocus)
        self.updateWindowTabs()
    }

    func removeWindow(_ windowId: WindowId) -> Bool {
        let wasRemoved = self.windowStack.remove(windowId)
        if wasRemoved {
            self.updateWindowTabs()
        }
        return wasRemoved
    }

    func nextWindow() -> WindowId? {
        let windowId = self.windowStack.nextWindow()
        self.updateWindowTabs()
        return windowId
    }

    func previousWindow() -> WindowId? {
        let windowId = self.windowStack.previousWindow()
        self.updateWindowTabs()
        return windowId
    }

    func moveWindow(_ windowId: WindowId, toFrame targetFrame: FrameController) throws {
        // Remove from source frame
        guard self.removeWindow(windowId) else {
            return
        }

        // Add to target frame. Both removeWindow() and addWindow() trigger updateWindowTabs(),
        // which publishes state changes. Observers automatically react without explicit refresh calls.
        try targetFrame.addWindow(windowId, shouldFocus: true)
    }

    /// Check if a specific window is the active window in this frame
    func isActiveWindow(_ windowId: WindowId) -> Bool {
        return self.windowStack.isActiveWindow(windowId)
    }

    /// Move the active window to another frame
    func moveActiveWindow(to targetFrame: FrameController) throws -> WindowId? {
        guard let activeWindowId = self.windowStack.getActiveWindowId() else { return nil }

        try self.moveWindow(activeWindowId, toFrame: targetFrame)
        return activeWindowId
    }

    func takeWindowsFrom(_ other: FrameController) throws {
        // Transfer windows to this frame's stack
        try self.windowStack.takeAll(from: other.windowStack)
        self.updateWindowTabs()

        // Source frame's windows were transferred, so update its tabs
        other.updateWindowTabs()

        // TODO: After refactoring, we need to:
        // 1. Update frame references for transferred windows (via FrameManager.frameMap)
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

        // Publish state change (parent becomes non-leaf). Observer and clear() handle the UI transition.
        self.updateWindowTabs()

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
        // Transfer windows first without updating tabs (children still exist)
        try parent.takeWindowsFrom(self)
        try parent.takeWindowsFrom(sibling)

        // Remove all children from parent BEFORE updating tabs.
        // This is critical: updateWindowTabs() checks children.isEmpty to decide
        // whether to return tabs (leaf) or empty array (non-leaf).
        // We must clear children before calling updateWindowTabs() so the parent
        // transitions from non-leaf back to leaf state with populated tabs.
        parent.children.removeAll()
        parent.splitDirection = nil

        // Now that parent is a leaf again, update tabs to show consolidated windows
        parent.updateWindowTabs()

        // Show parent frame and set active
        parent.frameWindow.show()
        parent.setActive(true)

        // TODO: Update frame references for windows
        // Currently we only have WindowIds, not the actual WindowController objects.
        // This will be fixed when FrameController has access to FrameManager.

        // Parent's state was updated by takeWindowsFrom(). Observer automatically syncs the UI.

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

        // Remove all children from parent (including self) and reset split state.
        // Like in closeFrame(), we must clear children BEFORE updating tabs so the
        // parent transitions to leaf state with the consolidated windows visible.
        parent.children.removeAll()
        parent.splitDirection = nil

        // Clear self's parent reference to fully detach
        self.parent = nil

        // Now that parent is a leaf again, update tabs to show consolidated windows
        parent.updateWindowTabs()

        // Show parent frame and set as active
        parent.frameWindow.show()
        parent.setActive(true)

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
