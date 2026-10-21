---
id: DUAL-1
title: "The repo and the wire"
status: review
type: story
epic: EPIC-01
sprint: 2026-S01
points: 8
priority: 1
labels: [core]
order: 10
created: 2026-10-21
updated: 2026-10-21
assignee: agent-opencode
---

## Context

The runtime speaks the serve protocol and the editor plugin has to speak
it too. Before any window is drawn, the plugin needs the wire: a way to
run the server, a way to talk to it, and a way to know what the server
can do.

The wire is also where the plugin's one bit of policy lives. The agent's
shell runs on the disk while its file tools work on the buffers, so the
shell is kept away from the model — and the plugin, which owns the
process, owns the server's configuration.

## Acceptance criteria

- [ ] A transport that runs the server and reads its lines. It is three
      things: start, write, stop.
- [ ] A client that writes requests, matches the replies to them, and
      hands the events to whoever is listening.
- [ ] The greeting is understood: the version, the model, the session
      and the capabilities.
- [ ] The capabilities are checked, so an older server is a degraded
      plugin and not a broken one.
- [ ] The session holds the state of the conversation: what is running,
      what is parked, what is waiting for an approval.
- [ ] The server runs with the plugin's own configuration: the shell is
      hidden unless the user asks for it.
- [ ] `:checkhealth dual` says whether the binary is there, whether the
      server answers, and what it understands.
- [ ] The tests need nothing but Neovim: a stand-in that speaks the
      protocol, and plain Lua scripts.
- [ ] `make test` is green.

## Notes

The transport is deliberately small, so a socket or a library transport
can replace the process later without touching anything above it.

The reply and the events are independent: a reply says the request was
understood, the events say what happened. The client keeps them apart.
