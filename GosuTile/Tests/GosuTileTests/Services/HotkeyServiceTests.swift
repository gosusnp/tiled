// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import GosuTile

@Suite("HotkeyService Tests")
struct HotkeyServiceTests {
    let logger: Logger

    init() {
        self.logger = Logger()
    }

    @Test("Initializes with empty shortcuts")
    func testInitialization() {
        let service = HotkeyService(logger: logger)

        #expect(service.shortcuts.isEmpty)
        #expect(service.shortcuts.count == 0)
    }

    @Test("Adds a shortcut to the array")
    func testAddShortcut() {
        let service = HotkeyService(logger: logger)

        service.addShortcut(
            steps: [(.character("a"), .maskCommand)],
            description: "cmd+a: test",
            action: {}
        )

        #expect(service.shortcuts.count == 1)
        #expect(service.shortcuts[0].description == "cmd+a: test")
    }

    @Test("Adds multiple shortcuts")
    func testAddMultipleShortcuts() {
        let service = HotkeyService(logger: logger)

        service.addShortcut(
            steps: [(.character("a"), .maskCommand)],
            description: "cmd+a",
            action: {}
        )

        service.addShortcut(
            steps: [(.character("b"), .maskCommand)],
            description: "cmd+b",
            action: {}
        )

        #expect(service.shortcuts.count == 2)
        #expect(service.shortcuts[0].description == "cmd+a")
        #expect(service.shortcuts[1].description == "cmd+b")
    }

    @Test("Preserves shortcut properties")
    func testShortcutProperties() {
        let service = HotkeyService(logger: logger)

        service.addShortcut(
            steps: [
                (.character("g"), .maskCommand),
                (.character("n"), [])
            ],
            description: "cmd+g, n: next",
            action: {}
        )

        let shortcut = service.shortcuts[0]

        #expect(shortcut.description == "cmd+g, n: next")
        #expect(shortcut.steps.count == 2)
        #expect(shortcut.steps[0].key == .character("g"))
        #expect(shortcut.steps[0].modifiers == .maskCommand)
        #expect(shortcut.steps[1].key == .character("n"))
        #expect(shortcut.steps[1].modifiers == [])
    }
}
