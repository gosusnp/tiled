// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

// MARK: - HotkeyController
class HotkeyController: ObservableObject, @unchecked Sendable {
    let service: HotkeyService
    private let windowManager: WindowManager

    init(windowManager: WindowManager, logger: Logger) {
        self.windowManager = windowManager
        self.service = HotkeyService(logger: logger)
        registerDefaultShortcuts()
    }

    deinit {
        service.stopMonitoring()
    }

    // MARK: - Register Shortcuts
    private func registerDefaultShortcuts() {
        let wm = self.windowManager

        service.addShortcut(
            steps: [
                (.character("g"), .maskCommand),
                (.character("n"), [])
            ],
            description: "cmd+g, n: next window",
            action: {
                Task { @MainActor in
                    wm.nextWindow()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("g"), .maskCommand),
                (.character("p"), [])
            ],
            description: "cmd+g, p: previous window",
            action: {
                Task { @MainActor in
                    wm.previousWindow()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("g"), .maskCommand),
                (.character("s"), [])
            ],
            description: "cmd+g, s: split frame vertically",
            action: {
                Task { @MainActor in
                    try wm.splitVertically()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("g"), .maskCommand),
                (.character("s"), .maskShift)
            ],
            description: "cmd+g, shift+s: split frame horizontally",
            action: {
                Task { @MainActor in
                    try wm.splitHorizontally()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("g"), .maskCommand),
                (.character("h"), [])
            ],
            description: "cmd+g, h: navigate to left frame",
            action: {
                Task { @MainActor in
                    wm.navigateLeft()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("g"), .maskCommand),
                (.character("j"), [])
            ],
            description: "cmd+g, j: navigate to bottom frame",
            action: {
                Task { @MainActor in
                    wm.navigateDown()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("g"), .maskCommand),
                (.character("k"), [])
            ],
            description: "cmd+g, k: navigate to top frame",
            action: {
                Task { @MainActor in
                    wm.navigateUp()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("g"), .maskCommand),
                (.character("l"), [])
            ],
            description: "cmd+g, l: navigate to right frame",
            action: {
                Task { @MainActor in
                    wm.navigateRight()
                }
            }
        )
    }
}
