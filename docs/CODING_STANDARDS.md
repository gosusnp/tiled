<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2025 Jimmy Ma -->

# Coding Standards

## Core Rules

1. **All state changes through `enqueueCommand()`** - never direct mutation
2. **Query methods are pure** - no side effects
3. **Graceful error handling** - recover on failure, never crash on unexpected state

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

## Error Handling: Graceful Recovery

Never use precondition for state validation. Even invariants can be violated in edge cases. Always provide graceful recovery.

**Use throws** for design decisions and invalid operations:

```swift
func closeFrame() throws -> FrameController? {
    guard let parent = parent else {
        throw FrameControllerError.cannotCloseRootFrame  // Design decision
    }

    // Graceful recovery if tree is inconsistent
    guard parent.children.count == 2 else {
        logger.warning("Frame tree inconsistent, cannot close safely")
        return nil  // Or attempt recovery
    }
    // ...
}
```

**Use returns** for cases where operation is not possible:

```swift
// Returns nil when window doesn't exist in frame
func removeWindow(_ window: WindowControllerProtocol) -> Bool {
    guard windowStack.remove(window) else {
        return false  // Window wasn't here, that's fine
    }
    return true
}
```

**Never crash on unexpected state.** Log it, recover, and keep running.

---

## Query/Navigation Methods

Pure functions, no side effects. Window queries may trigger identity completion (lazy), which is acceptable:

```swift
// ✅ Good: lazy completion is OK - happens once, then cached
func findWindowById(_ windowId: WindowId) -> WindowRecord? {
    windowId.ensureComplete()  // Triggers lookup if partial, otherwise no-op
    return registry.lookup(by: windowId)
}

// ✅ Good: pure frame query
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

## Window Identity Handling

Always use `WindowId`, never raw `AXUIElement` references:

```swift
// ✅ Good: FrameManager receives WindowId
func handleWindowAppeared(_ windowId: WindowId) {
    guard let record = windowRegistry.lookup(by: windowId) else { return }
    try activeFrame.addWindow(record.controller)
}

// ❌ Bad: Direct AXUIElement handling
func handleWindowAppeared(_ element: AXUIElement) {
    let controller = WindowController.fromElement(element)
    try activeFrame.addWindow(controller)  // controller holds stale element
}
```

**WindowId lifecycle:**

1. **WindowRegistry** creates WindowId from AXUIElement
2. WindowId may be **partial** (cgWindowID = nil) if bridge fails early
3. Pass **WindowId to FrameManager** (never AXUIElement)
4. WindowId **auto-completes later** (7s polling updates cgWindowID)
5. Never create WindowId directly—only WindowRegistry does

**Window operations:**

```swift
// ✅ Good: Query fresh element when needed
class WindowController {
    let windowId: WindowId

    func raise() throws {
        guard let element = windowId.getCurrentElement() else {
            throw WindowError.elementNotAvailable(windowId)
        }
        try AXUIElementPerformAction(element, kAXRaiseAction)
    }

    func getSize() -> NSSize? {
        guard let element = windowId.getCurrentElement() else { return nil }
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        // extract and return
    }
}

// ❌ Bad: Store reference
class WindowController {
    let element: AXUIElement  // Stale!
    func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction)  // Fails
    }
}
```

**Storing windows:**

```swift
// ✅ Good: Key by WindowIdKey (handles partial/complete)
var windowControllerMap: [WindowIdKey: WindowControllerProtocol] = [:]
windowControllerMap[windowId.asKey()] = controller

// ❌ Bad: Key by AXUIElement (same window = different reference)
var windowControllerMap: [AXUIElement: WindowControllerProtocol] = [:]
// Will have duplicate entries for same window
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
| Recover gracefully on unexpected state | Crash with precondition failures |
| Pure query methods | Queries with side effects |
| Log decisions and changes | Log in loops or frequent paths |
| All changes via enqueueCommand() | Direct mutation of state |
| Small, focused methods | Large, complex methods |
