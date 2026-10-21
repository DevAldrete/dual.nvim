---
id: DUAL-6
title: "The scoped requests: change and insert"
status: done
type: story
epic: EPIC-01
sprint: 2026-S02
points: 8
priority: 2
labels: [ui, core]
order: 60
created: 2026-10-21
updated: 2026-10-21
assignee: agent-opencode
---

## Context

Two requests are scoped: *change this selection* and *insert here*. They
are the ones where the user has said exactly where the change belongs,
and they are the ones where the plugin has to keep its word.

The scope travels in the request, so the agent knows what "this" is, and
it travels in the review, so the change is judged against the request
that asked for it. The two are the same scope: the range the user
pointed at.

## Acceptance criteria

- [ ] `:DualChange` asks for a change to the visual selection.
- [ ] `:DualInsert` asks for code at the cursor.
- [ ] The request carries the scope: the file, the lines, and the text
      itself, so the agent does not have to guess.
- [ ] The buffers are pushed before the turn, so the agent reads the live
      buffer and not the file on the disk.
- [ ] The change that comes back is reviewed at the range: the hunks that
      overlap the selection are the ones in the review, and the ones that
      do not are listed apart, marked, and not applied.
- [ ] The scope of the request is remembered for the turn, so a change
      that arrives later is judged against the request that asked for it.
- [ ] A request with no selection says so, instead of guessing.
- [ ] The tests cover the request, the scope and the review that follows.

## Notes

The scope is held by extmarks, so it follows the edits the user makes
while the agent works. The range of the *review* is the range of those
marks, not the range the request was made with: the user moved the code
down a line, and the change belongs where the code is now.

## Delivery

- Branch: `task/DUAL-6-scoped`
- Commits: `bcab743`, `508e546`, `25b267b`, `66e0acf`
- Summary: Merged in b65b34c.
- Checks: make test
