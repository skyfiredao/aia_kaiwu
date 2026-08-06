---
name: job-align
description: Workflow for aligning documentation with actual code implementation after iterative changes. Enumerates doc touch-points, classifies stale/missing/drift, obtains approval, and dispatches edits.
is_background: false
agents: [task-explore, task-yugong, task-multi-build, task-judge]
handoffs:
  - agent: task-yugong
    label: "Apply alignment (task-yugong)"
    prompt: "Read the persisted alignment report path provided by the parent. Apply its approved edits item-by-item; do not bulk-diff."
  - agent: task-multi-build
    label: "Apply alignment across modules (task-multi-build)"
    prompt: "Read the persisted alignment report path provided by the parent. Apply its approved edits across multiple modules under the task-multi-build contract. Preserve item-by-item semantics."
---

# job-align

## When to enter

- User says "文档过时了" / "对齐一下" / "文档和代码不一致" / "docs are out of date" / "align docs"
- After a large feature lands and before merge, to catch drifted docs
- After multiple rounds of code refactoring that touched documented surfaces

## Steps

1. Invoke **`task-explore`** to enumerate every documentation touch-point that describes implementation:
   - API signatures (function names, params, return types)
   - Behavior descriptions ("when X happens, Y is returned")
   - Code examples in docs
   - Directory structure descriptions
   - CLI flag or environment variable references
2. **Early exit gate**: if step 1 returns zero touch-points (e.g., the docs describe an unrelated project, the docs are all pure narrative with no implementation references, or no docs exist), report `no alignment needed: no doc touch-points describe this codebase's implementation` and terminate. Do not fabricate touch-points to keep the workflow going.
3. For each touch-point, read the actual code. Classify:
   - **stale**: doc describes something no longer in code
   - **missing**: code has something not documented
   - **drift**: both exist but descriptions differ
4. **User-approval gate for per-class direction** (default = docs follow code; exceptions for spec/PRD intent documents where code should follow docs).
5. Ask the parent or selected writable executor to persist the approved inventory under `spec/align/<sha_short>.md`, then include that path in the executor prompt.
6. **`task-yugong`** (single-scope) or **`task-multi-build`** (multi-file): Apply the approved alignment edits. Go item-by-item.
7. **`task-judge`**: Re-scan to confirm no residual drift. Standards axis narrowed to doc-code consistency; Spec axis narrowed to whether preserved intent docs match code intent.
8. Terminate.

## Dispatch rules

- Never edit spec/PRD-type intent documents without explicit user OK; those may represent design that code should follow, not the reverse.
- Never use bulk text diff to apply changes; go item-by-item to preserve semantics.
- Never batch multiple touch-points into a single edit if they describe different concerns.

## Output shape

```
## Scope
<docs audited: paths / sections>

## Touch-point inventory (from task-explore)
- <doc path:line>, <what it describes>

## Drift classification
### stale (doc says something not in code)
- <doc path:line>, <description>, <code state>

### missing (code has, doc doesn't)
- <code path:line>, <what's there>, <where doc should mention>

### drift (both, different)
- <doc path:line> vs <code path:line>, <difference>

## Approved direction
- <per class: docs follow code | code follows docs | leave as-is>

## Applied edits
- <path>, <what changed>

## Post-alignment check (from task-judge)
<residual drift, if any>

```

## Next

Terminal — the workflow ends on a clean re-scan; return control to the caller.
