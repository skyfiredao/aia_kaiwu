---
name: job-security-review
description: Workflow for end-to-end security audit. Locates security-sensitive surfaces, audits under OWASP scope, verifies external best practice, and optionally escalates unclear findings. Read-only; fixes are handed off.
readonly: true
is_background: false
agents: [task-explore, task-judge, task-librarian, task-debug]
handoffs:
  - agent: task-multi-build
    label: "Apply the fixes (task-multi-build)"
    prompt: "Apply the [blocker] and [should-fix] items from the security audit above. Skip [nit] items unless the user asks."
  - agent: task-yugong
    label: "Apply the fixes (task-yugong)"
    prompt: "Apply the [blocker] and [should-fix] items from the security audit above as one scoped task. Skip [nit] items unless the user asks."
---

# job-security-review

## Purpose

Route a security audit end-to-end: locate surfaces, audit, optionally deep-dive, aggregate.

## When to enter

- Before shipping code with security surface (auth, session, crypto, secret handling, input validation, deserialization)
- Before opening a PR that touches security-sensitive code
- Periodic per-release check
- When a security-relevant bug's exploit surface needs charting before the fix

Optional argument: `[scope]`: one of `whole` (default), `diff-since:<git-ref>`, or `<path>`.

## Steps

1. **`task-explore`**: Locate every file touching auth, session, password/secret/token/API-key handling, input validation, deserialization, crypto, authorization, file/process/network I/O taking user-controlled input, SQL/NoSQL/command/template construction from user input. Return `path:line` citations.
2. **`task-judge`** and **`task-librarian`** in parallel:
   - `task-judge`: Spec axis narrowed to OWASP Top 10 and the repo's security requirements; Standards axis restricted to security-relevant Fowler smells (unlabeled catches, primitive obsession on secrets, message chains hiding auth checks). Adversarial posture.
   - `task-librarian`: primary-source-only research on current best practice for any library/algorithm the code uses (bcrypt cost factor, JWT library recommendations, SSL/TLS config, framework auth idioms).
3. **Optional escalation to `task-debug`**: only when a specific finding's exact exploit path is unclear. Not on every finding.
4. **Aggregate** into severity buckets: `[blocker]` / `[should-fix]` / `[nit]`. Preserve source attribution; do not re-rank across sub-agents.

## Dispatch rules

- Output MUST end with the line `[read-only: no files edited]` as a self-declaration confirming no file writes occurred during the audit.
- Never skip step 1 (locate); audit without location is theatre.
- Never run `task-debug` on every finding (loop discipline).
- `[blocker]` requires a concrete named failure mode.
- Never merge findings across the parallel sub-agents.

## Output shape

```
## Scope
<scope audited, with commit SHA or diff range>

## Located surface (from task-explore)
<primary + secondary hits with path:line>

## Findings

### [blocker]
- <path:line>, <finding + concrete failure mode + OWASP/spec ref>

### [should-fix]
- <same shape>

### [nit]
- <same shape>

## External best-practice notes (from task-librarian)
- <library / algorithm / config>, <cited recommendation with URL>

## Escalations to task-debug (if invoked)
- <finding>, <SHA1 debug session ref>

## Verdict
<SHIP | FIX-THEN-SHIP | DO-NOT-SHIP + reasoning>

[read-only: no files edited]
```

## Handoff

`task-multi-build` or `task-yugong` to apply the `[blocker]` and `[should-fix]` items.
