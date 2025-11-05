<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2025 Jimmy Ma -->

# Testing Strategy

## Core Pattern: Dependency Injection

All components accept dependencies as constructor parameters, enabling mocking.

```swift
class FrameManager {
    let config: ConfigController
    let navigationService: FrameNavigationService
    let logger: Logger

    init(
        config: ConfigController,
        navigationService: FrameNavigationService = FrameNavigationService(),
        logger: Logger = Logger()
    ) {
        self.config = config
        self.navigationService = navigationService
        self.logger = logger
    }
}
```

---

## Test Levels

### Unit Tests (Fast)

Test individual components with mocked dependencies.

```swift
@Suite("FrameController Tests")
@MainActor
struct FrameControllerTests {
    let config: ConfigController
    let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    @Test("Split creates child frames")
    func testSplit() throws {
        let frame = FrameController(rect: testFrame, config: config)
        let newActive = try frame.split(direction: .Horizontal)

        #expect(frame.children.count == 2)
        #expect(newActive === frame.children[0])
    }

    @Test("Move window updates frame reference")
    func testMoveWindowUpdatesFrameReference() throws {
        let parent = FrameController(rect: testFrame, config: config)
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window = MockWindowController(title: "Window 1")
        try child1.windowStack.add(window, shouldFocus: false)
        window.frame = child1

        try child1.moveWindow(window, toFrame: child2)

        #expect(window.frame === child2)
    }
}
```

**Mock:** No AX side effects, deterministic behavior.

```swift
class MockWindowController: WindowControllerProtocol {
    var frame: FrameController?
    var position: CGPoint = .zero

    func move(to position: CGPoint) {
        self.position = position
    }
}
```

### Command Tests (Medium)

Test FrameManager command execution and state transitions.

```swift
@Suite("FrameManager Tests")
@MainActor
struct FrameManagerTests {
    let config = ConfigController()

    @Test("Move window left updates active frame")
    func testMoveWindowLeftUpdatesActiveFrame() throws {
        let manager = FrameManager(config: config)
        manager.initializeFromScreen(NSScreen.main!)

        try manager.splitVertically()
        let leftFrame = manager.activeFrame!
        try manager.splitVertically()
        let rightFrame = manager.activeFrame!

        let window = MockWindowController(title: "Test")
        try leftFrame.windowStack.add(window)
        window.frame = leftFrame
        manager.activeFrame = leftFrame

        try manager.moveActiveWindow(direction: .right)

        #expect(manager.activeFrame === rightFrame)
    }
}
```

### Integration Tests (Slow)

Test with real WindowController and AX operations. Only on macOS.

```swift
@Suite("Integration Tests")
@MainActor
struct IntegrationTests {
    @Test("Move real window to adjacent frame")
    func testMoveRealWindow() throws {
        // Create real window, test with real AX
    }
}
```

---

## Common Patterns

**Testing error conditions:**

```swift
@Test("Cannot close root frame")
func testCannotCloseRootFrame() throws {
    let frame = FrameController(rect: testFrame, config: config)

    var threwError = false
    do {
        _ = try frame.closeFrame()
    } catch FrameControllerError.cannotCloseRootFrame {
        threwError = true
    }
    #expect(threwError)
}
```

**Testing state transitions:**

```swift
@Test("Active frame updates after split")
func testActiveFrameAfterSplit() throws {
    let manager = FrameManager(config: config)
    manager.initializeFromScreen(NSScreen.main!)
    let initialFrame = manager.activeFrame!

    try manager.splitVertically()
    let newFrame = manager.activeFrame!

    #expect(initialFrame !== newFrame)
}
```

---

## Organization

```
Tests/
├── GosuTileTests/
│   ├── Controllers/
│   │   ├── FrameManagerTests.swift
│   │   ├── FrameControllerTests.swift
│   │   └── HotkeyControllerTests.swift
│   ├── Services/
│   │   └── FrameNavigationServiceTests.swift
│   └── Models/
│       └── WindowStackTests.swift
```

---

## Guidelines

✅ Test behavior, not implementation
✅ Use mocks to isolate components
✅ Test error cases
✅ Test preconditions and postconditions

❌ Test private implementation details
❌ Create test dependencies on each other
❌ Use real AX in unit tests
❌ Write flaky timing-dependent tests

---

## Running Tests

```bash
swift test
swift test --filter FrameControllerTests
swift test --verbose
```
