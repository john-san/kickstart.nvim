-- A drill session: runs a queue of drills in its own tabpage, counts keys with vim.on_key,
-- re-checks the goal whenever editor state may have changed, scores, and restores everything
-- it touched (registers, A-Z marks, quickfix, clipboard option, toggled options) at the end.
local api = vim.api
local goal = require 'drill.goal'
local keys = require 'drill.keys'
local score = require 'drill.score'
local state = require 'drill.state'
local ui = require 'drill.ui'
local workspace = require 'drill.workspace'

local R = {}
R.__index = R

---@type table? the running session
R.current = nil

local CONTROLS = { ['<M-r>'] = 'retry', ['<M-s>'] = 'skip', ['<M-/>'] = 'hint', ['<M-q>'] = 'quit' }
local CONTROL_MODES = { 'n', 'i', 'x', 's', 'o', 'c', 't' }
local SAVED_OPTS = { 'wrap', 'spell', 'relativenumber', 'number', 'hlsearch', 'list' }
local SAVED_REGS = vim.split('abcdefghijklmnopqrstuvwxyz0123456789"-/', '')
local EXT = { cs = 'cs', typescript = 'ts', lua = 'lua', sql = 'sql', json = 'json', html = 'html', yaml = 'yaml', text = 'txt', css = 'css', scss = 'scss' }

local function set_of(list)
  local s = {}
  for _, v in ipairs(list) do
    s[v] = true
  end
  return s
end

local function solution_text(sol)
  if type(sol) == 'string' then return sol end
  local parts = {}
  for _, step in ipairs(sol) do
    if type(step) == 'string' then table.insert(parts, step) end
  end
  -- Steps exist so the tests can wait between keys; to a person it is one key sequence.
  return table.concat(parts)
end
R.solution_text = solution_text

--- Start a session over `queue`. opts: header, mode ('day'|'speedrun'|'review'|'single'|'warmup'), day, test.
function R.start(queue, opts)
  if R.current then R.current:quit() end
  local s = setmetatable({
    queue = queue,
    opts = opts or {},
    header = (opts or {}).header or 'DRILL',
    idx = 0,
    combo = 0,
    xp_gained = 0,
    results = {},
    phase = 'idle',
    diag_ns = api.nvim_create_namespace 'drill-diagnostics',
  }, R)
  R.current = s
  s:open()
  s:advance()
  return s
end

function R:open()
  self.saved = { clipboard = vim.o.clipboard, regs = {}, marks = {}, qf = vim.fn.getqflist { items = 1, title = 1 } }
  for _, r in ipairs(SAVED_REGS) do
    local ok, info = pcall(vim.fn.getreginfo, r)
    if ok then self.saved.regs[r] = info end
  end
  for c = 65, 90 do
    local m = string.char(c)
    self.saved.marks[m] = api.nvim_get_mark(m, {})
  end
  -- Drill yanks must not overwrite the system clipboard (your 'clipboard' is unnamedplus).
  vim.o.clipboard = ''
  self.t_start = vim.uv.hrtime()

  self.user_tabs = set_of(api.nvim_list_tabpages())
  vim.cmd 'tabnew'
  self.tab = api.nvim_get_current_tabpage()
  self.main_win = api.nvim_get_current_win()
  self.blank = api.nvim_get_current_buf()
  vim.bo[self.blank].buftype = 'nofile'
  vim.bo[self.blank].bufhidden = 'hide'
  workspace.clean()

  self.on_key_ns = vim.on_key(function(k, typed) self:on_key(k, typed) end)

  -- which-key reads a sequence with getcharstr() and then re-feeds all of it with the
  -- "typed" flag, so on_key would see those keys twice. Note re-fed keys as a replay instead.
  self.replay = 0
  self.orig_feedkeys = api.nvim_feedkeys
  api.nvim_feedkeys = function(fed, mode, escape)
    if self.phase == 'attempt' and mode:find('t', 1, true) then
      local info = debug.getinfo(2, 'S')
      if info and info.source:find('which-key', 1, true) then self.replay = self.replay + keys.count(vim.fn.keytrans(fed)) end
    end
    return self.orig_feedkeys(fed, mode, escape)
  end

  self.augroup = api.nvim_create_augroup('drill-session', { clear = true })
  local au = function(ev, cb) api.nvim_create_autocmd(ev, { group = self.augroup, callback = cb }) end
  au({
    'TextChanged',
    'TextChangedI',
    'CursorMoved',
    'CursorMovedI',
    'ModeChanged',
    'BufEnter',
    'WinEnter',
    'WinClosed',
    'WinResized',
    'TabEnter',
    'QuickFixCmdPost',
    'DiagnosticChanged',
    'OptionSet',
  }, function() self:schedule_check() end)
  au('TabEnter', function()
    if not self.user_tabs[api.nvim_get_current_tabpage()] then vim.schedule(function() self:render() end) end
  end)
  au('TabClosed', function()
    vim.schedule(function()
      if R.current == self and not api.nvim_tabpage_is_valid(self.tab) then self:quit() end
    end)
  end)
  -- After a result, n/r/s/?/q live on the panel, so a click or <C-w> into the drill buffer
  -- would leave them as plain Vim keys. Send focus back to the panel.
  au('WinEnter', function()
    vim.schedule(function()
      if R.current ~= self or self.opts.mode == 'speedrun' then return end
      if self.phase ~= 'passed' and self.phase ~= 'failed' and self.phase ~= 'done' then return end
      if api.nvim_get_current_tabpage() ~= self.tab or api.nvim_get_current_win() == self.panel_win then return end
      if self.panel_win and api.nvim_win_is_valid(self.panel_win) then pcall(api.nvim_set_current_win, self.panel_win) end
    end)
  end)
  au('VimResized', function() self:render() end)
  au('VimLeavePre', function() self:quit { silent = true } end)

  self.saved_maps = {}
  for lhs, action in pairs(CONTROLS) do
    for _, mode in ipairs(CONTROL_MODES) do
      local old = vim.fn.maparg(lhs, mode, false, true)
      if not vim.tbl_isempty(old) and old.buffer == 0 then table.insert(self.saved_maps, { mode, old }) end
      vim.keymap.set(mode, lhs, function() self:control(action) end, { desc = 'Drill: ' .. action })
    end
  end

  self.timer = vim.uv.new_timer()
  self.timer:start(
    250,
    250,
    vim.schedule_wrap(function()
      if R.current ~= self then return end
      if self.phase == 'attempt' then
        self:check()
        self:render()
      end
    end)
  )
end

function R:render()
  if R.current ~= self or self.phase == 'closed' then return end
  if self.user_tabs[api.nvim_get_current_tabpage()] then return end
  pcall(ui.panel, self)
end

--- Move to the next drill (or finish).
function R:advance()
  self:leave_drill()
  self.idx = self.idx + 1
  if self.idx > #self.queue then return self:finish() end
  local d = self.queue[self.idx]
  self.drill = d
  self.par = d.par or keys.solution_cost(d.solution)
  self.rec = { passed = false, failed_any = false, hints = 0, par = self.par, attempts = 0 }
  self.best_score = 0
  self.hint_level = 0
  self:setup()
end

function R:leave_drill()
  -- Only outcomes count: a pass, a fail, a skip or a hint. Quitting halfway is not a miss.
  local rec = self.rec
  if self.drill and rec and (rec.passed or rec.failed_any or rec.hints > 0) and not self.opts.test then
    state.record(self.drill, self.rec)
    state.save()
  end
  if self.drill and self.rec then
    self.results[self.idx] = self.results[self.idx] or { drill = self.drill, passed = false, par = self.par }
    self.results[self.idx].passed = self.rec.passed
  end
  self:teardown()
end

function R:goto_session()
  if api.nvim_get_current_tabpage() ~= self.tab then api.nvim_set_current_tabpage(self.tab) end
  if not (api.nvim_win_is_valid(self.main_win) and api.nvim_win_get_tabpage(self.main_win) == self.tab) then self.main_win = goal.windows()[1] end
  api.nvim_set_current_win(self.main_win)
end

--- Build the drill's starting state: workspace files, buffer, cursor, marks, registers, LSP.
function R:setup()
  local d = self.drill
  self:goto_session()
  local base_tabs = vim.deepcopy(self.user_tabs)
  base_tabs[self.tab] = true
  local ctx = { drill = d, session = self, base_tabs = base_tabs, win = self.main_win }
  ctx.opts = { autoformat = vim.g.disable_autoformat, inlay = vim.lsp.inlay_hint.is_enabled {}, o = {} }
  for _, o in ipairs(SAVED_OPTS) do
    ctx.opts.o[o] = vim.o[o]
  end

  local files = vim.deepcopy(d.files or {})
  if d.file then files[d.file] = d.text end
  if d.git then
    ctx.dir = workspace.create {}
    workspace.git_init(ctx.dir, d.git)
    for rel, text in pairs(files) do
      workspace.write(ctx.dir, rel, text)
    end
  else
    ctx.dir = workspace.create(files)
  end
  -- On DirChanged, gitsigns starts watching the new cwd's .git/HEAD. On Windows, in a freshly
  -- created repo that watcher keeps re-firing (hundreds of `git rev-parse` in seconds), which
  -- starves the git calls gitsigns needs to attach to the drill file. Telescope's git pickers
  -- only need the real cwd, so git drills change directory without autocommands.
  vim.cmd { cmd = 'tcd', args = { vim.fn.fnameescape(ctx.dir) }, mods = { noautocmd = d.git ~= nil } }
  ctx.base_bufs = set_of(api.nvim_list_bufs())

  local buf
  if d.file then
    vim.cmd.edit(vim.fn.fnameescape(d.file))
    buf = api.nvim_get_current_buf()
    if d.ft and vim.bo[buf].filetype ~= d.ft then vim.bo[buf].filetype = d.ft end
  else
    local name = ('drill://%s.%s'):format(d.id, EXT[d.ft] or 'txt')
    local old = vim.fn.bufnr(name)
    if old ~= -1 then pcall(api.nvim_buf_delete, old, { force = true }) end
    buf = api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = 'hide'
    api.nvim_buf_set_name(buf, name)
    -- Loaded with undo disabled so `u` cannot undo the drill text itself.
    vim.bo[buf].undolevels = -1
    api.nvim_buf_set_lines(buf, 0, -1, false, goal.lines(d.text))
    vim.bo[buf].undolevels = -123456
    api.nvim_win_set_buf(self.main_win, buf)
    if d.ft then vim.bo[buf].filetype = d.ft end
    vim.bo[buf].modified = false
  end
  ctx.buf = buf
  ctx.start_lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local row, col = goal.pos(d.cursor or { 1, 0 }, ctx.start_lines)
  api.nvim_win_set_cursor(self.main_win, { row, col or 0 })

  for r, v in pairs(d.registers or {}) do
    vim.fn.setreg(r, v)
  end
  for m, p in pairs(d.marks or {}) do
    local mr, mc = goal.pos(p, ctx.start_lines)
    api.nvim_buf_set_mark(buf, m, mr, mc or 0, {})
  end
  vim.fn.setqflist({}, 'r', { items = {}, title = 'drill' })
  pcall(vim.fn.setloclist, self.main_win, {}, 'r')

  if d.lsp then
    local spec = vim.deepcopy(d.lsp)
    spec.diagnostics = d.diagnostics
    ctx.client = require('drill.lsp').start(buf, spec)
  elseif d.diagnostics then
    local list = {}
    for _, dg in ipairs(d.diagnostics) do
      local r2, c2 = goal.pos(dg, ctx.start_lines)
      table.insert(list, { lnum = r2 - 1, col = c2 or 0, end_col = (c2 or 0) + (dg.len or 1), message = dg.message, severity = dg.severity or 1, source = 'drill' })
    end
    vim.diagnostic.set(self.diag_ns, buf, list)
  end

  if d.goal.cursor and not d.goal.file then
    local target = d.goal.text and goal.lines(d.goal.text) or ctx.start_lines
    ctx.goal_pos = { goal.pos(d.goal.cursor, target) }
  end
  if d.setup then d.setup(ctx) end
  self.ctx = ctx
  self.attempt = nil
  self.result_rows = nil
  self.phase = 'loading'
  self:render()

  local ready = d.ready
  if not ready and d.lsp then ready = function(c) return require('drill.lsp').ready(c.buf) end end
  if not ready and d.git then
    ready = function(c)
      local ok, hunks = pcall(require('gitsigns').get_hunks, c.buf)
      return ok and hunks and #hunks > 0
    end
  end
  if not ready then return self:begin() end
  local waited = 0
  local function poll()
    if R.current ~= self or self.ctx ~= ctx then return end
    local ok, yes = pcall(ready, ctx)
    if (ok and yes) or waited > 10000 then
      if waited > 10000 then vim.notify('drill: setup did not become ready, starting anyway', vim.log.levels.WARN) end
      return self:begin()
    end
    waited = waited + 50
    -- gitsigns sometimes stalls on its first attach while it is busy elsewhere (its cwd
    -- watcher can loop on Windows); asking again gets it through.
    if d.git and waited == 1500 then pcall(function() require('gitsigns').attach(ctx.buf) end) end
    vim.defer_fn(poll, 50)
  end
  poll()
end

function R:begin()
  local ctx = self.ctx
  self.attempt = { keys = 0, spam = 0, arrows = 0, mouse = 0, hints = 0, t0 = vim.uv.hrtime() }
  self.replay = 0
  self.rec.attempts = self.rec.attempts + 1
  if ctx.goal_pos then ui.mark_target(ctx.buf, ctx.goal_pos[1], ctx.goal_pos[2]) end
  self.phase = 'attempt'
  self:render()
end

function R:on_key(_, typed)
  if self.phase ~= 'attempt' or not typed or typed == '' then return end
  local t = vim.fn.keytrans(typed)
  if CONTROLS[t] then return end
  local a = self.attempt
  local n = keys.count(t)
  if self.replay > 0 then
    local replayed = math.min(n, self.replay)
    self.replay = self.replay - replayed
    if replayed == n then return end
    n = n - replayed
  end
  local kind = keys.classify(t, api.nvim_get_mode().mode)
  if kind == 'mouse_noise' then return end
  a.keys = a.keys + n
  if kind == 'arrow' then
    a.arrows = a.arrows + 1
  elseif kind == 'mouse' then
    a.mouse = a.mouse + 1
  elseif kind == 'hjkl' and not a.counting and (self.drill.strict or a.prev == t) then
    a.spam = a.spam + 1
  end
  a.counting = kind == 'count' and (t ~= '0' or a.counting)
  a.prev = kind == 'hjkl' and t or nil
  if a.keys > score.budget(self.par) then
    vim.schedule(function()
      if self.attempt == a and a.keys > score.budget(self.par) then self:fail 'over the keystroke budget' end
    end)
  end
  self:schedule_check()
end

function R:schedule_check()
  if self.check_pending or self.phase ~= 'attempt' then return end
  self.check_pending = true
  vim.schedule(function()
    self.check_pending = false
    self:check()
  end)
end

function R:check()
  if self.phase ~= 'attempt' or R.current ~= self then return false end
  local ok, passed = pcall(goal.check, self.drill, self.ctx)
  if ok and passed then
    self:pass()
    return true
  end
  return false
end

function R:pass()
  local a, d = self.attempt, self.drill
  a.t1 = vim.uv.hrtime()
  local secs = (a.t1 - a.t0) / 1e9
  local res = score.compute { keys = a.keys, par = self.par, seconds = secs, hints = a.hints, spam = a.spam, arrows = a.arrows, mouse = a.mouse, boss = d.boss, combo = self.combo }
  self.combo = self.combo + 1
  local gained = math.max(0, res.score - self.best_score)
  self.best_score = math.max(self.best_score, res.score)
  local level_up = state.add_xp(gained)
  self.xp_gained = self.xp_gained + gained
  local rec = self.rec
  rec.passed = true
  rec.keys = math.min(rec.keys or math.huge, a.keys)
  rec.seconds = math.min(rec.seconds or math.huge, secs)
  self.results[self.idx] = { drill = d, passed = true, keys = rec.keys, par = self.par, label = score.label(rec.keys, self.par), score = self.best_score, seconds = rec.seconds }
  self.phase = 'passed'
  self.result_rows = ui.pass_rows(res, gained, d)
  if level_up then
    local _, title = state.level(state.load().xp)
    table.insert(self.result_rows, 1, { { (' ▲ LEVEL UP → L%d %s'):format(level_up, title), 'DrillWarn' } })
  end
  ui.flash(self.ctx.buf, ('✔ %s  +%d XP'):format(res.label, gained), 'DrillGood')
  self:between()
end

function R:fail(reason)
  if self.phase ~= 'attempt' then return end
  self.phase = 'failed'
  self.combo = 0
  self.rec.failed_any = true
  self.attempt.t1 = vim.uv.hrtime()
  self.result_rows = {
    { { (' ✘ FAIL: %s (%d keys, budget %d)'):format(reason, self.attempt.keys, score.budget(self.par)), 'DrillBad' } },
    { { '   r retries instantly; ? shows the hint, then the solution.', 'DrillDim' } },
  }
  ui.flash(self.ctx.buf, '✘ ' .. reason, 'DrillBad')
  self:between()
end

--- After a pass or fail: wait in the panel for n/r/s/?/q (speedrun advances on its own).
function R:between()
  if self.opts.test then return self:render() end
  if self.opts.mode == 'speedrun' then
    self:render()
    vim.defer_fn(function()
      if R.current == self and (self.phase == 'passed' or self.phase == 'failed') then self:advance() end
    end, self.phase == 'passed' and 400 or 900)
    return
  end
  local m = api.nvim_get_mode().mode
  if m ~= 'n' then api.nvim_feedkeys(vim.keycode '<C-\\><C-n>', 'n', false) end
  self:render()
  local buf = self.panel_buf
  if not vim.b[buf].drill_maps then
    vim.b[buf].drill_maps = true
    local function map(lhs, fn) vim.keymap.set('n', lhs, fn, { buffer = buf, nowait = true }) end
    local function act(fn)
      return function()
        local cur = R.current
        if cur and (cur.phase == 'passed' or cur.phase == 'failed' or cur.phase == 'done') then fn(cur) end
      end
    end
    map('n', act(function(c) c:advance() end))
    map('<CR>', act(function(c) c:advance() end))
    map('r', act(function(c) c:control 'retry' end))
    map('s', act(function(c) c:control 'skip' end))
    map('?', act(function(c) c:control 'hint' end))
    map('q', act(function(c) c:quit() end))
  end
  vim.schedule(function()
    if self.panel_win and api.nvim_win_is_valid(self.panel_win) then pcall(api.nvim_set_current_win, self.panel_win) end
  end)
end

function R:control(action)
  if action == 'quit' then return self:quit() end
  -- While a drill is loading (waiting on gitsigns or the LSP), retry and skip still work.
  local loading_ok = self.phase == 'loading' and (action == 'retry' or action == 'skip')
  if self.phase ~= 'attempt' and self.phase ~= 'passed' and self.phase ~= 'failed' and not loading_ok then return end
  if action == 'retry' then
    self:teardown()
    self.hint_text = nil
    self:setup()
  elseif action == 'skip' then
    if not self.rec.passed then
      self.rec.failed_any = true
      self.combo = 0
    end
    self:advance()
  elseif action == 'hint' then
    if self.opts.mode == 'speedrun' then return end
    if self.phase == 'attempt' then
      self.attempt.hints = self.attempt.hints + 1
      self.rec.hints = self.rec.hints + 1
    end
    self.hint_level = self.hint_level + 1
    local d = self.drill
    if self.hint_level == 1 and d.hint and self.phase == 'attempt' then
      self.hint_text = d.hint .. '\n(again for the solution, -30 each)'
    else
      self.hint_text = (d.hint and (d.hint .. '\n') or '') .. 'Solution: ' .. solution_text(d.solution)
    end
    self:render()
  end
end

local function to_normal()
  if api.nvim_get_mode().mode ~= 'n' then api.nvim_feedkeys(vim.keycode '<C-\\><C-n>', 'n', false) end
end

--- Undo everything the current drill created, leaving the session tab with one window.
function R:teardown()
  local ctx = self.ctx
  if not ctx then return end
  self.ctx = nil
  self.phase = 'idle'
  local d = ctx.drill
  to_normal()
  if d.teardown then pcall(d.teardown, ctx) end
  if ctx.client then require('drill.lsp').stop(ctx.client) end
  pcall(vim.diagnostic.reset, self.diag_ns)
  if not api.nvim_tabpage_is_valid(self.tab) then return end
  self:goto_session()
  for _, t in ipairs(api.nvim_list_tabpages()) do
    if not ctx.base_tabs[t] and api.nvim_tabpage_is_valid(t) then pcall(vim.cmd, 'tabclose! ' .. api.nvim_tabpage_get_number(t)) end
  end
  self:goto_session()
  pcall(vim.cmd, 'diffoff!')
  for _, w in ipairs(api.nvim_tabpage_list_wins(self.tab)) do
    if w ~= self.main_win and w ~= self.panel_win then pcall(api.nvim_win_close, w, true) end
  end
  api.nvim_win_set_buf(self.main_win, self.blank)
  local root = workspace.root():gsub('\\', '/')
  for _, b in ipairs(api.nvim_list_bufs()) do
    if not ctx.base_bufs[b] and b ~= self.blank and b ~= self.panel_buf and api.nvim_buf_is_valid(b) then
      local name = api.nvim_buf_get_name(b):gsub('\\', '/')
      local ours = vim.bo[b].buftype ~= '' or name == '' or name:find(root, 1, true) or name:match '^drill://'
      if ours or not vim.bo[b].modified then pcall(api.nvim_buf_delete, b, { force = true }) end
    end
  end
  if api.nvim_buf_is_valid(ctx.buf) and ctx.buf ~= self.blank then pcall(api.nvim_buf_delete, ctx.buf, { force = true }) end
  for o, v in pairs(ctx.opts.o) do
    vim.o[o] = v
  end
  vim.g.disable_autoformat = ctx.opts.autoformat
  pcall(vim.lsp.inlay_hint.enable, ctx.opts.inlay)
  vim.cmd 'nohlsearch'
end

--- Day/speedrun bookkeeping and the scorecard.
function R:finish()
  self.phase = 'done'
  self.drill = nil
  local passed, total, keys_total = 0, #self.queue, 0
  for _, r in pairs(self.results) do
    if r.passed then
      passed = passed + 1
      keys_total = keys_total + (r.keys or 0)
    end
  end
  local secs = (vim.uv.hrtime() - self.t_start) / 1e9
  local o = self.opts
  local rows = {}
  local data = state.load()
  if o.mode == 'day' and o.day then
    local day = state.day(o.day)
    local boss_ok = true
    for _, r in pairs(self.results) do
      if r.drill.boss and not r.passed then boss_ok = false end
    end
    day.last = state.today()
    day.best = math.max(day.best or 0, self.xp_gained)
    day.passed, day.total = passed, total
    if boss_ok and passed >= math.ceil(total * 0.6) then
      if not day.completed then
        for _, l in ipairs(ui.BANNERS.clear) do
          table.insert(rows, { { l, 'DrillBanner' } })
        end
      end
      day.completed = true
    end
  elseif o.mode == 'speedrun' and passed == total and total > 0 then
    local pb = data.speedrun
    if not pb or secs < pb.seconds then
      data.speedrun = { seconds = secs, keys = keys_total, count = total, date = state.today() }
      table.insert(rows, { { ' ★ NEW SPEEDRUN PERSONAL BEST ★', 'DrillBanner' } })
    end
  end
  if not o.test then state.save() end

  table.insert(rows, { { (' %s: %d/%d passed  ·  %s  ·  +%d XP'):format(self.header, passed, total, ui.fmt_time(secs), self.xp_gained), 'DrillTitle' } })
  table.insert(rows, '')
  for i = 1, total do
    local r = self.results[i]
    local d = self.queue[i]
    if r and r.passed then
      table.insert(rows, { { ' ✔ ', 'DrillGood' }, { ('%-38s'):format(d.title) }, { ('%3d/%-3d %-12s %4d XP'):format(r.keys, r.par, r.label, r.score), 'DrillDim' } })
    else
      table.insert(rows, { { ' ✘ ', 'DrillBad' }, { ('%-38s'):format(d.title) }, { r and 'missed (in tomorrow\'s warmup)' or 'not reached', 'DrillDim' } })
    end
  end
  table.insert(rows, '')
  local level, title = state.level(data.xp)
  table.insert(rows, { { (' Level %d %s  ·  %d XP  ·  streak %d day(s)'):format(level, title, data.xp, data.streak), 'DrillInfo' } })
  if o.mode == 'day' and o.day then
    local nxt = o.day < 7 and (' Next: :DrillDay %d tomorrow (warmup of today\'s misses runs first)'):format(o.day + 1) or ' Course complete. Keep it alive with :Drill review and :Drill speedrun.'
    table.insert(rows, { { nxt, 'DrillDim' } })
    if o.day == 7 then
      table.insert(rows, '')
      table.insert(rows, { { ' ═══ FINAL SCORECARD ═══', 'DrillBanner' } })
      vim.list_extend(rows, ui.stats_rows())
    end
  end
  self.summary_rows = rows
  if o.test then return end
  self:quit { keep_result = true }
  ui.float(rows, ' ' .. self.header .. ' ')
end

--- End the session and restore everything that was saved in open().
function R:quit(opts)
  opts = opts or {}
  if self.phase == 'closed' then return end
  if self.phase ~= 'done' then self:leave_drill() end
  self.phase = 'closed'
  if R.current == self then R.current = nil end
  vim.on_key(nil, self.on_key_ns)
  if self.orig_feedkeys then api.nvim_feedkeys = self.orig_feedkeys end
  if self.timer then
    self.timer:stop()
    self.timer:close()
  end
  pcall(api.nvim_del_augroup_by_id, self.augroup)
  for lhs in pairs(CONTROLS) do
    for _, mode in ipairs(CONTROL_MODES) do
      pcall(vim.keymap.del, mode, lhs)
    end
  end
  for _, m in ipairs(self.saved_maps) do
    pcall(vim.fn.mapset, m[1], false, m[2])
  end
  for r, info in pairs(self.saved.regs) do
    pcall(vim.fn.setreg, r, info)
  end
  for m, old in pairs(self.saved.marks) do
    local cur = api.nvim_get_mark(m, {})
    if not vim.deep_equal(cur, old) then
      if old[1] == 0 then
        pcall(api.nvim_del_mark, m)
      else
        local b = (old[3] ~= 0 and api.nvim_buf_is_valid(old[3])) and old[3] or vim.fn.bufadd(old[4])
        pcall(vim.fn.setpos, "'" .. m, { b, old[1], old[2] + 1, 0 })
      end
    end
  end
  pcall(vim.fn.setqflist, {}, 'r', { items = self.saved.qf.items, title = self.saved.qf.title })
  vim.o.clipboard = self.saved.clipboard
  if not opts.silent then
    if api.nvim_tabpage_is_valid(self.tab) and #api.nvim_list_tabpages() > 1 then
      pcall(vim.cmd, 'tabclose! ' .. api.nvim_tabpage_get_number(self.tab))
    end
    for _, b in ipairs { self.blank, self.panel_buf } do
      if b and api.nvim_buf_is_valid(b) then pcall(api.nvim_buf_delete, b, { force = true }) end
    end
    workspace.clean()
  end
  state.save()
end

return R
