// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

// MARK: - Error Types

enum FrameControllerError: Error {
    case cannotCloseRootFrame
    case frameNotInParent
}

@MainActor
class FrameController {
    let config: ConfigController
    let styleProvider: StyleProvider
    private let geometry: FrameGeometry
    let frameWindow: FrameWindowProtocol
    let windowStack: WindowStackController
    private let windowFactory: FrameWindowFactory

    var children: [FrameController] = []
    weak var parent: FrameController? = nil
    var splitDirection: Direction? = nil  // The direction this frame was split (if it has children)
    private var isActive: Bool = false

    var activeWindow: WindowControllerProtocol? {
        self.windowStack.activeWindow
    }

    func setActive(_ isActive: Bool) {
        self.isActive = isActive
        self.frameWindow.setActive(isActive)
    }

    /// Public initializer for production use
    init(rect: CGRect, config: ConfigController) {
        self.config = config
        self.styleProvider = StyleProvider()
        self.geometry = FrameGeometry(rect: rect, titleBarHeight: config.titleBarHeight)
        self.windowFactory = RealFrameWindowFactory(styleProvider: self.styleProvider)
        self.frameWindow = self.windowFactory.createFrameWindow(geometry: self.geometry)
        self.windowStack = WindowStackController(styleProvider: self.styleProvider)
    }

    /// Internal initializer for testing with custom window factory
    init(rect: CGRect, config: ConfigController, windowFactory: FrameWindowFactory) {
        self.config = config
        self.styleProvider = StyleProvider()
        self.geometry = FrameGeometry(rect: rect, titleBarHeight: config.titleBarHeight)
        self.windowFactory = windowFactory
        self.frameWindow = windowFactory.createFrameWindow(geometry: self.geometry)
        self.windowStack = WindowStackController(styleProvider: self.styleProvider)
    }

    /// Internal initializer for child frames created during split
    private init(geometry: FrameGeometry, config: ConfigController, windowFactory: FrameWindowFactory) {
        self.config = config
        self.styleProvider = StyleProvider()
        self.geometry = geometry
        self.windowFactory = windowFactory
        self.frameWindow = windowFactory.createFrameWindow(geometry: geometry)
        self.windowStack = WindowStackController(styleProvider: self.styleProvider)
    }

    func refreshOverlay() {
        if (self.children.isEmpty) {
            self.frameWindow.updateOverlay(tabs: self.windowStack.tabs)
        } else {
            self.frameWindow.clear()
            for child in self.children {
                child.refreshOverlay()
            }
        }
    }

    func addWindow(_ window: WindowControllerProtocol, shouldFocus: Bool = false) throws {
        window.frame = self  // Set the frame reference
        try self.windowStack.add(window, shouldFocus: shouldFocus)

        // resize window to frame size
        let targetRect = self.geometry.contentRect
        try window.resize(size: targetRect.size)
        try window.move(to: targetRect.origin)
    }

    func removeWindow(_ window: WindowControllerProtocol) -> Bool {
        let removed = self.windowStack.remove(window)
        if removed {
            window.frame = nil  // Clear the frame reference
        }
        return removed
    }

    func nextWindow() {
        self.windowStack.nextWindow()
        self.activeWindow?.raise()
        self.refreshOverlay()
    }

    func previousWindow() {
        self.windowStack.previousWindow()
        self.activeWindow?.raise()
        self.refreshOverlay()
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

    func takeWindowsFrom(_ other: FrameController) throws {
        // Transfer windows to this frame's stack
        try self.windowStack.takeAll(from: other.windowStack)

        // Update frame references for transferred windows
        for w in self.windowStack.all {
            w.frame = self
        }

        // Reposition all windows to fit this frame
        let targetRect = self.geometry.contentRect
        for w in self.windowStack.all {
            try w.resize(size: targetRect.size)
            try w.move(to: targetRect.origin)
        }
    }

    func split(direction: Direction) throws -> FrameController {
        precondition(self.children.isEmpty)

        let (geo1, geo2) = direction == .Horizontal
            ? self.geometry.splitHorizontally()
            : self.geometry.splitVertically()

        let child1 = FrameController(geometry: geo1, config: self.config, windowFactory: self.windowFactory)
        child1.parent = self
        let child2 = FrameController(geometry: geo2, config: self.config, windowFactory: self.windowFactory)
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

        // Get all windows to redistribute
        let windowsToMove = self.windowStack.all

        // Find sibling and index of this frame in parent
        let myIndex = parent.children.firstIndex(where: { $0 === self })
        guard let myIndex = myIndex else {
            throw FrameControllerError.frameNotInParent
        }

        // In a binary tree, we always have exactly 2 children (from the split)
        // So closing one child always means merging back to parent
        precondition(parent.children.count == 2)

        let sibling = parent.children[myIndex == 0 ? 1 : 0]

        // Parent takes windows from both children
        try parent.takeWindowsFrom(self)
        try parent.takeWindowsFrom(sibling)

        // Remove all children from parent (it's no longer split)
        parent.children.removeAll()
        parent.splitDirection = nil

        // Show parent frame and set active
        parent.frameWindow.show()
        parent.setActive(true)

        // Update frame references
        for window in windowsToMove {
            window.frame = parent
        }

        // Refresh overlay
        parent.refreshOverlay()

        return parent
    }

    func toString() -> String {
        return "Frame(rect=\(self.geometry.frameRect))"
    }

    static func fromScreen(_ screen: NSScreen, config: ConfigController) -> FrameController {
        let geometry = FrameGeometry.fromScreen(screen, titleBarHeight: config.titleBarHeight)
        let frame = FrameController(rect: geometry.frameRect, config: config)
        frame.setActive(true)
        return frame
    }
}
