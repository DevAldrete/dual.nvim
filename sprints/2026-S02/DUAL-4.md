---
id: DUAL-4
title: "The diff engine and the review state"
status: review
type: story
epic: EPIC-01
sprint: 2026-S02
points: 8
priority: 1
labels: [core]
order: 10
created: 2026-10-21
updated: 2026-10-21
assignee: agent-opencode
---

## Context

The agent edits whole files: it writes through the overlay and what comes
back is one whole file. The user cannot decide about a whole file — the
decision is about *parts* of it.

So the plugin has to turn one whole file into a set of hunks the user can
accept or refuse one at a time, and it has to do it from ground truth:
the difference between what the user has and what the agent wants.

Two things make this less trivial than it looks:

- **The buffer is the truth, not the disk.** The plugin believes what it
  pushed; the user's buffer may have moved on since.
- **A decision moves the ground.** Accepting a hunk changes the buffer,
  so the hunks after it are no longer where they were. The difference has
  to be recomputed, or a hunk is applied at a stale place.

The diff itself is `vim.diff` — Neovim's own, no shelling out, no
dependency. The *rendering* is a git-style diff, because that is the
notation everybody reads.

## Acceptance criteria

- [ ] The engine computes the hunks between two texts, with the context a
      diff shows (three lines by default).
- [ ] A hunk knows where it starts in the old text and in the new one,
      and carries its lines: the context, the removals, the additions.
- [ ] The plugin's belief about a file is the buffer: the text it holds
      and the tick it had.
- [ ] A change the agent made is a *pending change*: what the agent
      wants, what the plugin believes, and the hunks between them.
- [ ] Accepting a hunk writes it into the buffer as an undoable edit,
      and the hunk is gone from the difference afterwards.
- [ ] Refusing a hunk leaves the buffer as it is, and folds the buffer's
      version into what the plugin will push, so the hunk is gone too.
- [ ] The hunks are recomputed after every decision, so a hunk that moved
      is never applied where it used to be.
- [ ] The scope of a request narrows the review: the hunks that overlap
      it are the ones in question, and the rest are told apart.
- [ ] The tests cover the engine, the accept, the refuse, and the scope.

## Notes

The state of a file is small enough to be a table:

    { path, buf, base, target, tick, hunks }

`base` is what the plugin believes; `target` is what the agent wants.
Accepting moves `base` toward `target`; refusing moves `target` back
toward `base`. Either way the hunk disappears, and the difference is
recomputed against the truth.
