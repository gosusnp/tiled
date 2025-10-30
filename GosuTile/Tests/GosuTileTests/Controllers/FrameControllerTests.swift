// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import GosuTile

@Suite("FrameController Tests")
@MainActor
struct FrameControllerTests {
    let config: ConfigController
    let testFrame: CGRect

    init() {
        self.config = ConfigController()
        self.testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    @Test("Creates a frame controller from rect")
    func testFrameControllerInitialization() {
        let frameController = FrameController(rect: testFrame, config: config)

        #expect(frameController.windowStack.count == 0)
        #expect(frameController.children.isEmpty)
        #expect(frameController.windowStack.activeIndex == 0)
        #expect(frameController.activeWindow == nil)
    }

    @Test("nextWindow delegates to windowStack")
    func testNextWindow() throws {
        let frameController = FrameController(rect: testFrame, config: config)

        // Add windows directly to stack to avoid AX calls
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        try frameController.windowStack.add(window1)
        try frameController.windowStack.add(window2)

        #expect(frameController.activeWindow === window1)

        frameController.nextWindow()
        #expect(frameController.activeWindow === window2)

        frameController.nextWindow()
        #expect(frameController.activeWindow === window1)
    }

    @Test("previousWindow delegates to windowStack")
    func testPreviousWindow() throws {
        let frameController = FrameController(rect: testFrame, config: config)

        // Add windows directly to stack to avoid AX calls
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        try frameController.windowStack.add(window1)
        try frameController.windowStack.add(window2)

        #expect(frameController.activeWindow === window1)

        frameController.previousWindow()
        #expect(frameController.activeWindow === window2)

        frameController.previousWindow()
        #expect(frameController.activeWindow === window1)
    }

    @Test("Split creates child frames")
    func testSplit() throws {
        let frameController = FrameController(rect: testFrame, config: config)

        // Split with empty frame (no windows to transfer)
        try frameController.split(direction: .Horizontal)

        #expect(frameController.children.count == 2)
        #expect(frameController.windowStack.count == 0)
    }

    @Test("activeWindow reflects windowStack state")
    func testActiveWindowDelegation() {
        let frameController = FrameController(rect: testFrame, config: config)

        #expect(frameController.activeWindow == nil)
        #expect(frameController.activeWindow === frameController.windowStack.activeWindow)
    }
}
