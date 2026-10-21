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
