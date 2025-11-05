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

    func nextWindow() {
        activeFrame?.nextWindow()
    }

    func previousWindow() {
        activeFrame?.previousWindow()
    }

    // MARK: - Private Helpers

    private func updateActiveFrame(from old: FrameController, to new: FrameController) {
        old.setActive(false)
        new.setActive(true)
        activeFrame = new
        new.activeWindow?.raise()
    }
}
