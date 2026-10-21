---
id: DUAL-9
title: "The shell comes back, fenced in"
status: doing
type: story
epic: EPIC-01
sprint: 2026-S03
points: 5
priority: 1
labels: [core]
order: 10
created: 2026-10-21
updated: 2026-10-21
assignee: agent-opencode
---

## Context

The plugin kept the shell away from the model, and it was right to: the
shell ran on the disk while the file tools worked on the buffers, so a
shell that wrote a file changed something the user never accepted.

The server now fences the shell in — the project is read-only for it
when a host owns the files — and the greeting says what it is fenced
with, so the plugin can trust it.

So the shell can come back. The plugin asks the server the same question
the configuration asks (`xia.sandbox()`), and offers the shell when the
answer is a mechanism rather than "none".

The rule stays the user's to change: `allow_shell` decides.

## Acceptance criteria

- [ ] `allow_shell` is three-valued: `auto` (the default — the shell is
      offered when the server can fence it), `true` (always) and `false`
      (never).
- [ ] The plugin's own configuration of the server says the rule, and the
      user's own configuration still runs (the plugin does not replace it,
      it runs it).
- [ ] The shell is offered when the server can fence it, and kept away
      when it cannot — and the user is told which happened.
- [ ] The health check says what the shell is fenced with.
- [ ] The tests cover the three settings and the rule.
- [ ] The docs say what the shell may and may not do.
- [ ] `make test` is green.

## Notes

The plugin does not know what Seatbelt is, and does not need to: it asks
the server what the shell is fenced with, and the answer is a mechanism
or "none".

The shell still *reads* the disk, so `cat` and `read_file` can disagree
about a file the user has open. What the sandbox settles is the writing:
the shell cannot change a file the user never accepted.
