-- The configuration of dual: the defaults, and the merge.
--
-- Every value the user sets wins; everything else keeps its default. The
-- merge is shallow on purpose: a table the user gives replaces the one
-- the defaults have, so a list of keymaps is not half-merged with a list
-- of defaults.

local M = {}

M.defaults = {
  -- The server. `cmd` is the xia binary; the plugin runs it and talks to
  -- it over JSON lines.
  server = {
    cmd = "xia",
    args = { "--serve" },
    -- The model, as "provider/id". Empty means: whatever xia is
    -- configured with.
    model = "",
    -- The working directory of the server: the project root. Empty means
    -- the directory Neovim was started in.
    cwd = "",
    -- The environment for the server. Empty means: the environment of
    -- Neovim.
    env = nil,
  },

  -- The chat split. `width` is a fraction of the columns; `input_lines`
  -- is how tall the input is.
  chat = {
    width = 0.42,
    input_lines = 3,
    -- The split the chat opens on: "botright", "topright", "left",
    -- "right".
    position = "botright",
  },

  -- The files the agent works on. The plugin pushes the buffers it owns
  -- before every turn, so the agent reads what the user sees.
  files = {
    -- Which buffers to push: "loaded" (every loaded buffer), "modified"
    -- (only the ones with unsaved changes), or "current" (the one in
    -- focus).
    sync = "loaded",
    -- A file bigger than this is not pushed: the agent is told about the
    -- path instead, and reads it from the disk if it needs it.
    max_size = 512 * 1024,
  },

  -- The shell. The agent's shell runs on the disk, while the file tools
  -- work on the buffers, so it is hidden by default. Turning it on means
  -- the agent can change files the user never accepted.
  allow_shell = false,

  -- The keymaps. Empty means: no keymap.
  keys = {
    chat = "<leader>dc",
    ask = "<leader>da",
    change = "<leader>de",
    insert = "<leader>di",
    cancel = "<leader>dx",
    steer = "<leader>ds",
  },

  -- The commands.
  commands = {
    chat = "DualChat",
    ask = "DualAsk",
    change = "DualChange",
    insert = "DualInsert",
    cancel = "DualCancel",
    steer = "DualSteer",
    review = "DualReview",
    model = "DualModel",
    sessions = "DualSessions",
    health = "DualHealth",
  },

  -- The mentions: @file in the prompt.
  mentions = {
    files = true,
    rules = false,
  },

  -- How long, in milliseconds, the plugin waits for the server to say
  -- hello before it gives up.
  handshake_timeout = 10000,
}

-- A copy of a table, one level deep: the lists inside are copied too, so
-- the user cannot change the defaults by accident.
local function copy(t)
  local out = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      out[k] = copy(v)
    else
      out[k] = v
    end
  end
  return out
end

-- True for a table that is a list: the keys are 1, 2, 3...
local function is_list(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" then
      return false
    end
    n = n + 1
  end
  for i = 1, n do
    if t[i] == nil then
      return false
    end
  end
  return n > 0
end

-- The user's values over the defaults. A table is merged with the
-- default it replaces, so setting one keymap keeps the others; a list is
-- replaced whole, so a shorter list of arguments is the list.
local function merge(base, over)
  local out = copy(base)
  for k, v in pairs(over or {}) do
    if type(v) == "table" and type(out[k]) == "table" and not is_list(v) then
      out[k] = merge(out[k], v)
    elseif v ~= nil then
      out[k] = v
    end
  end
  return out
end

M.defaults = copy(M.defaults)
M.merge = merge

-- The configuration in effect. `setup` fills it.
M.values = copy(M.defaults)

function M.setup(opts)
  M.values = merge(M.defaults, opts)
  return M.values
end

return M
