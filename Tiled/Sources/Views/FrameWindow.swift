// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices
import Combine

@MainActor
class FrameWindow: FrameWindowProtocol {
    private var window: NSWindow
    private var titleBarView: FrameTitleBarView? {
        window.contentView as? FrameTitleBarView
    }

    // Observer pattern: weak reference to avoid retain cycles
    private weak var frameController: FrameController?
    private var cancellables = Set<AnyCancellable>()

    init(geo: FrameGeometry, styleProvider: StyleProvider) {
        let frame = FrameWindow.invertY(rect: geo.frameRect)
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Panel won't activate when shown
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false

        panel.contentView = FrameTitleBarView(geometry: geo, styleProvider: styleProvider)
        panel.orderFront(nil)

        self.window = panel
    }

    /// Set the frame controller and establish observer bindings
    /// This should be called by the factory or FrameController after creation
    func setFrameController(_ frameController: FrameController) {
        self.frameController = frameController
        setupBindings()
    }

    /// Setup Combine subscriptions to observe frameController's published state
    private func setupBindings() {
        guard let frameController = frameController else { return }

        // Subscribe to windowTabs changes
        frameController.$windowTabs
            .sink { [weak self] tabs in
                self?.updateOverlay(tabs: tabs)
            }
            .store(in: &cancellables)
    }

    /// Check if bindings are active (for testing)
    var hasActiveBindings: Bool {
        !cancellables.isEmpty
    }

    func updateOverlay(tabs: [WindowTab]) {
        self.titleBarView?.setupTabs(tabs: tabs)
    }

    func clear() {
        self.titleBarView?.setupTabs(tabs: [])
        self.titleBarView?.setActive(false)  // Show dimmed border for parent
    }

    func setActive(_ isActive: Bool) {
        self.titleBarView?.setActive(isActive)
    }

    func hide() {
        window.orderOut(nil)
    }

    func show() {
        window.orderFront(nil)
    }

    func close() {
        window.close()
    }

    deinit {
        window.close()
    }

    private static func invertY(rect: CGRect) -> NSRect {
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let convertedY = screenHeight - rect.origin.y - rect.size.height
        return NSRect(x: rect.origin.x, y: convertedY, width: rect.size.width, height: rect.size.height)
    }
}
