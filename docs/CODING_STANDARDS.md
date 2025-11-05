<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2025 Jimmy Ma -->

# Coding Standards

## Core Rules

1. **All state changes through `enqueueCommand()`** - never direct mutation
2. **Query methods are pure** - no side effects
3. **Use precondition for binary tree invariants** - use throws for design decisions

---

## State Mutations

### ✅ Correct: Through Command Queue

```swift
// In controllers/observers
frameManager.enqueueCommand(.moveWindowLeft)
frameManager.enqueueCommand(.externalWindowAppeared(window))
frameManager.enqueueCommand(.splitVertically)
```

### ❌ Wrong: Direct Mutation

```swift
activeFrame = someFrame
rootFrame?.children.append(newFrame)
try? currentFrame.addWindow(window)  // In observer
```

---

## Normal Operations

Assume state is healthy and write straightforward code.

```swift
// ✅ Good: clear, direct
func moveWindow(_ window: WindowController, toFrame target: FrameController) throws {
    guard removeWindow(window) else { return }
    try target.addWindow(window, shouldFocus: true)
}

// ❌ Bad: defensive checks scattered everywhere
func moveWindow(...) {
    if let w = windowStack.all.first(where: { $0 === window }) {
        // Maybe remove?
    }
    if target.parent != nil {
        // Maybe add?
    }
}
```

---

## Preconditions vs Errors

**Use precondition** for binary tree invariants that should never fail:

```swift
func closeFrame() throws -> FrameController {
    precondition(parent.children.count == 2)  // Binary tree requirement
    // ...
}
```

**Use throws** for legitimately non-recoverable cases:

```swift
guard let parent = parent else {
    throw FrameControllerError.cannotCloseRootFrame  // Design decision
}
```

---

## Query/Navigation Methods

Pure functions, no side effects:

```swift
// ✅ Good: pure query
func findAdjacentFrame(from frame: FrameController, direction: NavigationDirection) -> FrameController? {
    guard let parent = frame.parent else { return nil }
    let siblings = parent.children
    return siblings.first { $0 !== frame }
}

// ❌ Bad: query with side effects
func findOrCreateAdjacentFrame(...) -> FrameController {
    let frame = findAdjacentFrame(...)
    if frame == nil {
        try? split(.vertical)  // Side effect!
    }
    return frame
}
```

---

## Recovery (Edge Cases Only)

validateAndRepairState() is the safety mechanism. Most code never references it.

```swift
private func validateAndRepairState() {
    // Edge case: frame got orphaned somehow
    if let active = activeFrame, !isFrameInTree(active) {
        logger.error("activeFrame orphaned, recovering to root")
        activeFrame = rootFrame
    }

    // Edge case: window closed outside our control
    for frame in allFrames() {
        let deadWindows = frame.windowStack.all.filter { !isWindowAlive($0) }
        deadWindows.forEach { frame.removeWindow($0) }
    }
}
```

---

## Logging

Log at decision points, not everywhere:

```swift
// ✅ Good: log when recovering from bad state
if !isFrameInTree(activeFrame) {
    logger.error("activeFrame out of tree, recovering")
    activeFrame = rootFrame
}

// ✅ Good: log significant state changes
logger.log("Split frame in \(direction) direction")

// ❌ Bad: log everything
logger.log("Checking window")
logger.log("Getting rect")
logger.log("Adding to stack")
```

---

## Structure

Organize methods into clear sections:

```swift
@MainActor
class FrameManager {
    // MARK: - Properties
    let config: ConfigController
    var rootFrame: FrameController?

    // MARK: - Command Queue
    func enqueueCommand(_ command: FrameCommand) { ... }
    private func processQueue() async { ... }

    // MARK: - Frame Operations
    func splitHorizontally() throws { ... }
    func splitVertically() throws { ... }

    // MARK: - Validation
    private func validateAndRepairState() { ... }
}
```

---

## Naming

Clear intent. Methods that mutate start with verbs:

```swift
// ✅ Good
moveWindow(_ window:, toFrame:)
splitHorizontally()
closeFrame()
findAdjacentFrame(from:, direction:)
isWindowAlive(_ window:) -> Bool
```

---

## Quick Reference

| Do ✅ | Don't ❌ |
|--------|----------|
| Write clear, straightforward operations | Scatter defensive checks everywhere |
| Use precondition for invariants | Check external state everywhere |
| Pure query methods | Queries with side effects |
| Log decisions and changes | Log in loops or frequent paths |
| All changes via enqueueCommand() | Direct mutation of state |
| Small, focused methods | Large, complex methods |
