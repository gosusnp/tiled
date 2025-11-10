<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2025 Jimmy Ma -->

# Claude Code Guidelines

## Communication Style

**Default: Concise and scannable**
- Headers, bullets, tables for organization
- Quick reference over verbose explanation
- Core concepts only, exclude obvious details
- Link to docs rather than repeat them

**Exception: Match user's request**
- If user asks "explain this in detail", be explicit
- If user says "brief summary", stay scannable
- Adjust verbosity to context, not default

**Examples:**
- ✅ "Changes: WindowController now uses WindowId (line 63-68). Updated 2 creation sites in
WindowManager."
- ❌ "WindowController previously stored a WindowModel which contained an AXUIElement
reference. This was problematic because... [long explanation]"

## Code Structure

Follow `docs/CODING_STANDARDS.md`, `docs/ARCHITECTURE.md`, `docs/DESIGN_PRINCIPLES.md`.

**Code comments:** Explain *why* and *what matters*, not *what the code does*.

**Quick principles:**
- State changes: only via `enqueueCommand()`
- Query methods: pure (no side effects)
- Errors: `precondition` for invariants, `throws` for design decisions
- Architecture: Separation of Concerns, Dependency Injection
- Failure handling: recover gracefully, keep app in valid state
- ⚠️ CAUTION: Error swallowing hides problems. Only use for expected transient errors.

## Testing & Validation

Use dependency injection. Test behavior, not implementation.

**Approach:**
- Unit tests with mocks
- Integration tests with real Accessibility API
- ⚠️ **ObjectIdentifier(AXUIElement) → integration tests only** (signal 5 crash on ARM64e, see `docs/TESTING.md:129-140`)
- TDD: write tests first (see Development Process section)

See `docs/TESTING.md` for details.

## Phase Planning Guidelines

When reviewing a multi-phase plan:
- [ ] Each phase should end with working, compilable code
- [ ] Don't accept plans that say "Phase X breaks things, Phase Y fixes them"
    - This indicates phases are too coarse-grained
- [ ] If a phase will break the build:
    - Question the phase boundaries
    - Suggest combining phases or splitting differently
    - Ask: "Should we combine Phase 2+3 to keep the build working?"
- [ ] Before starting: "Does this plan leave the codebase broken at any phase end?"
    - If YES: Don't start. Revise the plan first.

## Before Writing Any Production Code

Ask: "Do tests exist for this behavior?"
- YES → Write test that currently fails, then code to pass it
- NO → Write the test first, show to user, then code

## Development Process - BLOCKING CHECKS - NON-NEGOTIABLE

Before you mark any task complete or move to the next task, you MUST complete all items below. There are NO exceptions:
1. [ ] ⚠️ YOU MUST run `make test` (swift test with the correct options) and confirm exit code 0
2. [ ] ⚠️ **YOU MUST STOP and explicitly ask user**: "Task X is complete. Is it? Should we proceed to Task Y?"
3. [ ] If uncertain about requirements, STOP and ask - do not assume
4. [ ] If refactoring chains get long (>3 consecutive changes), STOP and ask: "Is there a
  simpler approach?"

VIOLATION = proceeding without these checks
