<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2025 Jimmy Ma -->

# Commands

Commands are simple value types describing *what* should happen, decoupled from *how*.

```swift
enum FrameCommand {
    // Window movement
    case moveWindowLeft
    case moveWindowRight
    case moveWindowUp
    case moveWindowDown

    // Frame operations
    case splitHorizontally
    case splitVertically
    case closeFrame

    // Window cycling
    case cycleNextWindow
    case cyclePreviousWindow

    // External events
    case externalWindowAppeared(NSWindow)
    case externalWindowClosed(NSWindow)
    case externalWindowMoved(NSWindow)
}
```

---

## Command Sources

**User Actions** → HotkeyController

```swift
service.addShortcut(
    steps: [(.character("h"), [.maskCommand, .maskShift])],
    description: "cmd+shift+h: move window left",
    action: {
        Task { @MainActor in
            frameManager.enqueueCommand(.moveWindowLeft)
        }
    }
)
```

**System Events** → WindowObserver

```swift
func windowDidAppear(_ notification: NSNotification) {
    frameManager.enqueueCommand(.externalWindowAppeared(notification.window))
}
```

**System Queries** → WindowPoller

```swift
func pollForChanges() {
    let currentWindows = AXUIElement.systemWide().windows()
    if let newWindow = detectNewWindow(currentWindows) {
        frameManager.enqueueCommand(.externalWindowAppeared(newWindow))
    }
}
```

---

## Command Execution

```swift
private func processQueue() async {
    while let command = commandQueue.removeFirst() {
        do {
            try await executeCommand(command)
        } catch {
            logger.error("Command execution failed: \(error)")
        }
    }
}

private func executeCommand(_ command: FrameCommand) async throws {
    switch command {
    case .moveWindowLeft:
        try moveActiveWindow(direction: .left)
    case .splitVertically:
        try splitVertically()
    case .externalWindowAppeared(let window):
        try handleWindowAppeared(window)
    // ... etc
    }
}
```

---

## Command Semantics

### Move Window Commands

Find adjacent frame, remove from current, add to target, update active.

```swift
private func moveActiveWindow(direction: NavigationDirection) throws {
    guard let current = activeFrame else { return }
    guard let window = current.activeWindow else { return }
    guard let targetFrame = navigationService.findAdjacentFrame(
        from: current,
        direction: direction
    ) else { return }

    try current.moveWindow(window, toFrame: targetFrame)
    updateActiveFrame(from: current, to: targetFrame)
}
```

### Split Commands

Create two child frames, move windows to one child, make other child active.

### Close Frame Command

Merge back to parent, transfer windows, delete children.

### External Window Commands

Handle windows created/closed outside GosuTile's control. Integrate or remove from tree.

---

## Adding New Commands

1. Add to enum
2. Add case in executeCommand dispatcher
3. Implement logic
4. Add hotkey/observer trigger if needed
5. Add tests

```swift
enum FrameCommand {
    case newCommand  // Step 1
}

private func executeCommand(_ command: FrameCommand) async throws {
    switch command {
    case .newCommand:  // Step 2
        try executeNewCommand()  // Step 3
    }
}

// Step 4: In HotkeyController or observer
frameManager.enqueueCommand(.newCommand)

// Step 5: In tests
@Test func testNewCommand() { ... }
```
