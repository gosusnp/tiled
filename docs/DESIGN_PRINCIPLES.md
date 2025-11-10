<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2025 Jimmy Ma -->

# Design Principles

Tile.d is built on three core principles that work together to create a resilient, predictable system.

## 1. Single Entry Point

All state mutations flow through a single command queue via `enqueueCommand()`.

**Why:** Eliminates race conditions, provides central logging, prevents conflicting AX operations.

```swift
@MainActor
class FrameManager {
    func enqueueCommand(_ command: FrameCommand) {
        commandQueue.append(command)
        if !isProcessing {
            Task { await processQueue() }
        }
    }
}
```

**All changes go through:** HotkeyController → enqueueCommand, WindowObserver → enqueueCommand, WindowPoller → enqueueCommand.

**Never:** Direct mutation like `activeFrame = someFrame` or `rootFrame?.children.append(...)`.

---

## 2. Straightforward Operations

Operations assume healthy state because the command queue prevents concurrent mutations.

**Why:** Keeps business logic clear and simple. No defensive checks scattered throughout.

```swift
// Straightforward: queue ensures serialized execution
func moveWindow(_ window: WindowController, toFrame target: FrameController) throws {
    guard removeWindow(window) else { return }
    try target.addWindow(window, shouldFocus: true)
}
```

The command queue eliminates the need for defensive programming. Since all mutations are serialized on MainActor, state is always valid when an operation starts.

---

## 3. Graceful Error Handling

When operations fail, recover gracefully rather than crashing. The app should always be in a valid state.

**Why:** Users shouldn't lose work. Transient errors (windows closing, AX API issues) are normal.

```swift
// Wrong: crash on unexpected state
func closeFrame() {
    precondition(parent.children.count == 2)  // Crashes if violated
    // ...
}

// Right: recover gracefully
func closeFrame() throws -> FrameController? {
    guard parent?.children.count == 2 else {
        logger.warning("Frame tree inconsistent, attempting recovery")
        return attemptRecovery()
    }
    // ...
}
```

**Strategies:**
- Return nil/empty for optional results
- Use throws for design decisions, not invariant violations
- Clean up broken state (orphaned frames, dead windows) rather than crashing
- Log what happened for debugging, but keep the app running

---

## 4. Reactive View Updates

Views observe model state and update automatically via Combine `@Published` properties.

**Why:** Eliminates imperative view refresh calls. Controllers publish state; views react. Guarantees UI consistency without manual synchronization.

```swift
// Controller publishes state
@MainActor
class FrameController {
    @Published var windowTabs: [WindowTab] = []

    func addWindow(_ windowId: WindowId) throws {
        try windowStack.add(windowId)
        updateWindowTabs()  // @Published fires, views react automatically
    }
}

// View observes and reacts
class FrameWindow {
    func setupBindings() {
        frameController?.$windowTabs
            .sink { [weak self] tabs in
                tabs.isEmpty ? self?.clear() : self?.updateOverlay(tabs: tabs)
            }
            .store(in: &cancellables)
    }
}
```

**Key points:**
- **Weak references:** Views hold weak references to controllers to prevent retain cycles
- **Automatic propagation:** State change → `@Published` fires → observer reacts → view updates
- **Recursive cascade:** Geometry changes propagate via `setGeometryRecursive()`:
  - Each node updates its `@Published geometry`
  - Each node's observer fires, updating its view
  - Each node recursively updates children
  - Entire tree synchronized in one operation

**Never:** Call view update methods directly from controllers (e.g., `frameWindow.updateOverlay()`). Publish state changes via `@Published` instead.

---

## Separation of Concerns

**Business Logic** (FrameController, FrameNavigationService)
- Assume healthy state, write straightforward code
- Serial queue ensures state is always valid

**Command Processing** (FrameManager)
- Command queue with serial processing
- Separates concurrency control from business logic

**Window Identification** (WindowRegistry, WindowId)
- Single source of truth for window identity
- Bridges unstable AXUIElement (event) ↔ stable WindowId (identity)
- Handles async discovery: creates partial WindowIds, completes them later
- Maintains WindowId ↔ AXUIElement ↔ WindowController mappings

**System Integration** (HotkeyController, WindowObserver, WindowPoller, WindowTracker)
- Generate commands via WindowRegistry, don't execute directly
- WindowTracker delegates to WindowRegistry for discovery
- Independent from command processor

**Display** (FrameWindow, Views)
- Observe model via `@Published` properties
- Weak references prevent retain cycles
- React automatically to state changes; no imperative refresh calls

---

## What Not To Do

### ❌ Direct State Mutation
```swift
activeFrame = someFrame
rootFrame?.children.append(newFrame)
```

### ❌ Business Logic in Observers
```swift
// Wrong
func windowDidAppear(_ notification: NSNotification) {
    try? activeFrame?.addWindow(...)  // Direct operation
}

// Right
func windowDidAppear(_ notification: NSNotification) {
    frameManager.enqueueCommand(.externalWindowAppeared(window))
}
```

### ❌ Defensive Checks in Operations
```swift
// Wrong: scattered defensive checks
func moveWindow(...) {
    if let w = windowStack.all.first(where: { $0 === window }) {
        // Maybe remove?
    }
    // ...
}

// Right: write clear operations
func moveWindow(...) {
    guard removeWindow(...) else { return }
    try addWindow(...)
}
```

### ❌ Storing AXUIElement References
```swift
// Wrong: reference becomes stale
class WindowController {
    let element: AXUIElement  // Stale after next observer fire
    func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction)  // May fail
    }
}

// Right: use stable WindowId
class WindowController {
    let windowId: WindowId
    func raise() throws {
        guard let element = windowId.getCurrentElement() else {
            throw WindowError.elementNotAvailable(windowId)
        }
        try AXUIElementPerformAction(element, kAXRaiseAction)
    }
}
```

### ❌ Using AXUIElement as Dictionary Key
```swift
// Wrong: same window produces different AXUIElement references
var windows: [AXUIElement: WindowController] = [:]
// Observer gives element1, later close event gives element2
// Lookup fails: windows[element2] returns nil even though window exists

// Right: use stable WindowId
var windows: [WindowIdKey: WindowController] = [:]
// WindowId.asKey() handles partial/complete transparently
```

---

## Summary

| Principle | How | Why |
|-----------|-----|-----|
| **Single Entry** | All changes via `enqueueCommand()` | Predictable, serialized, auditable |
| **Straightforward Operations** | Queue ensures serialized execution | No concurrent mutations, clear code |
| **Graceful Error Handling** | Recover on failure, never crash | Users keep working, logging for debugging |
| **Reactive Views** | Views observe `@Published` properties | Automatic consistency, no manual refresh calls |

The command queue is the core solution. By serializing all state mutations on MainActor, we eliminate race conditions. When unexpected things happen (edge cases, transient errors), the system recovers gracefully and logs what happened.

The reactive view pattern ensures UI stays synchronized with model. Views observe model state via Combine and update automatically—no imperative refresh orchestration needed.
