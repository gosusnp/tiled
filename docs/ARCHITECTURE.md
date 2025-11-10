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
2. WindowObserver or WindowPoller detects AXUIElement
3. WindowTracker delegates to `WindowRegistry.getOrCreateRecord()`:
   - Bridges AXUIElement → `WindowId(appPID, cgWindowID?)`
   - Creates WindowController holding stable WindowId (not element)
   - `cgWindowID` may be nil if geometry matching fails (partial)
4. Enqueues `FrameCommand.windowAppeared(windowId)`
5. Command processor dequeues command
6. executeCommand(.windowAppeared) runs atomically:
   - Looks up WindowController by WindowId
   - Assigns to active frame
   - Updates windowTabs via @Published (view observers react)
7. Later (7s polling): If partial WindowId, polling completes it
   - Same WindowController instance, no duplication
   - View already rendering; no refresh needed

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

---

## Window Identification Strategy

Windows are identified by a stable compound key instead of unstable AXUIElement references.

**The problem with AXUIElement:**
- Event-driven: observer fires, gives you an element reference
- Unstable: same window produces different element objects
- Can't use as dictionary key (lookup fails on next event)
- Becomes stale: can't reuse after observer cycle

**The solution: WindowId**

```swift
class WindowId {
    let appPID: pid_t              // Always available
    let cgWindowID: CGWindowID?    // May be nil (partial) or complete
}
```

**Compound key enables async discovery:**
- **Observer fires** (real-time): AXUIElement detected
  - WindowRegistry bridges element → WindowId
  - `cgWindowID` may be nil if geometry lookup fails
  - Creates WindowController holding WindowId (stable)
  - Enqueues command with WindowId

- **Command executes** (immediately): Frame assignment via WindowId
  - Works whether WindowId is partial or complete
  - View renders; no need to wait

- **Polling completes** (7s later): `cgWindowID` becomes available
  - Same WindowId instance (same appPID)
  - Upgrades from partial → complete
  - No duplication, no state corruption

**Why this pattern works:**
- Deduplicates windows: same `(appPID, cgWindowID)` = same window
- Handles async discovery: partial WindowIds work immediately
- Stable across events: WindowId doesn't change, element reference does
- Integrates with reactive views: models track windows via stable WindowId

**Where WindowId is used:**
- FrameManager keeps `[WindowId: WindowController]` mapping
- FrameController.windowStack stores WindowControllers (which hold WindowIds)
- Views observe @Published properties that reference windows
- Never store raw AXUIElement in controllers/models
