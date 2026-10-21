---
id: DUAL-7
title: "The model picker and the sessions picker"
status: todo
type: story
epic: EPIC-01
sprint: 2026-S02
points: 5
priority: 2
labels: [ui]
order: 40
created: 2026-10-21
updated: 2026-10-21
---

## Context

The plugin does not know what models exist and does not want to: xia
does. But the user has to be able to *choose* one, and the catalog is a
list of ninety-seven names — a list that a picker handles and a command
line does not.

The protocol already answers both questions: `{"cmd":"models"}` and
`{"cmd":"sessions"}`. What is missing is the surface.

## Acceptance criteria

- [ ] `:DualModel` asks the server for the models and lets the user pick
      one.
- [ ] The pick is applied to the server, and the chat says which model is
      in use now.
- [ ] `:DualSessions` asks the server for the sessions and lets the user
      pick one; the pick resumes it.
- [ ] The list shows what makes a model worth choosing: the provider, the
      name, and the context window.
- [ ] The picker is `vim.ui.select`, so the user's own picker takes over
      — telescope, snacks, anything.
- [ ] A server that does not know the command says so, rather than
      failing: the capability list is checked first.
- [ ] The model in use is marked in the list.
- [ ] The tests cover both, against the stand-in.

## Notes

The plugin has no catalog of its own, and that is the point: a picker
that offers a model the server cannot serve is a picker that lies. The
list comes from the server, every time.
