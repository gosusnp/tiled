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
    }
}
