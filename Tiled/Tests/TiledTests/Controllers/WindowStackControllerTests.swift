// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

class MockStyleProvider: StyleProvider {}

@Suite("WindowStackController Tests")
@MainActor
struct WindowStackControllerTests {
    let mockStyleProvider = MockStyleProvider()
    let mockRegistry = MockWindowRegistry()

    @Test("Initializes with empty stack")
    func testInitialization() {
        let stack = WindowStackController(styleProvider: mockStyleProvider)

        #expect(stack.count == 0)
        #expect(stack.allWindowIds.isEmpty)
        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() == nil)
    }

    @Test("Adds a window to the stack")
    func testAddWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId = WindowId(appPID: 1234, registry: mockRegistry)

        try stack.add(windowId)

        #expect(stack.count == 1)
        #expect(stack.allWindowIds.count == 1)
        #expect(stack.getActiveWindowId() === windowId)
    }

    @Test("Rejects duplicate windows")
    func testAddDuplicateWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId = WindowId(appPID: 1234, registry: mockRegistry)

        try stack.add(windowId)

        // Try to add the same window again - should throw
        do {
            try stack.add(windowId)
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
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)
        let windowId3 = WindowId(appPID: 1236, registry: mockRegistry)

        try stack.add(windowId1)
        try stack.add(windowId2)
        try stack.add(windowId3)

        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() === windowId1)

        var actualWindowId: WindowId?

        actualWindowId = stack.nextWindow()
        #expect(actualWindowId == windowId2)
        #expect(stack.activeIndex == 1)
        #expect(stack.getActiveWindowId() === windowId2)

        actualWindowId = stack.nextWindow()
        #expect(actualWindowId == windowId3)
        #expect(stack.activeIndex == 2)
        #expect(stack.getActiveWindowId() === windowId3)

        // Wraps around
        actualWindowId = stack.nextWindow()
        #expect(actualWindowId == windowId1)
        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() === windowId1)
    }

    @Test("Cycles to previous window")
    func testPreviousWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)
        let windowId3 = WindowId(appPID: 1236, registry: mockRegistry)

        try stack.add(windowId1)
        try stack.add(windowId2)
        try stack.add(windowId3)

        #expect(stack.activeIndex == 0)

        var actualWindowId: WindowId?

        actualWindowId = stack.previousWindow()
        #expect(actualWindowId == windowId3)
        #expect(stack.activeIndex == 2)
        #expect(stack.getActiveWindowId() === windowId3)

        actualWindowId = stack.previousWindow()
        #expect(actualWindowId == windowId2)
        #expect(stack.activeIndex == 1)
        #expect(stack.getActiveWindowId() === windowId2)

        actualWindowId = stack.previousWindow()
        #expect(actualWindowId == windowId1)
        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() === windowId1)
    }

    @Test("Removes a window and adjusts activeIndex")
    func testRemoveWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)
        let windowId3 = WindowId(appPID: 1236, registry: mockRegistry)

        try stack.add(windowId1)
        try stack.add(windowId2)
        try stack.add(windowId3)

        #expect(stack.count == 3)
        #expect(stack.activeIndex == 0)

        // Remove the first window
        let removed = stack.remove(windowId1)
        #expect(removed)
        #expect(stack.count == 2)
        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() === windowId2)
    }

    @Test("Removes middle window and adjusts activeIndex")
    func testRemoveMiddleWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)
        let windowId3 = WindowId(appPID: 1236, registry: mockRegistry)

        try stack.add(windowId1)
        try stack.add(windowId2)
        try stack.add(windowId3)

        stack.nextWindow()
        stack.nextWindow()
        #expect(stack.activeIndex == 2)

        // Remove middle window
        let removed = stack.remove(windowId2)
        #expect(removed)
        #expect(stack.count == 2)
        #expect(stack.activeIndex == 1) // Decremented because removed index < activeIndex
        #expect(stack.getActiveWindowId() === windowId3)
    }

    @Test("Handles removing last window with activeIndex adjustment")
    func testRemoveLastWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)

        try stack.add(windowId1)
        try stack.add(windowId2)

        stack.nextWindow()
        #expect(stack.activeIndex == 1)

        // Remove the active window (last one)
        let removed = stack.remove(windowId2)
        #expect(removed)
        #expect(stack.count == 1)
        #expect(stack.activeIndex == 0) // Adjusted to valid index
        #expect(stack.getActiveWindowId() === windowId1)
    }

    @Test("Returns false when removing non-existent window")
    func testRemoveNonExistentWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)

        try stack.add(windowId1)

        let removed = stack.remove(windowId2)
        #expect(!removed)
        #expect(stack.count == 1)
        #expect(stack.getActiveWindowId() === windowId1)
    }

    @Test("nextWindow does nothing on empty stack")
    func testNextWindowOnEmpty() {
        let stack = WindowStackController(styleProvider: mockStyleProvider)

        stack.nextWindow()
        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() == nil)
    }

    @Test("previousWindow does nothing on empty stack")
    func testPreviousWindowOnEmpty() {
        let stack = WindowStackController(styleProvider: mockStyleProvider)

        stack.previousWindow()
        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() == nil)
    }

    @Test("Returns correct activeWindow when stack has one window")
    func testActiveWindowWithSingleWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId = WindowId(appPID: 1234, registry: mockRegistry)

        try stack.add(windowId)

        #expect(stack.getActiveWindowId() === windowId)
        #expect(stack.activeIndex == 0)
    }

    @Test("Takes all windows from one stack to another")
    func testTakeAll() throws {
        let sourceStack = WindowStackController(styleProvider: mockStyleProvider)
        let targetStack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)
        let windowId3 = WindowId(appPID: 1236, registry: mockRegistry)

        try sourceStack.add(windowId1)
        try sourceStack.add(windowId2)
        try sourceStack.add(windowId3)

        // Take all from source to target
        try targetStack.takeAll(from: sourceStack)

        // Verify target has all windows
        #expect(targetStack.count == 3)
        #expect(targetStack.allWindowIds.count == 3)
        #expect(targetStack.allWindowIds[0] === windowId1)
        #expect(targetStack.allWindowIds[1] === windowId2)
        #expect(targetStack.allWindowIds[2] === windowId3)
    }

    @Test("Clears source stack after takeAll")
    func testTakeAllClearsSource() throws {
        let sourceStack = WindowStackController(styleProvider: mockStyleProvider)
        let targetStack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)

        try sourceStack.add(windowId1)
        try sourceStack.add(windowId2)

        #expect(sourceStack.count == 2)

        try targetStack.takeAll(from: sourceStack)

        // Verify source is empty
        #expect(sourceStack.count == 0)
        #expect(sourceStack.allWindowIds.isEmpty)
        #expect(sourceStack.activeIndex == 0)
        #expect(sourceStack.getActiveWindowId() == nil)
    }

    @Test("TakeAll with target stack that already has windows")
    func testTakeAllToNonEmptyTarget() throws {
        let sourceStack = WindowStackController(styleProvider: mockStyleProvider)
        let targetStack = WindowStackController(styleProvider: mockStyleProvider)
        let existing = WindowId(appPID: 9999, registry: mockRegistry)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)

        // Target already has a window
        try targetStack.add(existing)

        // Source has windows to take
        try sourceStack.add(windowId1)
        try sourceStack.add(windowId2)

        try targetStack.takeAll(from: sourceStack)

        // Verify target has all windows (existing + moved)
        #expect(targetStack.count == 3)
        #expect(targetStack.allWindowIds[0] === existing)
        #expect(targetStack.allWindowIds[1] === windowId1)
        #expect(targetStack.allWindowIds[2] === windowId2)

        // Verify source is empty
        #expect(sourceStack.count == 0)
    }

    @Test("Adding window with shouldFocus=true makes it active")
    func testAddWindowWithFocus() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)

        try stack.add(windowId1)
        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() === windowId1)

        // Add second window with shouldFocus=true
        try stack.add(windowId2, shouldFocus: true)
        #expect(stack.activeIndex == 1)
        #expect(stack.getActiveWindowId() === windowId2)
    }

    @Test("Adding window with shouldFocus=false keeps previous active")
    func testAddWindowWithoutFocus() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)

        try stack.add(windowId1)
        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() === windowId1)

        // Add second window with shouldFocus=false (default)
        try stack.add(windowId2, shouldFocus: false)
        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() === windowId1)
        #expect(stack.count == 2)
    }

    @Test("Shifts active window left")
    func testShiftActiveWindowLeft() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)
        let windowId3 = WindowId(appPID: 1236, registry: mockRegistry)

        try stack.add(windowId1)
        try stack.add(windowId2)
        try stack.add(windowId3)

        // Start at index 2 (windowId3)
        stack.nextWindow()
        stack.nextWindow()
        #expect(stack.activeIndex == 2)
        #expect(stack.getActiveWindowId() === windowId3)
        #expect(stack.allWindowIds == [windowId1, windowId2, windowId3])

        // Shift left: windowId3 should swap with windowId2 and become active
        stack.shiftActiveLeft()
        #expect(stack.activeIndex == 1)
        #expect(stack.getActiveWindowId() === windowId3)
        #expect(stack.allWindowIds == [windowId1, windowId3, windowId2])
    }

    @Test("Shift left does nothing at start of list")
    func testShiftActiveWindowLeftAtStart() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)

        try stack.add(windowId1)
        try stack.add(windowId2)

        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() === windowId1)

        // Try to shift left when already at start - should do nothing
        stack.shiftActiveLeft()
        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() === windowId1)
        #expect(stack.allWindowIds == [windowId1, windowId2])
    }

    @Test("Shifts active window right")
    func testShiftActiveWindowRight() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)
        let windowId3 = WindowId(appPID: 1236, registry: mockRegistry)

        try stack.add(windowId1)
        try stack.add(windowId2)
        try stack.add(windowId3)

        // Start at index 0 (windowId1)
        #expect(stack.activeIndex == 0)
        #expect(stack.getActiveWindowId() === windowId1)
        #expect(stack.allWindowIds == [windowId1, windowId2, windowId3])

        // Shift right: windowId1 should swap with windowId2
        stack.shiftActiveRight()
        #expect(stack.activeIndex == 1)
        #expect(stack.getActiveWindowId() === windowId1)
        #expect(stack.allWindowIds == [windowId2, windowId1, windowId3])
    }

    @Test("Shift right does nothing at end of list")
    func testShiftActiveWindowRightAtEnd() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)

        try stack.add(windowId1)
        try stack.add(windowId2)

        stack.nextWindow()
        #expect(stack.activeIndex == 1)
        #expect(stack.getActiveWindowId() === windowId2)

        // Try to shift right when already at end - should do nothing
        stack.shiftActiveRight()
        #expect(stack.activeIndex == 1)
        #expect(stack.getActiveWindowId() === windowId2)
        #expect(stack.allWindowIds == [windowId1, windowId2])
    }

    @Test("Shift left with single window does nothing")
    func testShiftActiveWindowLeftWithSingleWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId = WindowId(appPID: 1234, registry: mockRegistry)

        try stack.add(windowId)
        #expect(stack.activeIndex == 0)

        stack.shiftActiveLeft()
        #expect(stack.activeIndex == 0)
        #expect(stack.allWindowIds == [windowId])
    }

    @Test("Shift right with single window does nothing")
    func testShiftActiveWindowRightWithSingleWindow() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId = WindowId(appPID: 1234, registry: mockRegistry)

        try stack.add(windowId)
        #expect(stack.activeIndex == 0)

        stack.shiftActiveRight()
        #expect(stack.activeIndex == 0)
        #expect(stack.allWindowIds == [windowId])
    }

    @Test("Multiple shifts left")
    func testMultipleShiftsLeft() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)
        let windowId3 = WindowId(appPID: 1236, registry: mockRegistry)
        let windowId4 = WindowId(appPID: 1237, registry: mockRegistry)

        try stack.add(windowId1)
        try stack.add(windowId2)
        try stack.add(windowId3)
        try stack.add(windowId4)

        // Start at index 3 (windowId4)
        for _ in 0..<3 {
            stack.nextWindow()
        }
        #expect(stack.activeIndex == 3)
        #expect(stack.allWindowIds == [windowId1, windowId2, windowId3, windowId4])

        // Shift left 3 times
        stack.shiftActiveLeft()
        #expect(stack.activeIndex == 2)
        #expect(stack.allWindowIds == [windowId1, windowId2, windowId4, windowId3])

        stack.shiftActiveLeft()
        #expect(stack.activeIndex == 1)
        #expect(stack.allWindowIds == [windowId1, windowId4, windowId2, windowId3])

        stack.shiftActiveLeft()
        #expect(stack.activeIndex == 0)
        #expect(stack.allWindowIds == [windowId4, windowId1, windowId2, windowId3])
    }

    @Test("Multiple shifts right")
    func testMultipleShiftsRight() throws {
        let stack = WindowStackController(styleProvider: mockStyleProvider)
        let windowId1 = WindowId(appPID: 1234, registry: mockRegistry)
        let windowId2 = WindowId(appPID: 1235, registry: mockRegistry)
        let windowId3 = WindowId(appPID: 1236, registry: mockRegistry)
        let windowId4 = WindowId(appPID: 1237, registry: mockRegistry)

        try stack.add(windowId1)
        try stack.add(windowId2)
        try stack.add(windowId3)
        try stack.add(windowId4)

        // Start at index 0 (windowId1)
        #expect(stack.activeIndex == 0)
        #expect(stack.allWindowIds == [windowId1, windowId2, windowId3, windowId4])

        // Shift right 3 times
        stack.shiftActiveRight()
        #expect(stack.activeIndex == 1)
        #expect(stack.allWindowIds == [windowId2, windowId1, windowId3, windowId4])

        stack.shiftActiveRight()
        #expect(stack.activeIndex == 2)
        #expect(stack.allWindowIds == [windowId2, windowId3, windowId1, windowId4])

        stack.shiftActiveRight()
        #expect(stack.activeIndex == 3)
        #expect(stack.allWindowIds == [windowId2, windowId3, windowId4, windowId1])
    }
}
