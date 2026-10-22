---
name: ship-pr-review-loop
description: >-
  Ship a completed change: branch, validate, open/update PR, watch CI, request
  Copilot review, fix every Copilot finding, squash-merge, then publish
  federated packages to pub.dev. Use when the user says /ship-pr-review-loop,
  wants a PR review loop, squash-merge after Copilot is clean, or publish to
  pub.dev.
disable-model-invocation: true
---

# Ship PR, Copilot loop, squash-merge, pub.dev

User-invoked delivery loop for this federated Flutter plugin. Prefer repo conventions over generic assumptions.

## Goal

1. Branch + commit if needed
2. Local validation
3. PR → CI green on **latest head**
4. Copilot reviewer assigned
5. Fix **every** Copilot finding until the latest Copilot review has zero open issues
6. Squash-merge and delete the branch
7. Publish `openidconnect_platform_interface` first, then `openidconnect`

## Watch, do not busy-wait

Use the bundled PR monitor. Do not poll in the turn.

```bash
python3 ~/.grok/bundled/skills/long-running-background-tasks/watch_pr.py \
  "https://github.com/4D-Technologies/openidconnect_flutter/pull/<n>"
```

Wake on CI failure, new Copilot threads, merge conflicts, mergeable, merged, or closed. Always compare against the **latest PR head SHA**.

## Copilot findings are defects

Treat every Copilot comment, thread, and overview “open issue” as a real bug. Do not dismiss it as speculative, out of contract, extra, or a race that “cannot happen on the main path.”

For each finding:

1. Reproduce it against current code.
2. Fix it with the narrowest correct change and a regression test.
3. Reply, resolve, re-request Copilot, and watch the **new** head.

Do not resolve a thread by arguing. Do not merge because GitHub `mergeable` is true while Copilot still lists open issues. Resolving a thread after a pushback does not count as addressing the finding.

## Copilot via `gh`, not GitHub MCP

Copilot request/reply via GitHub MCP returns 403. Use `gh`. Quote the reviewer so zsh does not glob `[]`.

```bash
gh pr edit <n> --add-reviewer copilot-pull-request-reviewer
gh api repos/4D-Technologies/openidconnect_flutter/pulls/<n>/comments/<id>/replies -f body='...'
gh api graphql -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }' -f id='PRRT_...'
```

## Workflow

### 1. Baseline

```bash
git status -sb
git branch --show-current
gh repo view --json nameWithOwner,defaultBranchRef
```

Default base: `main`. Conventional commits (`fix`, `feat`, `docs`, …). Never commit secrets.

### 2. Local validation

Run from the **package directory**, not the workspace root (`flutter test` at the root has no tests).

```bash
(cd openidconnect && dart analyze lib test && flutter test)
(cd openidconnect_platform_interface && dart analyze lib test && flutter test)
```

`flutter test` rewrites `openidconnect/analysis_options.yaml` (adds a `build/**` exclude). Restore it before every commit:

```bash
git checkout -- openidconnect/analysis_options.yaml
```

### 3. Changelog, versions, README

Before opening or merging:

- Bump `version:` in each published package `pubspec.yaml`
- Matching `CHANGELOG.md` entry with date and issue link
- README / Getting Started notes for user-visible API changes
- Plugin constraint on `openidconnect_platform_interface` must match the interface version you will publish first

### 4. PR

```bash
gh pr create --base main --title "…" --body "…"
```

Body: summary, `Fixes #<n>`, test plan. After push, start `watch_pr.py`.

### 5. Review loop

Until Copilot’s **latest** review has zero open issues, unresolved threads == 0, **and** CI is green on the latest SHA:

1. Collect threads (`gh api` GraphQL `reviewThreads`) and the latest Copilot review overview
2. Fix each finding (see above)
3. Small commits, restore `analysis_options.yaml`, local tests, push
4. Reply + resolve; re-request Copilot after code changes
5. Watch the **new** head

### 6. Squash-merge

```bash
gh pr merge <n> --squash --delete-branch
git checkout main
git pull --ff-only origin main
```

Do not merge with open Copilot issues, unresolved threads, or red CI. GitHub `MERGEABLE` is not sufficient.

### 7. Publish to pub.dev

Federated order: interface, then plugin. `resolution: workspace` is stripped by publish.

```bash
(cd openidconnect_platform_interface && flutter pub publish --dry-run)
(cd openidconnect_platform_interface && flutter pub publish --force)
# wait until https://pub.dev/packages/openidconnect_platform_interface/versions shows the new version
(cd openidconnect && flutter pub publish --dry-run)
(cd openidconnect && flutter pub publish --force)
```

`--force` skips the interactive confirmation. If publish prints a Google OAuth URL, the user must complete it in a browser; there is no stored `pub-credentials.json` on this machine unless they have already authorized.

Do not publish platform implementations unless their versions also changed.

## Stop and ask only for

- Missing pub.dev OAuth / credentials
- Ambiguous version / breaking-change intent

## Completion

Working tree clean; PR squash-merged; branch deleted; packages live on pub.dev; user gets PR URL, merge SHA, and published versions.
