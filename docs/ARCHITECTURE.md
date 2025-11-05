<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2025 Jimmy Ma -->

# Architecture Overview

## System Flow

```
Input Sources (Independent)
├─ HotkeyController (user input)
├─ WindowObserver (system events)
└─ WindowPoller (system queries)
           ↓ enqueueCommand()
      Command Queue
           ↓
    FrameManager
  (Command Processor)
      ↓
  validateAndRepairState()
      ↓
  executeCommand()
      ↓
  validateAndRepairState()
      ↓
  FrameManager (canonical state)
    ├─ rootFrame
    ├─ activeFrame
    └─ windowMap
      ↓
  Views (read-only)
```

---

## Components

### Input Controllers

**HotkeyController:** Listen for keyboard shortcuts, enqueue commands.

**WindowObserver:** Listen for macOS window notifications, enqueue commands.

**WindowPoller:** Periodically query for window changes, enqueue commands.

These run independently and never mutate state directly.

### Command Processor (FrameManager)

Central hub that processes all commands sequentially on MainActor.

```swift
@MainActor
class FrameManager {
    private var commandQueue: [FrameCommand] = []
    private var isProcessing = false

    func enqueueCommand(_ command: FrameCommand) {
        commandQueue.append(command)
        if !isProcessing {
            Task { await processQueue() }
        }
    }

    private func processQueue() async {
        isProcessing = true
        defer { isProcessing = false }

        while let command = commandQueue.removeFirst() {
            validateAndRepairState()
            try? await executeCommand(command)
            validateAndRepairState()
        }
    }
}
```

**Key:** One command at a time, validation before/after each.

### Frame Tree (FrameController)

Binary tree of frames. Leaf frames contain windows.

- Assume healthy state
- Don't reference validation or recovery
- Focus: *what* operations are valid

### Services

**FrameNavigationService:** Pure queries for finding adjacent frames. No side effects.

### Views

Read-only access to FrameManager state. Never mutate.

---

## Data Flow Examples

### User Hotkey
1. User presses Cmd+Shift+H
2. HotkeyController detects, enqueues `FrameCommand.moveWindowLeft`
3. Command processor dequeues command
4. validateAndRepairState() ensures consistent state
5. executeCommand(.moveWindowLeft) runs
   - Finds adjacent frame
   - Moves active window
   - Updates activeFrame
6. validateAndRepairState() verifies result
7. UI updates

### External Window Appears
1. macOS creates window
2. WindowObserver detects, enqueues `FrameCommand.externalWindowAppeared(window)`
3. Command processor dequeues command
4. validateAndRepairState() ensures consistent state
5. executeCommand(.externalWindowAppeared) wraps and assigns window
6. validateAndRepairState() verifies result

---

## State Mutations

Only these operations mutate state:

1. **Frame operations** (split, close, move windows)
2. **Window assignment** (add window, handle external appearance)
3. **Navigation** (change active frame, cycle windows)
4. **Repair operations** (in validateAndRepairState)

All flow through command queue with before/after validation.

---

## Note: UI Separation (Future)

Currently, frame operations call `refreshOverlay()` directly. This is a leaky abstraction.

Better approach: After command executes, have the processor notify views to update independently. Keep business logic separate from UI concerns.

```swift
// Future:
private func processQueue() async {
    while let command = commandQueue.removeFirst() {
        validateAndRepairState()
        try? await executeCommand(command)
        validateAndRepairState()
        notifyViewsOfStateChange()  // Views observe and update
    }
}
```
