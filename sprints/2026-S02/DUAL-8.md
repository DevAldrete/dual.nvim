---
id: DUAL-8
title: "The mentions and the quickfix"
status: review
type: story
epic: EPIC-01
sprint: 2026-S02
points: 8
priority: 3
labels: [ui]
order: 10
created: 2026-10-21
updated: 2026-10-21
assignee: agent-opencode
---

## Context

Two things a person does with an agent that the plugin still makes hard.

**Naming a file.** "look at src/parser.c" means what it says to a person
and nothing to a model: the model has no idea what the user is looking
at. The obvious fix — pasting the file into the prompt — costs a fortune
in tokens and goes stale the moment the buffer changes. The agent can
read the file itself: the plugin owns the buffers, so the agent reads
the *live* buffer, and the mention only has to name the path.

**Finding things.** When the agent greps, the results are the answer, and
the user wants them in a list they can walk: the quickfix list.

## Acceptance criteria

- [ ] `@` in the chat input completes the files of the project.
- [ ] A mention is sent as a path, and the mentioned files are listed
      for the agent, so it reads them itself. The file's contents are
      not pasted.
- [ ] The agent reads the mentioned file from the buffers, not from the
      disk: an unsaved change is what it sees.
- [ ] A `grep` or a `glob` the agent runs fills the quickfix list.
- [ ] The chat says how many matches there are, and how to open them.
- [ ] A mention of a file that is not there is said plainly.
- [ ] The tests cover the completion, the expansion and the quickfix.

## Notes

The quickfix list is built from the tool's *output*, not from the prose
around it: the plugin reads the results of the tool call, the way the
agent's own tools do, and the model's summary stays a summary.

The grep tool answers `path:line: text`; the glob tool answers one path
per line. Both are the plugin's to read.
