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
  executeCommand() (serial, atomic)
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

Central hub that processes all commands sequentially on MainActor. Each command executes atomically—no interleaving, no race conditions.

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

        while !commandQueue.isEmpty {
            let command = commandQueue.removeFirst()
            try? await executeCommand(command)
        }
    }
}
```

**Key:** One command at a time. Serial execution on MainActor eliminates all concurrent access to state.

### Frame Tree (FrameController)

Binary tree of frames. Leaf frames contain windows.

- Assume healthy state
- Don't reference validation or recovery
- Focus: *what* operations are valid

### Services

**FrameNavigationService:** Pure queries for finding adjacent frames. No side effects.

### Views

Observe model state via Combine `@Published` properties. React automatically to changes.

**Pattern:**
- FrameWindow holds weak reference to FrameController
- `setupBindings()` establishes Combine subscriptions
- Views update when `@Published` properties change

**Key invariant:** Views never mutate model. All changes flow through command queue.

See "Reactive View Updates" section for implementation details.

---

## Data Flow Examples

### User Hotkey
1. User presses Cmd+Shift+H
2. HotkeyController detects, enqueues `FrameCommand.moveWindowLeft`
3. Command processor dequeues command
4. executeCommand(.moveWindowLeft) runs atomically:
   - Finds adjacent frame
   - Moves active window
   - Updates activeFrame
5. UI reads updated state and refreshes

### External Window Appears
1. macOS creates window
2. WindowPoller detects, enqueues `FrameCommand.addWindow(window)`
3. Command processor dequeues command
4. executeCommand(.addWindow) runs atomically:
   - Wraps AXUIElement as WindowController
   - Assigns to active frame
   - Updates UI

---

## State Mutations

Only these operations mutate state:

1. **Frame operations** (split, close, move windows)
2. **Window assignment** (add window, remove window)
3. **Navigation** (change active frame, cycle windows)

All flow through command queue. Each command executes atomically with no interleaving.

---

## Reactive View Updates

Views observe model state via Combine `@Published` properties and react automatically to changes.

**Pattern:**
- FrameController publishes state via `@Published` (e.g., `windowTabs`, `geometry`)
- FrameWindow observes via `setupBindings()` using weak references (prevents retain cycles)
- State changes trigger observers; views update without imperative calls

**Example flow:**
```swift
// FrameController (Model)
@MainActor
class FrameController {
    @Published var windowTabs: [WindowTab] = []

    private func updateWindowTabs() {
        self.windowTabs = computeWindowTabs()
        // @Published automatically notifies observers
    }
}

// FrameWindow (View)
class FrameWindow {
    private weak var frameController: FrameController?

    func setupBindings() {
        frameController?.$windowTabs
            .sink { [weak self] tabs in
                // View reacts: update or clear based on tabs
                tabs.isEmpty ? self?.clear() : self?.updateOverlay(tabs: tabs)
            }
            .store(in: &cancellables)
    }
}
```

**Why this pattern:**
- **Decoupling:** Controllers don't know about views, only publish state
- **Consistency:** Views always reflect current model state automatically
- **Simplicity:** No manual refresh orchestration; Combine handles propagation

**Geometry cascade:** When parent geometry changes, `setGeometryRecursive()` updates `@Published geometry` at each node. Each node's observer fires, triggering its view to reposition. Entire tree synchronizes in one operation.
