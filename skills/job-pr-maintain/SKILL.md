---
name: job-pr-maintain
description: Maintain an open pull request through its review lifecycle. Use to address reviewer comments, update the PR description, and reply to review threads.
is_background: false
agents: [task-explore, task-judge, task-yugong, task-multi-build]
handoffs:
  - agent: job-security-review
    label: "Security review (job-security-review)"
    prompt: "The PR diff touches security-sensitive surfaces (auth / session / crypto / secrets / dep manifests / env vars / new user-controlled I/O). Run job-security-review on the diff."
---

# job-pr-maintain

## Boundary: GitHub API vs local git

This workflow owns GitHub API interactions for the PR. It does not own local git operations, which remain the executing skill's responsibility under its own git discipline.

| Responsibility | Owner |
|---|---|
| Read PR metadata, human reviewer comments, CI status | this workflow (GitHub API, read-only) |
| Fresh first-principles review of the current diff | this workflow (dispatches task-judge) |
| Apply code fixes from findings and actionable comments | executor (task-yugong / task-multi-build) |
| Local git diff, commit, branch management | executor (its own git discipline) |
| Update PR description | this workflow (GitHub API, requires authorization) |
| Reply to review comments | this workflow (GitHub API, requires authorization) |
| Push commits to remote | executor (requires push authorization per AGENTS.md section 6) |

The workflow reads the local diff (`git diff <base>...<head>`) as context input. It does not own the diffing action itself.

## GitHub access prerequisite

This workflow requires at least read access to the GitHub API. Any one of the following satisfies the requirement:

- `gh` CLI installed and authenticated
- `GITHUB_TOKEN` environment variable set (usable via `curl`)
- Host tool's built-in GitHub integration (VS Code GitHub extension, Cursor built-in, etc.)
- A configured GitHub MCP server

If none is available, terminate with a message naming the options above. Do not attempt to proceed without GitHub read access.

## GitHub authorization gate

Before any GitHub write operation, confirm the user has authorized GitHub interaction for this session.

- **Read operations** (always allowed): fetch PR metadata, read human reviewer comments, read CI status.
- **Write operations** (require explicit user authorization): update PR description, reply to review comments, request re-review.

If the user has not authorized GitHub writes, perform read and analysis steps only. Present the proposed description update and comment replies as output for the user to apply manually.

Posting to GitHub also requires the user to confirm the review results (step 10), separate from the standing write authorization.

## Steps

1. **Identify the PR.** Resolve the target PR through the first method that succeeds:
   - User provided a PR URL or number directly.
   - Detect from current branch: query GitHub for a PR whose head matches the current branch name. Use whichever mechanism the environment provides (`gh pr view`, GitHub REST API via `curl` with a configured token, host tool's built-in GitHub integration, or a GitHub MCP server).
   - If all detection methods fail (branch not pushed, no associated PR, no GitHub access configured), ask the user for the PR identifier. Do not guess.

   Once identified, read PR metadata: title, description, base branch, head branch, review status.
2. **Read human reviewer comments.** Fetch pending review comments and conversation threads left by **human reviewers**. Group by file and thread. Ignore auto-generated tool markers (Copilot auto-review, bot suggestions, any "resolved / fixed / addressed" markers) — they are not read and not verified.
3. **Read the local diff.** Run `git diff <base>...<head>` locally to understand the current state. This is a read action for context.
4. **Fresh first-principles review.** Dispatch `task-judge` on the current diff (Standards + Spec axes). This review is done from scratch every round; it does not trace, trust, or verify any prior tool marker or prior fix. Findings are the genuine issues present in the current code only. If the diff touches security surface, continue to `job-security-review`.
5. **Classify human reviewer comments.** For each human comment or thread:
   - `[actionable]`: clear fix needed. Specify the concrete change.
   - `[discussion]`: needs clarification or technical pushback. Draft a response.
   - `[out-of-scope]`: beyond the PR's scope. Note for a follow-up.
6. **Apply fixes.** Dispatch `task-yugong` (single-scope) or `task-multi-build` (multi-file) for the first-principles findings and `[actionable]` human comments. Each fix follows the executor's own TDD discipline.
7. **Verify fixes.** Confirm each fix by its test / machine-checkable predicate. Run relevant tests. Do not verify against external tools' markers.
8. **Update PR description** (GitHub write authorization required). If changes materially alter scope or approach, draft an updated description reflecting the current state.
9. **Draft comment replies** (GitHub write authorization required). For each thread, format the reply for the GitHub comment API:

   **Inline comments** (GitHub binds them to file:line; do not repeat file:line in the body):
   ```
   <plain prose reply, one to three sentences>
   ```
   By category:
   - Actionable: what changed and where; link the commit.
   - Discussion: technical reasoning or a clarifying question.

   **Top-level PR comment** (one summary covering genuine findings and responses this round):
   ```
   ## Review round response

   ### Fixes applied
   - <file:line>: <change summary>

   ### Discussion
   - <file:line>: <reasoning or question>

   ### Out of scope
   - <topic>: <reason, with follow-up reference if applicable>
   ```

10. **Confirm before posting.** Present the review findings, drafted replies, and description update to the user. Post to GitHub only after the user confirms the review results. If the first-principles review finds no issues and no human comment needs a reply, post nothing — do not manufacture a "no issues this round" summary.

## Dispatch rules

- The review is done fresh from first principles every round via `task-judge` on the current diff. Never verify, trust, or trace external tools' fix markers or "resolved" flags.
- Never apply a fix without understanding the reviewer's intent. Ambiguous human comments classify as `[discussion]`.
- Never dismiss a human reviewer's feedback without technical justification.
- Never update the PR description or post replies without GitHub write authorization AND user confirmation of the review results (step 10).
- If the first-principles review finds no issues and no human comment needs a reply, post nothing. Do not manufacture a "no issues this round" summary.
- Never push code from this workflow. Pushing is an executor action under AGENTS.md section 6, requiring separate authorization.
- Never fabricate reviewer intent. If a comment is unclear, say so.
- Never silently expand the PR scope while applying fixes. If a fix requires out-of-scope changes, flag it.
- Reply content posted to GitHub is short human-style prose. No bracket-category tags, alarm emojis, or force-emphasis.

## Output shape

```
## PR
<PR URL, title, base → head>

## First-principles review (from task-judge on current diff)
### [blocker] / [should-fix]
- <file:line>: <finding> → fix: <what was changed>

## Human reviewer comments
### [actionable]
- <file:line> <reviewer>: <summary> → fix: <what was changed>

### [discussion]
- <file:line> <reviewer>: <summary> → response: <draft reply>

### [out-of-scope]
- <reviewer>: <summary> → reason: <why out of scope>

## Fixes applied
- <file:line>: <change summary>

## PR description
<updated description draft, or "no update needed">

## PR comments to post (require GitHub write authorization + user confirmation)
<omit this whole section if no genuine finding and no human comment needs a reply>

### Inline comments
- [<file>:<line>] <finding> | <concrete change or reasoning>
- ...

### Top-level PR comment
## Review round response

### Fixes applied
- <file:line>: <change summary>

### Discussion
- <file:line>: <reasoning or question>

### Out of scope
- <topic>: <reason, with follow-up reference if applicable>

## Pending actions (only what applies)
- [ ] Post inline comments (N items, requires GitHub write authorization + user confirmation)
- [ ] Post top-level PR comment (requires GitHub write authorization + user confirmation)
- [ ] Update PR description (requires GitHub write authorization)
- [ ] Push commits (requires push authorization per AGENTS.md section 6)
```

## Next

`job-security-review` (when the diff touches security surface). User (to confirm review results, authorize GitHub writes, and push).
