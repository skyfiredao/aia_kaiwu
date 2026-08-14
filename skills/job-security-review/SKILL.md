---
name: job-security-review
description: End-to-end security audit. Use for security review or when work touches auth, crypto, or secrets.
is_background: false
agents: [task-explore, task-judge, task-librarian, task-debug]
handoffs:
  - agent: task-multi-build
    label: "Apply the fixes (task-multi-build)"
    prompt: "Read the persisted security audit report path provided by the parent. Apply its [blocker] and [should-fix] items. Skip [nice-to-have] items unless the user asks."
  - agent: task-yugong
    label: "Apply the fixes (task-yugong)"
    prompt: "Read the persisted security audit report path provided by the parent. Apply its [blocker] and [should-fix] items as one scoped task. Skip [nice-to-have] items unless the user asks."
---

# job-security-review

## Steps

0. **Classify input surfaces first.** Enumerate every input surface (network endpoint, CLI argument, env variable, config file, data file, state file the project writes and reads back) and assign each a trust class:
   - adversarial: untrusted parties can reach it → full severity rubric
   - user-error: project owner hand-authors → wrong value gets a clear error; malformed exotic shapes Low at most
   - machine-generated: project pipeline produces it → generator's real output is the contract; off-contract Low, Declined by default
   - state-at-rest: project writes and reads back → external corruption Low at most

   Findings triggered only by out-of-envelope input are Low at most, regardless of consequence.
1. **`task-explore`**: Locate every file touching auth, session, password/secret/token/API-key handling, input validation, deserialization, crypto, authorization, file/process/network I/O taking user-controlled input, SQL/NoSQL/command/template construction from user input. Return `path:line` citations.
2. Run **`task-judge`** and **`task-librarian`** as independent passes. Native subagent tools may run them in parallel; opencode runs them sequentially with separate labeled outputs:
   - `task-judge`: Spec axis narrowed to OWASP Top 10 and the repo's security requirements; Standards axis restricted to security-relevant Fowler smells (unlabeled catches, primitive obsession on secrets, message chains hiding auth checks). Adversarial posture.
   - `task-librarian`: primary-source-only research on current best practice for any library/algorithm the code uses (bcrypt cost factor, JWT library recommendations, SSL/TLS config, framework auth idioms).
3. **Optional escalation to `task-debug`**: only when a specific finding's exact exploit path is unclear. Not on every finding.
4. **Aggregate** into severity buckets: `[blocker]` / `[should-fix]` / `[nice-to-have]`. Preserve source attribution; do not re-rank across sub-agents.
5. If fixes are required, ask the parent or a writable workflow to persist the audit under `spec/security/<sha_short>.md`, then include that path in the executor dispatch.

## Dispatch rules

- Never skip step 1 (locate); audit without location is theatre.
- Never run `task-debug` on every finding (loop discipline).
- `[blocker]` requires a concrete named failure mode.
- Never merge findings across the independent passes.
- Three-strike rule: third finding sharing one root cause → structural task or Proposed envelope decision; no fourth instance patch.

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

### [nice-to-have]
- <same shape>

## External best-practice notes (from task-librarian)
- <library / algorithm / config>, <cited recommendation with URL>

## Escalations to task-debug (if invoked)
- <finding>, <diagnostic result; include SHA1 ref only if a writable executor applied instrumentation>

## Verdict
<APPROVED | CHANGES-REQUESTED | BLOCKED + reasoning>

```

## Next

Next step — apply the `[blocker]` and `[should-fix]` items (via `task-yugong` single-scope or `task-multi-build` multi-module).
