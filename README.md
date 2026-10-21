# dual.nvim

The AI client that Neovim deserves — a front-end for
[xia](https://github.com/DevAldrete/xia).

`xia` is the agent: the providers, the tools, the session. `dual.nvim` is
the editor: the chat, the quick ask, the buffers, the diffs. One runtime,
many models, and a Neovim that stays yours.

```lua
{
  "DevAldrete/dual.nvim",
  dependencies = { "DevAldrete/xia" },
  config = function()
    require("dual").setup()
  end,
}
```

## What it does

- **A chat that shares one conversation with everything else.** Ask in the
  chat, ask about a selection, change a selection — the same session, the
  same history.
- **A quick ask about the code you are looking at.** Select, ask, and the
  answer lands below the selection, where the code is. The selection is
  never touched.
- **The agent edits buffers, not files.** A change lands in an unsaved
  buffer as a diff, and you accept or refuse it hunk by hunk.
- **The agent can be steered.** While it works, type what it should do
  instead; the guidance reaches it at the next boundary and the turn
  carries on.
- **Provider-agnostic.** The model is xia's business: OpenAI, Anthropic,
  Gemini, OpenRouter, Ollama, whatever xia has configured. The plugin
  never asks who the provider is.

## Requirements

- Neovim 0.11 or newer.
- The `xia` binary on the path. It is the agent; the plugin is the
  editor.

## The commands

| Command | What it does |
|---|---|
| `:DualChat` | opens or closes the chat |
| `:DualAsk` | asks about the selection |
| `:DualChange` | asks for a change to the selection |
| `:DualInsert` | asks for code at the cursor |
| `:DualReview` | reviews what the agent changed |
| `:DualModel` | picks the model |
| `:DualSessions` | picks a session |
| `:DualCancel` | stops the turn that is running |
| `:DualSteer` | guides the turn that is running |
| `:DualHealth` | says whether the agent is there |

## The configuration

```lua
require("dual").setup({
  server = {
    cmd = "xia",
    model = "anthropic/claude-sonnet-4",
  },
  chat = {
    width = 0.42,
    input_lines = 3,
  },
  files = {
    sync = "loaded",
    max_size = 512 * 1024,
  },
  allow_shell = false,
  keys = {
    chat = "<leader>dc",
    ask = "<leader>da",
    change = "<leader>de",
    insert = "<leader>di",
    cancel = "<leader>dx",
    steer = "<leader>ds",
  },
})
```

### The shell

The agent's shell runs on the disk, while its file tools work on your
buffers. A shell that writes to the disk changes files you never
accepted, so it is hidden by default. `allow_shell = true` turns it back
on, and the chat says so.

## The tests

```sh
make test
```

The tests need nothing but Neovim: they are plain Lua scripts, and the
server they talk to is a stand-in that speaks the protocol.

## The license

MIT.
