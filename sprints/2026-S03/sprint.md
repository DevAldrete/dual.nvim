---
id: 2026-S03
name: "Sprint 03"
state: closed
goal: "The shell comes back, fenced in. And the keys the user chooses, from the editor."
start: 2026-11-17
end: 2026-12-01
capacity: 25
---

## Working agreements

- One task per branch, one logical change per commit.
- `make test` must be green between tasks.
- The tests need nothing but Neovim.

## Notes

Two cards, and both are about the *trust* the user has in the agent —
the two things that could go wrong with an agent that has your files and
your keys.

- **DUAL-9** — the shell comes back, fenced in. The plugin kept the
  shell away because the shell ran on the disk while the file tools
  worked on the buffers. The server now fences the shell in, and says
  so, so the plugin asks and the answer decides.
- **DUAL-10** — the keys are set from the editor. `:DualAuth` asks
  which providers there are, takes the key in a prompt that hides it,
  and gives it to the server.

## Retro

**Delivered:** 13 of 25 points, 2 of 2 cards, all merged into
`sprint/2026-S03` with `make test` green after each (235 checks across
14 files).

### What worked

- **The plugin asks; it does not know.** `xia.sandbox()` answers "what
  is the shell fenced with", and the plugin's rule is written in terms
  of the answer, not the mechanism. The plugin never learns what
  Seatbelt is.
- **The user's own configuration runs first.** The plugin used to
  replace it with its own file; now its file runs the user's and then
  adds to it. A plugin that adds to what the user configured is a
  plugin the user can still configure.
- **A secret is a different kind of prompt.** The label is on its own
  line and what is typed is concealed, because "hidden" is not the same
  as "small": a key typed in a normal prompt is on the screen.

### What went wrong

- **`conceallevel` is a window option, not a buffer one.** The prompt
  set it on the buffer and Neovim said so, in the middle of a test run.
- **A chat that is not open drops what it is told.** The first version
  of the test asserted on the transcript of a chat that was never
  opened, so the assertion was true for the wrong reason.

### What we learned

- **The rule belongs to the server.** The plugin's job is to know
  nothing: the models come from the server, the sessions come from the
  server, and now the sandbox comes from the server too. Everything the
  plugin knows, it can go stale on.
- **"Empty means forget" is a small, honest interface.** A prompt that
  says "empty forgets it" needs no second command, no confirmation
  dialog, and no state.

### Next

The shell still *reads* the disk while the file tools read the buffers,
so `cat` and `read_file` can disagree about a file the user has open.
The sandbox settled the writing; the reading is the next piece, and it
is a matter of giving the shell a view of what the host has.
