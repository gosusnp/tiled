// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

@MainActor
class FrameManager {
    let config: ConfigController
    var rootFrame: FrameController?
    var activeFrame: FrameController?
    private let axHelper: AccessibilityAPIHelper

    private let navigationService: FrameNavigationService
    private let logger: Logger

    // Window controller mapping (keyed by stable WindowId, not stale AXUIElement)
    var windowControllerMap: [UUID: WindowControllerProtocol] = [:]

    // Frame mapping (reverse lookup: WindowId -> FrameController)
    // Maintained by FrameManager as single source of truth for window→frame relationships
    private var frameMap: [WindowId: FrameController] = [:]

    // Command queue infrastructure
    private var commandQueue: [FrameCommand] = []
    private var isProcessing = false

    init(config: ConfigController, logger: Logger = Logger(), axHelper: AccessibilityAPIHelper = DefaultAccessibilityAPIHelper()) {
        self.config = config
        self.navigationService = FrameNavigationService()
        self.logger = logger
        self.axHelper = axHelper
    }

    // MARK: - Initialization

    func initializeFromScreen(_ screen: NSScreen) {
        let geometry = FrameGeometry.fromScreen(screen, titleBarHeight: config.titleBarHeight)
        let frame = FrameController(rect: geometry.frameRect, config: config, axHelper:axHelper)
        frame.setActive(true)
        self.rootFrame = frame
        self.activeFrame = frame
    }

    // MARK: - Command Queue

    func enqueueCommand(_ command: FrameCommand) {
        commandQueue.append(command)
        if !isProcessing {
            Task { await processQueue() }
        }
    }

    private func processQueue() async {
        isProcessing = true
        defer { isProcessing = false }

        while !commandQueue.isEmpty {
            let command = commandQueue.removeFirst()
            // Placeholder: validateAndRepairState() will be implemented in Phase 4
            try? await executeCommand(command)
        }
    }


    // MARK: - Frame Operations

    func splitHorizontally() throws {
        guard let current = activeFrame else { return }
        let newActive = try current.split(direction: .Horizontal)
        activeFrame = newActive
        try snapFrameWindows(frame: newActive)
    }

    func splitVertically() throws {
        guard let current = activeFrame else { return }
        let newActive = try current.split(direction: .Vertical)
        activeFrame = newActive
        try snapFrameWindows(frame: newActive)
    }

    func closeActiveFrame() throws {
        guard let current = activeFrame else { return }
        let newActive = try current.closeFrame()
        activeFrame = newActive
        if (newActive != nil) {
            try snapFrameWindows(frame: newActive!)
        }
    }

    // MARK: - Navigation Operations

    func navigateLeft() {
        guard let current = activeFrame else { return }
        guard let next = navigationService.findAdjacentFrame(from: current, direction: .left) else { return }
        updateActiveFrame(from: current, to: next)
    }

    func navigateRight() {
        guard let current = activeFrame else { return }
        guard let next = navigationService.findAdjacentFrame(from: current, direction: .right) else { return }
        updateActiveFrame(from: current, to: next)
    }

    func navigateUp() {
        guard let current = activeFrame else { return }
        guard let next = navigationService.findAdjacentFrame(from: current, direction: .up) else { return }
        updateActiveFrame(from: current, to: next)
    }

    func navigateDown() {
        guard let current = activeFrame else { return }
        guard let next = navigationService.findAdjacentFrame(from: current, direction: .down) else { return }
        updateActiveFrame(from: current, to: next)
    }

    // MARK: - Move Window Operations

    func moveActiveWindowLeft() throws {
        try moveActiveWindow(direction: .left)
    }

    func moveActiveWindowRight() throws {
        try moveActiveWindow(direction: .right)
    }

    func moveActiveWindowUp() throws {
        try moveActiveWindow(direction: .up)
    }

    func moveActiveWindowDown() throws {
        try moveActiveWindow(direction: .down)
    }

    private func moveActiveWindow(direction: NavigationDirection) throws {
        guard let current = activeFrame else { return }
        guard let targetFrame = navigationService.findAdjacentFrame(from: current, direction: direction) else { return }

        guard let windowId = try current.moveActiveWindow(to: targetFrame) else { return }
        try snapWindowToFrame(windowId, frame: targetFrame)
        // Update frameMap to reflect window move to new frame
        frameMap[windowId] = targetFrame
        updateActiveFrame(from: current, to: targetFrame)
    }

    // MARK: - Window Management

    func assignWindow(_ window: WindowControllerProtocol, shouldFocus: Bool = false) throws {
        guard let frame = activeFrame else { return }
        try frame.addWindow(window.windowId, shouldFocus: shouldFocus)
        frameMap[window.windowId] = frame
        try snapWindowToFrame(window.windowId, frame: frame)
        // State change in frame.addWindow() triggers observer; no explicit UI refresh needed.
        // FrameManager is now decoupled from UI concerns and only manages frame operations.
    }

    func registerExistingWindow(_ window: WindowControllerProtocol, windowId: WindowId) {
        windowControllerMap[windowId.asKey()] = window
    }

    func unregisterWindow(windowId: WindowId) {
        windowControllerMap.removeValue(forKey: windowId.asKey())
        frameMap.removeValue(forKey: windowId)
    }

    func frameContaining(_ windowId: WindowId) -> FrameController? {
        frameMap[windowId]
    }

    func nextWindow() {
        let windowId = activeFrame?.nextWindow()
        raiseWindow(windowId)
    }

    func previousWindow() {
        let windowId = activeFrame?.previousWindow()
        raiseWindow(windowId)
    }

    // MARK: - Window Operations

    private func snapFrameWindows(frame: FrameController) throws {
        for windowId in frame.windowIds {
            try snapWindowToFrame(windowId, frame: frame)
        }
    }

    private func snapWindowToFrame(_ windowId: WindowId?, frame: FrameController) throws {
        guard let window = getWindow(windowId) else {
            // Window controller is missing - clean up all references
            cleanupMissingWindow(windowId, from: frame)
            return
        }

        // Reposition window to frame
        let targetRect = frame.geometry.contentRect
        try window.reposition(to: targetRect)
    }

    private func raiseWindow(_ windowId: WindowId?) {
        guard let window = getWindow(windowId) else {
            // Window controller is missing - clean up all references
            cleanupMissingWindow(windowId)
            return
        }
        window.raise()
    }

    private func getWindow(_ windowId: WindowId?) -> WindowControllerProtocol? {
        return windowId.flatMap { id in windowControllerMap[id.asKey()] }
    }

    /// Cleanup when a WindowId's controller is discovered to be missing.
    /// This ensures that when an operation discovers a window is gone (likely due to app exit),
    /// we clean up all references immediately rather than leaving inconsistent state.
    /// - Parameters:
    ///   - windowId: The WindowId whose controller was not found
    ///   - frame: Optional frame we know contains this window. If provided, we remove from it directly.
    ///            If not provided, we look it up in frameMap.
    private func cleanupMissingWindow(_ windowId: WindowId?, from frame: FrameController? = nil) {
        guard let windowId = windowId else { return }

        // Determine which frame owns this window
        let owningFrame = frame ?? frameMap[windowId]

        // Remove from frame's window stack
        if let owningFrame = owningFrame {
            _ = owningFrame.removeWindow(windowId)
        }

        // Remove from frameMap
        frameMap.removeValue(forKey: windowId)

        // Remove from windowControllerMap
        windowControllerMap.removeValue(forKey: windowId.asKey())
    }

    // MARK: - Command Execution

    private func executeCommand(_ command: FrameCommand) async throws {
        switch command {
        case .splitVertically:
            try splitVertically()
        case .splitHorizontally:
            try splitHorizontally()
        case .closeFrame:
            try closeActiveFrame()
        case .navigateLeft:
            navigateLeft()
        case .navigateRight:
            navigateRight()
        case .navigateUp:
            navigateUp()
        case .navigateDown:
            navigateDown()
        case .moveWindowLeft:
            try moveActiveWindowLeft()
        case .moveWindowRight:
            try moveActiveWindowRight()
        case .moveWindowUp:
            try moveActiveWindowUp()
        case .moveWindowDown:
            try moveActiveWindowDown()
        case .cycleWindowForward:
            nextWindow()
        case .cycleWindowBackward:
            previousWindow()
        case .shiftWindowLeft:
            activeFrame?.shiftActiveWindowLeft()
        case .shiftWindowRight:
            activeFrame?.shiftActiveWindowRight()
        case .addWindow(let window):
            guard let frame = activeFrame else { return }
            try frame.addWindow(window.windowId, shouldFocus: false)
            // State change triggers observer; no explicit UI refresh needed
        case .removeWindow(let window):
            let _ = activeFrame?.removeWindow(window.windowId)
            // State change triggers observer; no explicit UI refresh needed
        case .focusWindow:
            // TODO Implement
            return
        case .windowAppeared(let window, let windowId):
            handleWindowAppeared(window, windowId: windowId)
        case .windowDisappeared(let windowId):
            handleWindowDisappeared(windowId)
        }
    }

    // MARK: - Private Helpers

    private func updateActiveFrame(from old: FrameController?, to new: FrameController) {
        old?.setActive(false)
        new.setActive(true)
        activeFrame = new
    }

    // MARK: - Window Lifecycle Handlers

    private func handleWindowAppeared(_ window: WindowControllerProtocol, windowId: WindowId) {
        // Register in map
        windowControllerMap[windowId.asKey()] = window

        // Assign to active frame
        guard let frame = activeFrame else {
            logger.warning("No active frame to assign window to")
            windowControllerMap.removeValue(forKey: windowId.asKey())
            return
        }

        do {
            try frame.addWindow(windowId, shouldFocus: true)
            // Update frameMap to track window→frame relationship
            frameMap[windowId] = frame
            // Position window in its frame
            try snapWindowToFrame(windowId, frame: frame)
            // State change automatically triggers observer; UI stays in sync
        } catch {
            logger.warning("Failed to assign window: \(error)")
            windowControllerMap.removeValue(forKey: windowId.asKey())
        }
    }

    private func handleWindowDisappeared(_ windowId: WindowId) {
        guard let frame = frameMap[windowId] else {
            logger.debug("Window has no frame (floating window)")
            windowControllerMap.removeValue(forKey: windowId.asKey())
            frameMap.removeValue(forKey: windowId)
            return
        }

        let wasActive = frame.isActiveWindow(windowId)

        // Remove from frame. State change automatically triggers observer UI sync.
        let _ = frame.removeWindow(windowId)
        windowControllerMap.removeValue(forKey: windowId.asKey())
        frameMap.removeValue(forKey: windowId)

        if wasActive {
            // TODO We should raise the active window again because it changed and may no longer be on top
        }

        logger.debug("Window removed from frame")
    }
}
