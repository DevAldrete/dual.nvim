---
id: 2026-S02
name: "Sprint 02"
state: closed
goal: "The review: the diff, the hunks, the decision. And the extras: the mentions, the pickers, the quickfix."
start: 2026-11-03
end: 2026-11-17
capacity: 40
---

## Working agreements

- One task per branch, one logical change per commit.
- `make test` must be green between tasks.
- The tests need nothing but Neovim: plain Lua scripts, and a stand-in
  that speaks the protocol.

## Notes

The first sprint built the wire, the chat and the quick ask. This one
builds the part the whole thing is for: **the user stays in charge of
the code**.

- **DUAL-4** — the diff engine and the review state. The agent writes
  whole files; the user decides about parts of them. `vim.diff` gives
  the hunks, and a hunk knows both of its sides: the lines it replaces
  and the lines that replace them. Accepting moves the base toward the
  target; refusing moves the target back. Either way the hunk is gone,
  and the difference is recomputed against the truth.
- **DUAL-5** — the review window. The diff in the notation everybody
  reads, the hunks navigable, `a` and `r` to decide, `d` for the whole
  file side by side. The hunks outside the scope of the request are in
  their own section: the agent's overrun, shown and not applied.
- **DUAL-6** — the scoped requests. `:DualChange` and `:DualInsert`,
  with the scope travelling in the request and in the review.
- **DUAL-7** — the pickers. The model and the session, from the
  server's own list, through `vim.ui.select`, so the user's own picker
  takes over.
- **DUAL-8** — the mentions and the quickfix. A mention is a path, and
  the agent reads the file itself; a search fills the quickfix list.

## Retro

**Delivered:** 37 of 40 points, 5 of 5 cards, all merged into
`sprint/2026-S02` with `make test` green after every task (204 checks).

### What worked

- **A hunk that knows both of its sides makes the decision symmetric.**
  Accepting moves the base toward the target; refusing moves the target
  back. One rule, two directions, and the hunk disappears either way.
- **The buffer is the truth, and saying so out loud is the whole
  design.** The plugin's belief about a file is the buffer and its tick.
  When the user edits under a review, the difference grows to include
  their edit and the window says so — no hidden state, no lost work.
- **The scope shapes the review, never the capability.** The agent can
  still read, grep and fix three things in a turn; the plugin only
  decides how the result is *shown*, and the overrun is shown apart
  rather than refused.
- **The stand-in server earned its keep again.** The mock learned to
  change a file and to search, and the whole review was tested end to
  end without the binary.

### What went wrong

- **The branch story got tangled twice.** The work landed on the sprint
  branch instead of a task branch, and a `reset --hard` ate a day of
  edits. The order is: stash, claim, branch, pop — and the claim needs a
  clean tree, which means the untracked files have to be stashed too.
- **`vim.diff`'s indices are a start and a count, not a start and an
  end.** The first version of the engine read them as ranges and
  produced hunks that made no sense. The engine has a test that says
  what a hunk holds, now.
- **The `accept` wrote the change twice into a file that was not open.**
  The file is seeded with what the plugin believed, and then the hunk
  lands in it — but the base had already moved. The seed is now taken
  before the base moves.

### What we learned

- **A decision has to be able to move either side.** That symmetry is
  what made the state small enough to be a table: path, buffer, base,
  target, tick.
- **The diff is not the review.** The diff is the notation; the review
  is the place where the user acts. Both had to be built, and the second
  one is the one people touch.
- **The plugin's job is to know nothing.** The models come from the
  server, the sessions come from the server, the files come from the
  disk the editor is already in. Everything the plugin knows, it can go
  stale on.

### Next

The review is the heart of it, and it is now the part with the fewest
tests around the edges: the conflict when the user and the agent change
the same lines, and the diff of a file that is not open. And the shell:
`allow_shell` is still the only thing between the agent and the disk,
and a sandboxed shell would be the honest answer.
