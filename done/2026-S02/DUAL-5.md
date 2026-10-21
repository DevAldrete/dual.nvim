---
id: DUAL-5
title: "The review window"
status: done
type: story
epic: EPIC-01
sprint: 2026-S02
points: 8
priority: 1
labels: [ui]
order: 50
created: 2026-10-21
updated: 2026-10-21
assignee: agent-opencode
---

## Context

The difference is only half of the review. The other half is a surface
the user can read it on and act in it: this is where accept and refuse
happen, one hunk at a time.

The rules the reference plugins agree on:

- the diff is shown, not described;
- the hunks are navigable — `]c` and `[c` walk them;
- accepting and refusing are one key each, and they act on the hunk under
  the cursor;
- the whole comparison is available when the local change is too large to
  judge — two windows, the two versions, side by side;
- closing the review does not throw the change away.

## Acceptance criteria

- [ ] The review is a window with the diff of the file: the header, the
      hunks, the context, in the notation of a git diff.
- [ ] `]c` and `[c` walk the hunks, and the cursor lands on one.
- [ ] `a` accepts the hunk under the cursor; `r` refuses it. The window
      redraws with what is left.
- [ ] `A` accepts everything; `R` refuses everything.
- [ ] `d` opens the whole file as a diff — two windows, the buffer's
      version and the agent's — and `q` comes back to the review.
- [ ] `q` closes the review. The change stays pending, and the chat says
      so.
- [ ] The hunks outside the scope of the request are in their own
      section, marked as such, and they are not applied until the user
      says so.
- [ ] When the buffer moved under the review, the window says so: the
      difference now includes the user's own edit.
- [ ] A file the agent created is reviewed too, and accepting it opens it
      as a buffer.
- [ ] The tests cover the rendering and the keys.

## Notes

The window is a floating one: the review is a moment, and it should not
disturb the layout the user has. The full diff is a split, because a
comparison of two versions wants the room.

## Delivery

- Branch: `task/DUAL-5-review-window`
- Commits: `4cc4b1f`, `f1d306c`, `47a67cf`, `e1c1327`
- Summary: Merged in 07b6718.
- Checks: make test
