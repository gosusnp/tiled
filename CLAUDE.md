<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2025 Jimmy Ma -->

# Claude Code Guidelines

## Documentation Style

**Concise, scannable, essential only.**

- Headers, bullets, tables for organization
- Quick reference over verbose explanation
- Include: core concepts, practical examples, guidelines
- Exclude: redundant explanations, verbose preambles, obvious details

---

## Code Standards

Follow `docs/CODING_STANDARDS.md`:
- State changes through `enqueueCommand()` only
- Assume healthy state, write straightforward code
- Pure query methods
- precondition for invariants, throws for design decisions

---

## Architecture

See `docs/ARCHITECTURE.md` and `docs/DESIGN_PRINCIPLES.md`.

Command queue → validateAndRepairState → executeCommand → validateAndRepairState.

Business logic assumes healthy state. Recovery is automatic.

---

## Testing

From `docs/TESTING.md`: Unit (mocks), command, integration (real AX).

Use dependency injection. Test behavior, not implementation.

---

## When Writing

1. Keep explanations brief - link to docs
2. Be explicit when user wants detail - they'll ask
3. Default to quick reference style
4. Match docs' conciseness level
