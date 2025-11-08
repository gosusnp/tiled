// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

@MainActor
class FrameManager {
    let config: ConfigController
    var rootFrame: FrameController?
    var activeFrame: FrameController?

    private let navigationService: FrameNavigationService
    private let logger: Logger

    // Window controller mapping (keyed by stable WindowId, not stale AXUIElement)
    var windowControllerMap: [UUID: WindowControllerProtocol] = [:]

    // Command queue infrastructure
    private var commandQueue: [FrameCommand] = []
    private var isProcessing = false

    init(config: ConfigController, logger: Logger = Logger()) {
        self.config = config
        self.navigationService = FrameNavigationService()
        self.logger = logger
    }

    // MARK: - Initialization

    func initializeFromScreen(_ screen: NSScreen) {
        let geometry = FrameGeometry.fromScreen(screen, titleBarHeight: config.titleBarHeight)
        let frame = FrameController(rect: geometry.frameRect, config: config)
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
    }

    func splitVertically() throws {
        guard let current = activeFrame else { return }
        let newActive = try current.split(direction: .Vertical)
        activeFrame = newActive
    }

    func closeActiveFrame() throws {
        guard let current = activeFrame else { return }
        let newActive = try current.closeFrame()
        activeFrame = newActive
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
        guard let window = current.activeWindow else { return }
        guard let targetFrame = navigationService.findAdjacentFrame(from: current, direction: direction) else { return }

        try current.moveWindow(window, toFrame: targetFrame)
        updateActiveFrame(from: current, to: targetFrame)
    }

    // MARK: - Window Management

    func assignWindow(_ window: WindowController, shouldFocus: Bool = false) throws {
        guard let frame = activeFrame else { return }
        try frame.addWindow(window, shouldFocus: shouldFocus)
        frame.refreshOverlay()
    }

    func registerExistingWindow(_ window: WindowControllerProtocol, windowId: WindowId) {
        windowControllerMap[windowId.asKey()] = window
    }

    func unregisterWindow(windowId: WindowId) {
        windowControllerMap.removeValue(forKey: windowId.asKey())
    }

    func nextWindow() {
        activeFrame?.nextWindow()
    }

    func previousWindow() {
        activeFrame?.previousWindow()
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
        case .addWindow(let window):
            guard let frame = activeFrame else { return }
            try frame.addWindow(window, shouldFocus: false)
            frame.refreshOverlay()
        case .removeWindow(let window):
            let _ = activeFrame?.removeWindow(window)
            activeFrame?.refreshOverlay()
        case .focusWindow(let window):
            if let frame = window.frame {
                updateActiveFrame(from: activeFrame ?? rootFrame, to: frame)
            }
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
        new.activeWindow?.raise()
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
            try frame.addWindow(window, shouldFocus: true)
            frame.refreshOverlay()
        } catch {
            logger.warning("Failed to assign window: \(error)")
            windowControllerMap.removeValue(forKey: windowId.asKey())
        }
    }

    private func handleWindowDisappeared(_ windowId: WindowId) {
        guard let windowController = windowControllerMap[windowId.asKey()] else {
            logger.debug("Window disappeared but not found in map")
            return
        }

        guard let frame = windowController.frame else {
            logger.debug("Window has no frame (floating window)")
            windowControllerMap.removeValue(forKey: windowId.asKey())
            return
        }

        let wasActive = frame.activeWindow === windowController

        // Remove from frame
        frame.removeWindow(windowController)
        windowControllerMap.removeValue(forKey: windowId.asKey())
        frame.refreshOverlay()

        // Focus next window if this was active
        if wasActive, let newActive = frame.activeWindow {
            newActive.raise()
        }

        logger.debug("Window removed from frame")
    }
}
