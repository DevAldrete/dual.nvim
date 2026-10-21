---
id: DUAL-3
title: "The quick ask"
status: todo
type: story
epic: EPIC-01
sprint: 2026-S01
points: 13
priority: 1
labels: [ui]
order: 30
created: 2026-10-21
updated: 2026-10-21
---

## Context

The quick ask is the thing a user does most: select the code that is in
front of them and ask about it. The answer should land where the code
is, not somewhere else, and the code must not change.

The scope of the request has to travel with it: the agent needs to know
which file, which lines, and that the buffer is unsaved.

The buffer is pushed to the server before the turn, so the agent reads
what the user sees — the live, unsaved buffer — and not the file on the
disk.

## Acceptance criteria

- [ ] `:DualAsk` asks about the visual selection.
- [ ] The answer appears below the selection, wrapped to the width of
      the window, and can be dismissed with `×` without touching the
      conversation.
- [ ] The selection is not changed, and the source keys keep their
      meaning.
- [ ] The request carries the file, the lines and the selection, so the
      agent knows what "this" is.
- [ ] The buffer is pushed before the turn, so the agent reads the live
      buffer and not the file on the disk.
- [ ] A spinner marks the selection while the agent works.
- [ ] The answer also reaches the chat, so the conversation is whole.
- [ ] A file the agent changed during the ask is **pending**: it is not
      applied, and the plugin says so.
- [ ] The tests cover the scope, the annotation and the pending change.

## Notes

The scope travels in the prompt, in a block the agent can read:

    <dual_context file="src/a.c" lines="10-20" saved="false">
    ...the selection...
    </dual_context>

The pending rule is the one that keeps the milestone honest: the plugin
pushes what it owns, so a change the agent made must not be lost by the
next push. The review that turns pending into accepted is the next
milestone.
