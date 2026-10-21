---
id: 2026-S01
name: "Sprint 01"
state: closed
goal: "A chat that talks to xia, and a quick ask about the code under the cursor."
start: 2026-10-20
end: 2026-11-03
capacity: 40
---

## Working agreements

- One task per branch, one logical change per commit.
- `make test` must be green between tasks.
- The tests need nothing but Neovim: plain Lua scripts, and a stand-in
  that speaks the protocol.

## Notes

The first sprint of the front-end. The runtime was ready — the transport
speaks JSON lines, the overlay carries the client's files, the steering
and the approvals are there — and what was missing was the other half: a
Neovim that knows how to talk to it.

The three cards are the three layers, in the order they depend on each
other:

- **DUAL-1** — the wire. The transport runs the server, the client
  speaks the protocol, the session holds the conversation, and the health
  check says whether the agent is there. The plugin owns the process, so
  it owns the server's configuration: the shell is kept away from the
  model.
- **DUAL-2** — the chat. A split on the right: the header, the
  conversation, the input. The input is a normal buffer with normal
  modes; `Enter` in Normal mode sends, `Enter` in Insert mode adds a
  line.
- **DUAL-3** — the quick ask. The selection is the question, the answer
  lands below the code, and the code is not touched. The buffers go to
  the server first, so the agent reads what the user sees.

What is *not* here yet: the review. A change the agent made is pending,
and the plugin says so, but there is no diff to look at and nothing to
accept. That is the next sprint, and it is the heart of the thing: the
user stays in charge of the code.

## Retro

**Delivered:** 34 of 40 points, 3 of 3 cards, all merged into
`sprint/2026-S01` with `make test` green after every task (84 checks).

### What worked

- **The stand-in server paid for itself twice.** The tests never need
  the binary: a Lua script that speaks the protocol is enough, and it
  runs in the same interpreter as the tests. The CI needs Neovim and
  nothing else.
- **The scope is held by extmarks, not by line numbers.** The range
  follows the edits the user makes while the agent works, and the answer
  lands where the code *is*, not where it was.
- **The plugin owns the process, so it owns the policy.** Hiding the
  shell is one line in the server's own configuration, not a rule the
  plugin has to enforce afterwards.

### What went wrong

- **The events arrive in a fast event context.** The first version of
  the transcript wrote to a buffer from the process's stdout callback,
  and the editor said no. The transport now hands the lines to the main
  loop, which is where the editor may be touched. It took a test to find
  it, because a headless run and a real editor fail the same way — the
  first time.
- **The claim needs a clean tree, and the work does not.** Twice the
  claim failed because the changes were still in the working tree. The
  order is: the claim on the sprint branch, the branch, the work.
  Stash, claim, branch, pop.
- **The branch history got tangled once.** A merge landed before the
  card was in review, and the claim had to be redone with `--force`.
  The rule is one task per branch, one merge per card, in that order.

### What we learned

- **A reply is data; a transcript is a story.** The runtime's protocol
  is the difference between a client that can act and a client that
  scrapes text. Every command answers with a structure.
- **The pending rule is the honest one.** The plugin pushes what it
  believes about each file, so a change the agent made must not be lost
  by the next push. Pending is not a half-built feature: it is the
  truth about who owns the file until the user decides.
- **The scope shapes the review, never the capability.** The agent can
  still read, grep and fix three things in a turn; the plugin only
  decides how the result is *shown*.

### Next

The review: the diff of what the agent changed, the hunk-by-hunk
decision, and the changes that landed outside the scope the user asked
for. Then the mentions, and the search that fills the quickfix list.

The plan is in /Users/neurd/.opencode/plan/dual-nvim-plan.md.
