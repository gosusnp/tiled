// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import GosuTile

class MockStyleProvider: StyleProvider {}

@Suite("WindowStackController Tests")
@MainActor
struct WindowStackControllerTests {
    let mockStyleProvider = MockStyleProvider()

    @Test("Initializes with empty stack")
    func testInitialization() {
        let stack = WindowStackController(styleProvider: mockStyleProvider)

        #expect(stack.count == 0)
        #expect(stack.all.isEmpty)
        #expect(stack.activeIndex == 0)
        #expect(stack.activeWindow == nil)
    }

    @Test("Adds a window to the stack")
    func testAddWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let window = MockWindowController(title: "Window 1")

        try stack.add(window)

        #expect(stack.count == 1)
        #expect(stack.all.count == 1)
        #expect(stack.activeWindow === window)
    }

    @Test("Rejects duplicate windows")
    func testAddDuplicateWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let window = MockWindowController(title: "Window 1")

        try stack.add(window)

        // Try to add the same window again - should throw
        do {
            try stack.add(window)
            Issue.record("Expected WindowStackError but no error was thrown")
        } catch let error as WindowStackError {
            #expect(error == .duplicateWindow)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Cycles to next window")
    func testNextWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        try stack.add(window1)
        try stack.add(window2)
        try stack.add(window3)

        #expect(stack.activeIndex == 0)
        #expect(stack.activeWindow === window1)

        stack.nextWindow()
        #expect(stack.activeIndex == 1)
        #expect(stack.activeWindow === window2)

        stack.nextWindow()
        #expect(stack.activeIndex == 2)
        #expect(stack.activeWindow === window3)

        // Wraps around
        stack.nextWindow()
        #expect(stack.activeIndex == 0)
        #expect(stack.activeWindow === window1)
    }

    @Test("Cycles to previous window")
    func testPreviousWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        try stack.add(window1)
        try stack.add(window2)
        try stack.add(window3)

        #expect(stack.activeIndex == 0)

        stack.previousWindow()
        #expect(stack.activeIndex == 2)
        #expect(stack.activeWindow === window3)

        stack.previousWindow()
        #expect(stack.activeIndex == 1)
        #expect(stack.activeWindow === window2)

        stack.previousWindow()
        #expect(stack.activeIndex == 0)
        #expect(stack.activeWindow === window1)
    }

    @Test("Removes a window and adjusts activeIndex")
    func testRemoveWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        try stack.add(window1)
        try stack.add(window2)
        try stack.add(window3)

        #expect(stack.count == 3)
        #expect(stack.activeIndex == 0)

        // Remove the first window
        let removed = stack.remove(window1)
        #expect(removed)
        #expect(stack.count == 2)
        #expect(stack.activeIndex == 0)
        #expect(stack.activeWindow === window2)
    }

    @Test("Removes middle window and adjusts activeIndex")
    func testRemoveMiddleWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        try stack.add(window1)
        try stack.add(window2)
        try stack.add(window3)

        stack.nextWindow()
        stack.nextWindow()
        #expect(stack.activeIndex == 2)

        // Remove middle window
        let removed = stack.remove(window2)
        #expect(removed)
        #expect(stack.count == 2)
        #expect(stack.activeIndex == 1) // Decremented because removed index < activeIndex
        #expect(stack.activeWindow === window3)
    }

    @Test("Handles removing last window with activeIndex adjustment")
    func testRemoveLastWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try stack.add(window1)
        try stack.add(window2)

        stack.nextWindow()
        #expect(stack.activeIndex == 1)

        // Remove the active window (last one)
        let removed = stack.remove(window2)
        #expect(removed)
        #expect(stack.count == 1)
        #expect(stack.activeIndex == 0) // Adjusted to valid index
        #expect(stack.activeWindow === window1)
    }

    @Test("Returns false when removing non-existent window")
    func testRemoveNonExistentWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try stack.add(window1)

        let removed = stack.remove(window2)
        #expect(!removed)
        #expect(stack.count == 1)
        #expect(stack.activeWindow === window1)
    }

    @Test("nextWindow does nothing on empty stack")
    func testNextWindowOnEmpty() {
        let stack = WindowStackController(styleProvider: mockStyleProvider)

        stack.nextWindow()
        #expect(stack.activeIndex == 0)
        #expect(stack.activeWindow == nil)
    }

    @Test("previousWindow does nothing on empty stack")
    func testPreviousWindowOnEmpty() {
        let stack = WindowStackController(styleProvider: mockStyleProvider)

        stack.previousWindow()
        #expect(stack.activeIndex == 0)
        #expect(stack.activeWindow == nil)
    }

    @Test("Returns correct activeWindow when stack has one window")
    func testActiveWindowWithSingleWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let window = MockWindowController(title: "Window 1")

        try stack.add(window)

        #expect(stack.activeWindow === window)
        #expect(stack.activeIndex == 0)
    }

    @Test("Takes all windows from one stack to another")
    func testTakeAll() throws {
        let sourceStack = WindowStackController(styleProvider: mockStyleProvider)
        let targetStack = WindowStackController(styleProvider: mockStyleProvider)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        try sourceStack.add(window1)
        try sourceStack.add(window2)
        try sourceStack.add(window3)

        // Take all from source to target
        try targetStack.takeAll(from: sourceStack)

        // Verify target has all windows
        #expect(targetStack.count == 3)
        #expect(targetStack.all.count == 3)
        #expect(targetStack.all[0] === window1)
        #expect(targetStack.all[1] === window2)
        #expect(targetStack.all[2] === window3)
    }

    @Test("Clears source stack after takeAll")
    func testTakeAllClearsSource() throws {
        let sourceStack = WindowStackController(styleProvider: mockStyleProvider)
        let targetStack = WindowStackController(styleProvider: mockStyleProvider)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try sourceStack.add(window1)
        try sourceStack.add(window2)

        #expect(sourceStack.count == 2)

        try targetStack.takeAll(from: sourceStack)

        // Verify source is empty
        #expect(sourceStack.count == 0)
        #expect(sourceStack.all.isEmpty)
        #expect(sourceStack.activeIndex == 0)
        #expect(sourceStack.activeWindow == nil)
    }

    @Test("TakeAll with target stack that already has windows")
    func testTakeAllToNonEmptyTarget() throws {
        let sourceStack = WindowStackController(styleProvider: mockStyleProvider)
        let targetStack = WindowStackController(styleProvider: mockStyleProvider)
        let existing = MockWindowController(title: "Existing")
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        // Target already has a window
        try targetStack.add(existing)

        // Source has windows to take
        try sourceStack.add(window1)
        try sourceStack.add(window2)

        try targetStack.takeAll(from: sourceStack)

        // Verify target has all windows (existing + moved)
        #expect(targetStack.count == 3)
        #expect(targetStack.all[0] === existing)
        #expect(targetStack.all[1] === window1)
        #expect(targetStack.all[2] === window2)

        // Verify source is empty
        #expect(sourceStack.count == 0)
    }

    @Test("Adding window with shouldFocus=true makes it active")
    func testAddWindowWithFocus() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try stack.add(window1)
        #expect(stack.activeIndex == 0)
        #expect(stack.activeWindow === window1)

        // Add second window with shouldFocus=true
        try stack.add(window2, shouldFocus: true)
        #expect(stack.activeIndex == 1)
        #expect(stack.activeWindow === window2)
    }

    @Test("Adding window with shouldFocus=false keeps previous active")
    func testAddWindowWithoutFocus() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try stack.add(window1)
        #expect(stack.activeIndex == 0)
        #expect(stack.activeWindow === window1)

        // Add second window with shouldFocus=false (default)
        try stack.add(window2, shouldFocus: false)
        #expect(stack.activeIndex == 0)
        #expect(stack.activeWindow === window1)
        #expect(stack.count == 2)
    }
}
