---
id: DUAL-10
title: "The keys are set from the editor"
status: todo
type: story
epic: EPIC-01
sprint: 2026-S03
points: 8
priority: 2
labels: [ui, core]
order: 20
created: 2026-10-21
updated: 2026-10-21
---

## Context

The provider is a choice, and the key belongs to that choice. The server
keeps the keys now (`xia auth set`, and `{"cmd":"auth"}` for a client),
but the person using the editor is not at a terminal: they are in
Neovim, in the middle of something.

So the editor needs a way to do what the command line does: ask which
providers there are, ask for the key, and give it to the server.

The key is a secret, so it is not shown while it is typed and not kept
in the transcript: the prompt masks it, and the server stores it in its
keyring.

## Acceptance criteria

- [ ] `:DualAuth` asks the server which providers there are and which of
      them have a key.
- [ ] The user picks a provider — through `vim.ui.select`, so their own
      picker takes over.
- [ ] The key is asked for in a masked prompt: it is not on the screen
      while it is typed, and it does not go near the transcript.
- [ ] The key is given to the server, which remembers it, and the chat
      says which provider now has one.
- [ ] A provider that already has a key says so, and the user can take
      it back.
- [ ] A server that does not know the command says so, rather than
      failing.
- [ ] The tests cover the picker, the masking and the round trip.
- [ ] The docs say where the key ends up.
- [ ] `make test` is green.

## Notes

The key never goes near the transcript, the command line or the
environment: it is typed into a masked prompt and sent in the protocol
message the client already has a channel for. The server writes it to
its keyring, with `0600`, in the configuration directory — and that is
where the user can look at it, and delete it.
