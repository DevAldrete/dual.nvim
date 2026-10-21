---
id: DUAL-2
title: "The chat split"
status: done
type: story
epic: EPIC-01
sprint: 2026-S01
points: 13
priority: 1
labels: [ui]
order: 20
created: 2026-10-21
updated: 2026-10-21
assignee: agent-opencode
---

## Context

The chat is the place to think through the work, and it shares one
conversation with every other surface of the plugin: a quick ask, a
change, an annotation all land in the same history.

The reference plugins both get this right in different ways. The rules
that matter:

- the input is a **normal buffer**, with normal modes and motions;
- `Enter` in Insert mode adds a line, `Enter` in Normal mode sends;
- the transcript reads like a conversation, not like a log;
- tool activity is **one compact row** per call, and it expands when the
  user wants to see it;
- the scroll follows the answer, unless the user scrolled up to read.

## Acceptance criteria

- [ ] The chat is a split on the right: the transcript above, the input
      below, a header above that.
- [ ] The input is a buffer: `Enter` in Normal mode sends and clears it,
      `Enter` in Insert mode adds a line, `Esc` cancels.
- [ ] The answer streams into the transcript as it arrives.
- [ ] The transcript distinguishes the user's lines from the agent's, and
      the tool rows are compact.
- [ ] The scroll follows the answer, and a user who scrolled up stays
      where they are.
- [ ] The chat can be closed and reopened without losing the session.
- [ ] `:DualChat` opens and closes it; the keymap does the same.
- [ ] A turn that is running shows a state, and can be stopped.
- [ ] The tests cover the layout and the sending.

## Notes

The chat is the only surface in this milestone that is *about* the
conversation. The quick ask is about the code.

## Delivery

- Branch: `task/DUAL-2-chat`
- Commits: `b2e59ee`, `55aa6ce`, `172a74f`, `97e1238`
- Summary: Merged in 861f8fc.
- Checks: make test
