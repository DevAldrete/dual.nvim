---
id: EPIC-01
title: "The editor front-end of xia"
state: active
color: 3
target: 2026-12-15
---

The runtime has everything a front-end needs: the workspace, the transport,
the overlay, the steering, the approvals. What is missing is the front-end
itself.

This epic builds **dual.nvim**: the chat, the quick ask, the buffers, the
diffs. The plugin owns the Neovim experience and nothing else — no
provider, no agent loop, no session store. Those are the runtime's
business, and the plugin talks to it over the serve protocol.

Two ideas shape it:

- **One transport, two review granularities.** The agent always edits
  real files through the overlay. A scoped request (change this selection)
  is reviewed at the range; a free turn is reviewed per file. The scope
  shapes the review, never the capability.
- **The plugin owns the server, so it owns its configuration.** The
  shell is hidden by default, because a shell that writes to the disk
  changes files the user never accepted.

What done looks like: a user selects code, asks a question, gets the
answer below the selection, asks for a change, sees the diff in the
unsaved buffer, and keeps or throws it away — with the same conversation
behind all of it.

## What was delivered

Seven cards, two sprints:

- **DUAL-1** — the wire: the transport, the client, the session, the
  health check, and the plugin's own configuration of the server.
- **DUAL-2** — the chat split: the header, the transcript, the input.
- **DUAL-3** — the quick ask: the scope, the prompt, the annotation.
- **DUAL-4** — the diff engine and the review state.
- **DUAL-5** — the review window: the diff, the hunks, the decision.
- **DUAL-6** — the scoped requests: `:DualChange` and `:DualInsert`.
- **DUAL-7** — the model picker and the sessions picker.
- **DUAL-8** — the mentions and the quickfix.

The milestone the plan called M1 is the first three, and M3 and M4 are
the last four. The buffer model — the full sync policy, the conflict
detection, the new files — is the part that is left, and the review is
where it will land: a change is applied to the buffer when the user
accepts it, and never before.

What the user has now: a chat, a quick ask about the code under the
cursor, a diff they accept hunk by hunk, a model picker that knows
nothing about any provider, and a quickfix list built from what the
agent actually found.
