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

## 2. State Always Correct (With Fallback Recovery)

Operations assume healthy state. If something breaks (crashes, external events), automatic repair brings state back to validity.

**Why:** Keeps business logic clear; system recovers gracefully from edge cases.

```swift
private func processQueue() async {
    while let command = commandQueue.removeFirst() {
        validateAndRepairState()    // Safety net
        try? await executeCommand(command)
        validateAndRepairState()    // Safety net
    }
}
```

**Normal operations:** Write straightforward code assuming things work.

```swift
// Normal: assume things work
func moveWindow(_ window: WindowController, toFrame target: FrameController) throws {
    guard removeWindow(window) else { return }
    try target.addWindow(window, shouldFocus: true)
}
```

**Recovery (edge cases only):**

```swift
private func validateAndRepairState() {
    // Edge case: frame got orphaned
    if let active = activeFrame, !isFrameInTree(active) {
        activeFrame = rootFrame
    }
    // Edge case: window closed outside our control
    for frame in allFrames() {
        let deadWindows = frame.windowStack.all.filter { !isWindowAlive($0) }
        deadWindows.forEach { frame.removeWindow($0) }
    }
}
```

Most code doesn't think about this. It's automatic fallback for crashes, external events, rare bugs.

---

## 3. Self-Healing Operations

When state is inconsistent, it's automatically repaired before cascading to other operations.

**Why:** System survives crashes, external app behavior, unexpected macOS events.

---

## Separation of Concerns

**Business Logic** (FrameController, FrameNavigationService)
- Assume healthy state, write straightforward code
- Rely on Self-Healing to simplify complex recovery

**Command Processing** (FrameManager)
- Command queue, processQueue loop
- Separates concurrency control from business logic

**System Integration** (HotkeyController, WindowObserver, WindowPoller)
- Generate commands, don't execute directly
- Independent from command processor

**Display** (FrameWindowController, Views)
- Read-only access to model
- No mutations

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

---

## Summary

| Principle | How | Why |
|-----------|-----|-----|
| **Single Entry** | All changes via `enqueueCommand()` | Predictable, serialized, auditable |
| **Always Correct** | Validate before/after operations | Clear code, automatic recovery |
| **Self-Healing** | Auto-repair inconsistencies | Survives crashes and external events |

Normal operations are straightforward; edge cases are handled automatically.
