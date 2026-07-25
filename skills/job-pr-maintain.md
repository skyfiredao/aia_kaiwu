---
name: job-pr-maintain
description: Workflow for maintaining an open pull request through its review lifecycle. Reads review comments from GitHub, evaluates feedback validity, dispatches executors to apply fixes, updates PR description, and replies to review threads. GitHub write operations require explicit authorization.
readonly: false
is_background: false
agents: [task-explore, task-judge, task-yugong, task-multi-build]
handoffs:
  - agent: job-review
    label: "Pre-push review (job-review)"
    prompt: "Fixes applied for PR feedback. Run job-review on the new diff before pushing."
---

# job-pr-maintain

## Purpose

Maintain an open pull request through its review lifecycle. Read review comments from GitHub, evaluate their technical validity, apply warranted fixes, update the PR description to reflect changes, and reply to review threads.

## Boundary: GitHub API vs local git

This workflow owns GitHub API interactions for the PR. It does not own local git operations, which remain under AGENTS.md section 3.8 and the executing skill's responsibility.

| Responsibility | Owner |
|---|---|
| Read PR metadata, review comments, CI status | this workflow (GitHub API, read-only) |
| Evaluate review feedback validity | this workflow (analysis) |
| Apply code fixes from review feedback | executor (task-yugong / task-multi-build) |
| Local git diff, commit, branch management | executor under AGENTS.md 3.8 |
| Update PR description | this workflow (GitHub API, requires authorization) |
| Reply to review comments | this workflow (GitHub API, requires authorization) |
| Push commits to remote | executor (requires push authorization per AGENTS.md 3.6) |

The workflow reads the local diff (`git diff <base>...<head>`) as context input. It does not own the diffing action itself.

## When to enter

- User asks to address PR review comments ("fix the review comments", "处理 PR 评审意见")
- User asks to update a PR description based on current changes
- User asks to respond to PR feedback
- After applying fixes, user wants the PR synced

## GitHub access prerequisite

This workflow requires at least read access to the GitHub API. Any one of the following satisfies the requirement:

- `gh` CLI installed and authenticated
- `GITHUB_TOKEN` environment variable set (usable via `curl`)
- Host tool's built-in GitHub integration (VS Code GitHub extension, Cursor built-in, etc.)
- A configured GitHub MCP server

If none is available, terminate with a message naming the options above. Do not attempt to proceed without GitHub read access.

## GitHub authorization gate

Before any GitHub write operation, confirm the user has authorized GitHub interaction for this session.

- **Read operations** (always allowed): fetch PR metadata, read review comments, read CI status.
- **Write operations** (require explicit user authorization): update PR description, reply to review comments, request re-review.

If the user has not authorized GitHub writes, perform read and analysis steps only. Present the proposed description update and comment replies as output for the user to apply manually.

## Steps

1. **Identify the PR.** Resolve the target PR through the first method that succeeds:
   - User provided a PR URL or number directly.
   - Detect from current branch: query GitHub for a PR whose head matches the current branch name. Use whichever mechanism the environment provides (`gh pr view`, GitHub REST API via `curl` with a configured token, host tool's built-in GitHub integration, or a GitHub MCP server).
   - If all detection methods fail (branch not pushed, no associated PR, no GitHub access configured), ask the user for the PR identifier. Do not guess.

   Once identified, read PR metadata: title, description, base branch, head branch, review status.
2. **Read review comments.** Fetch all pending review comments and conversation threads. Group by file and thread.
3. **Read the local diff.** Run `git diff <base>...<head>` locally to understand the current state. This is a read action for context.
4. **Evaluate each comment.** For each review comment or thread:
   - `[actionable]`: clear fix needed. Specify the concrete change.
   - `[discussion]`: needs clarification or technical pushback. Draft a response.
   - `[resolved]`: already addressed by existing changes.
   - `[out-of-scope]`: beyond the PR's scope. Note for a follow-up.
5. **Apply fixes.** Dispatch `task-yugong` (single-scope) or `task-multi-build` (multi-file) for `[actionable]` items. Each fix follows TDD discipline per AGENTS.md 3.9.
6. **Verify fixes.** Confirm each fix addresses the reviewer's concern. Run relevant tests.
7. **Update PR description** (GitHub write authorization required). If changes materially alter scope or approach, draft an updated description reflecting the current state.
8. **Draft comment replies** (GitHub write authorization required). For each thread, format the reply for the GitHub comment API:

   **Inline comments** (bound to a specific file and line):
   ```
   [<file>:<line>] <category> | <finding> | <concrete change or reasoning>
   ```
   - `[actionable]`: state what was changed and where.
   - `[discussion]`: state technical reasoning or clarifying question.
   - `[resolved]`: brief note on how it was addressed.

   **Top-level PR comment** (one summary covering the full review round):
   ```
   ## Review round response

   ### Fixes applied
   - <file:line>: <change summary>

   ### Discussion
   - <file:line>: <reasoning or question>

   ### Out of scope
   - <topic>: <reason, with follow-up reference if applicable>
   ```

   When `job-review` was run before this step, incorporate its `[blocker]` and `[should-fix]` findings into the top-level summary under a "Self-review findings also addressed" heading, converted to the same `[file:line] category | finding | fix` format.

## Dispatch rules

- Never apply a fix without understanding the reviewer's intent. Ambiguous comments classify as `[discussion]`.
- Never dismiss review feedback without technical justification.
- Never update the PR description or post replies without GitHub write authorization.
- Never push code from this workflow. Pushing is an executor action under AGENTS.md 3.6, requiring separate authorization.
- Never fabricate reviewer intent. If a comment is unclear, say so.
- Never silently expand the PR scope while applying fixes. If a fix requires out-of-scope changes, flag it.

## Output shape

```
## PR
<PR URL, title, base → head>

## Review comments
### [actionable]
- <file:line> <reviewer>: <summary> → fix: <what was changed>

### [discussion]
- <file:line> <reviewer>: <summary> → response: <draft reply>

### [resolved]
- <file:line> <reviewer>: <summary> → already addressed in <commit/change>

### [out-of-scope]
- <reviewer>: <summary> → reason: <why out of scope>

## Fixes applied
- <file:line>: <change summary>

## PR description
<updated description draft, or "no update needed">

## PR comments to post (require GitHub write authorization)

### Inline comments
- [<file>:<line>] <category> | <finding> | <concrete change or reasoning>
- ...

### Top-level PR comment
## Review round response

### Fixes applied
- <file:line>: <change summary>

### Discussion
- <file:line>: <reasoning or question>

### Out of scope
- <topic>: <reason, with follow-up reference if applicable>

### Self-review findings also addressed (if job-review was run)
- [<file>:<line>] <category> | <finding> | <fix>

## Pending actions
- [ ] Post inline comments (N items, requires GitHub write authorization)
- [ ] Post top-level PR comment (requires GitHub write authorization)
- [ ] Update PR description (requires GitHub write authorization)
- [ ] Push commits (requires push authorization per AGENTS.md 3.6)
```

## Handoff

`job-review` (optional, before pushing fixes). User (to authorize GitHub writes and push).
