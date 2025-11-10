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
                (.character(">"), [.maskCommand, .maskShift]),
            ],
            description: "cmd+shift+.: cycle next window in frame",
            action: {
                Task { @MainActor in
                    wm.nextWindow()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("<"), [.maskCommand, .maskShift]),
            ],
            description: "cmd+shift+,: cycle previous window in frame",
            action: {
                Task { @MainActor in
                    wm.previousWindow()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("s"), [.maskCommand , .maskShift]),
            ],
            description: "cmd+shift+s: split frame vertically",
            action: {
                Task { @MainActor in
                    try wm.splitVertically()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("v"), [.maskCommand, .maskShift]),
            ],
            description: "cmd+shift+v: split frame horizontally",
            action: {
                Task { @MainActor in
                    try wm.splitHorizontally()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("h"), [.maskCommand, .maskShift]),
            ],
            description: "cmd+shift+h: navigate to left frame",
            action: {
                Task { @MainActor in
                    wm.navigateLeft()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("j"), [.maskCommand, .maskShift]),
            ],
            description: "cmd+shift+j: navigate to bottom frame",
            action: {
                Task { @MainActor in
                    wm.navigateDown()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("k"), [.maskCommand, .maskShift]),
            ],
            description: "cmd+shift+k: navigate to top frame",
            action: {
                Task { @MainActor in
                    wm.navigateUp()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("l"), [.maskCommand, .maskShift]),
            ],
            description: "cmd+shift+l: navigate to right frame",
            action: {
                Task { @MainActor in
                    wm.navigateRight()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("c"), [.maskCommand, .maskShift]),
            ],
            description: "cmd+shift+c: close active frame",
            action: {
                Task { @MainActor in
                    try wm.closeActiveFrame()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("h"), [.maskCommand, .maskControl]),
            ],
            description: "cmd+ctrl+h: move active window to left frame",
            action: {
                Task { @MainActor in
                    try wm.moveActiveWindowLeft()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("j"), [.maskCommand, .maskControl]),
            ],
            description: "cmd+ctrl+j: move active window to bottom frame",
            action: {
                Task { @MainActor in
                    try wm.moveActiveWindowDown()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("k"), [.maskCommand, .maskControl]),
            ],
            description: "cmd+ctrl+k: move active window to top frame",
            action: {
                Task { @MainActor in
                    try wm.moveActiveWindowUp()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("l"), [.maskCommand, .maskControl]),
            ],
            description: "cmd+ctrl+l: move active window to right frame",
            action: {
                Task { @MainActor in
                    try wm.moveActiveWindowRight()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character(","), [.maskCommand, .maskControl]),
            ],
            description: "cmd+ctrl+,: shift active window left in frame",
            action: {
                Task { @MainActor in
                    try wm.shiftActiveWindowLeft()
                }
            }
        )

        service.addShortcut(
            steps: [
                (.character("."), [.maskCommand, .maskControl]),
            ],
            description: "cmd+ctrl+.: shift active window right in frame",
            action: {
                Task { @MainActor in
                    try wm.shiftActiveWindowRight()
                }
            }
        )
    }
}
