-- Claude Code over the same IDE bridge the VS Code extension uses: Claude sees the current
-- buffer and selection, and proposes edits as diffs (:w or <leader>ca accepts, :q rejects).
-- Claude runs in its own tmux pane, connected with /ide, so the plugin never opens a terminal.
vim.pack.add { 'https://github.com/coder/claudecode.nvim' }

require('claudecode').setup { terminal = { provider = 'none' } }

local function tmux(args)
  local r = vim.system(vim.list_extend({ 'tmux' }, args), { text = true }):wait()
  return r.code == 0 and vim.trim((r.stdout:gsub('\r', ''))) or nil
end

-- psmux numbers panes per session, so a bare %N can hit another session's pane, and a bad target
-- silently falls back to the active pane. Qualify it and check it resolves to the pane meant.
local function pane_target(session, pane)
  for _, t in ipairs { session .. ':.' .. pane, session .. ':' .. pane } do
    if tmux { 'display-message', '-p', '-t', t, '#{session_name}|#{pane_id}' } == session .. '|' .. pane then return t end
  end
end

--- Calls on_pane(target, command) with the Claude pane in nvim's own tmux window.
local function with_claude_pane(on_pane)
  local session = vim.env.PSMUX_SESSION or tmux { 'display-message', '-p', '#S' }
  local own = session and vim.env.TMUX_PANE and pane_target(session, vim.env.TMUX_PANE)
  local index = own and tmux { 'display-message', '-p', '-t', own, '#{window_index}' }
  if not index then return vim.notify('Not inside a tmux pane', vim.log.levels.WARN) end

  local window = session .. ':' .. index
  local panes = {}
  for line in (tmux { 'list-panes', '-t', window, '-F', '#{pane_id}|#{pane_current_command}' } or ''):gmatch '[^\n]+' do
    local id, cmd = line:match '^(.-)|(.*)$'
    -- An npm install of Claude Code shows up as node; a native one as claude.exe (or claude.exe.old.N mid-update).
    if id ~= vim.env.TMUX_PANE and (cmd:find 'claude' or cmd == 'node') then table.insert(panes, { id = id, cmd = cmd }) end
  end
  if #panes == 0 then return vim.notify('No Claude pane in this tmux window', vim.log.levels.WARN) end

  local function pick(p)
    local target = p and pane_target(session, p.id)
    if target then on_pane(target, p.cmd) end
  end
  if #panes == 1 then return pick(panes[1]) end
  vim.ui.select(panes, { prompt = 'Which pane is Claude?', format_item = function(p) return p.id .. '  ' .. p.cmd end }, pick)
end

-- Claude's prompt runs in vim mode (editorMode = vim), and drops back to NORMAL after a slash
-- command; typed text would then run as vim commands. Read its mode line and get to INSERT first.
local function to_insert(target)
  local lines = vim.split(tmux { 'capture-pane', '-p', '-t', target } or '', '\n', { trimempty = true })
  local footer = table.concat(lines, '\n', math.max(1, #lines - 3))
  if footer:find '%-%- VISUAL %-%-' then
    tmux { 'send-keys', '-t', target, 'Escape' }
    -- Escape followed at once by A reads as Alt-A, so let it land on its own.
    vim.wait(150)
  elseif not footer:find '%-%- NORMAL %-%-' then
    return
  end
  tmux { 'send-keys', '-t', target, 'A' }
end

local function ask_claude()
  with_claude_pane(function(target, cmd)
    vim.ui.input({ prompt = ('Ask Claude (%s, %s): '):format(target, cmd) }, function(text)
      if not text or text == '' then return end
      to_insert(target)
      tmux { 'send-keys', '-t', target, '-l', text }
      tmux { 'send-keys', '-t', target, 'Enter' }
    end)
  end)
end

local map = vim.keymap.set
map('n', '<leader>ck', ask_claude, { desc = '[C]laude: as[K] (types into the tmux Claude pane)' })
map('n', '<leader>cf', function() with_claude_pane(function(target) tmux { 'select-pane', '-t', target } end) end, { desc = '[C]laude: [F]ocus the tmux pane' })
map('n', '<leader>cb', '<cmd>ClaudeCodeAdd %<CR>', { desc = '[C]laude: add [B]uffer' })
map('x', '<leader>cs', '<cmd>ClaudeCodeSend<CR>', { desc = '[C]laude: [S]end selection' })
map('n', '<leader>ca', '<cmd>ClaudeCodeDiffAccept<CR>', { desc = '[C]laude: [A]ccept diff' })
map('n', '<leader>cd', '<cmd>ClaudeCodeDiffDeny<CR>', { desc = '[C]laude: [D]eny diff' })

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'neo-tree',
  callback = function(ev) map('n', '<leader>cs', '<cmd>ClaudeCodeTreeAdd<CR>', { buffer = ev.buf, desc = '[C]laude: add file under cursor' }) end,
})
