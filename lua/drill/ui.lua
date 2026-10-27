-- The side panel (task, target, live keys/clock/combo), result banners, the session scorecard
-- and :DrillStats. Panel lines are built from { text, hl } chunks.
local api = vim.api
local M = {}

M.ns = api.nvim_create_namespace 'drill-ui'

local function set_hl()
  local hl = function(name, opts)
    opts.default = true
    api.nvim_set_hl(0, name, opts)
  end
  hl('DrillTitle', { link = 'Title' })
  hl('DrillDim', { link = 'Comment' })
  hl('DrillGood', { link = 'DiagnosticOk' })
  hl('DrillBad', { link = 'DiagnosticError' })
  hl('DrillWarn', { link = 'DiagnosticWarn' })
  hl('DrillInfo', { link = 'DiagnosticInfo' })
  hl('DrillKey', { link = 'Special' })
  hl('DrillChanged', { link = 'DiffChange' })
  hl('DrillTarget', { link = 'IncSearch' })
  hl('DrillBanner', { link = 'DiagnosticOk' })
end
set_hl()
api.nvim_create_autocmd('ColorScheme', { group = api.nvim_create_augroup('drill-ui-hl', { clear = true }), callback = set_hl })

local function width() return math.max(44, math.min(70, math.floor(vim.o.columns * 0.42))) end

local function fmt_time(sec)
  sec = math.floor(sec or 0)
  return ('%d:%02d'):format(math.floor(sec / 60), sec % 60)
end
M.fmt_time = fmt_time

--- Turn rows of chunks into buffer lines plus highlight ranges.
local function flatten(rows, w)
  local lines, hls = {}, {}
  for i, row in ipairs(rows) do
    if type(row) == 'string' then row = { { row } } end
    local text = ''
    for _, ch in ipairs(row) do
      local s = #text
      text = text .. ch[1]
      if ch[2] then table.insert(hls, { i - 1, s, #text, ch[2] }) end
    end
    if w and vim.fn.strdisplaywidth(text) > w then text = vim.fn.strcharpart(text, 0, w - 1) .. '…' end
    lines[i] = text
  end
  return lines, hls
end

local function paint(buf, rows, w)
  local lines, hls = flatten(rows, w)
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  for _, h in ipairs(hls) do
    pcall(api.nvim_buf_set_extmark, buf, M.ns, h[1], h[2], { end_col = math.min(h[3], #lines[h[1] + 1]), hl_group = h[4] })
  end
  return lines
end

local BANNERS = {
  pass = { '╔═══════════════════╗', '║   ★  %-12s ║', '╚═══════════════════╝' },
  boss = { '  ☠  ☠  ☠  BOSS DOWN  ☠  ☠  ☠', '  ▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀' },
  clear = {
    '  ___   _ __   __   ___ _    ___   _   ___ ',
    ' |   \\ /_\\\\ \\ / /  / __| |  | __| /_\\ | _ \\',
    ' | |) / _ \\\\ V /  | (__| |__| _| / _ \\|   /',
    ' |___/_/ \\_\\|_|    \\___|____|___/_/ \\_\\_|_\\',
  },
}
M.BANNERS = BANNERS

--- Target rows for a text goal: every line when short, otherwise changed lines with context.
local function target_rows(start, want, w)
  local rows = {}
  local diff = (vim.text and vim.text.diff or vim.diff)(table.concat(start, '\n') .. '\n', table.concat(want, '\n') .. '\n', { result_type = 'indices' })
  local changed, removed_at = {}, {}
  for _, h in ipairs(diff --[[@as integer[][] ]]) do
    local bs, bc = h[3], h[4]
    for i = bs, bs + bc - 1 do
      changed[i] = true
    end
    if bc == 0 then removed_at[math.max(bs, 1)] = (removed_at[math.max(bs, 1)] or 0) + h[2] end
  end
  local show = {}
  if #want <= 14 then
    for i = 1, #want do
      show[i] = true
    end
  else
    for i in pairs(changed) do
      for j = i - 1, i + 1 do
        show[j] = true
      end
    end
    for i in pairs(removed_at) do
      show[i], show[i + 1] = true, true
    end
  end
  local last = 0
  for i = 1, #want do
    if show[i] then
      if last > 0 and i > last + 1 then table.insert(rows, { { '      ⋮', 'DrillDim' } }) end
      local mark = changed[i] and 'DrillChanged' or nil
      table.insert(rows, { { ('%4d │ '):format(i), 'DrillDim' }, { want[i], mark } })
      last = i
    end
    if removed_at[i] then table.insert(rows, { { ('     ╳ %d line(s) removed here'):format(removed_at[i]), 'DrillWarn' } }) end
  end
  if #want == 0 then table.insert(rows, { { '     (empty buffer)', 'DrillDim' } }) end
  return rows
end

--- Build the panel rows for a session.
function M.rows(s)
  local w = width()
  local rule = { { string.rep('─', w - 2), 'DrillDim' } }
  local d = s.drill
  local st = require 'drill.state'
  local data = st.load()
  local level, title = st.level(data.xp)
  local rows = {}
  local head = s.header or 'DRILL'
  local count = ('%d/%d'):format(s.idx, #s.queue)
  table.insert(rows, { { ' ' .. head, 'DrillTitle' }, { string.rep(' ', math.max(1, w - 3 - #head - #count)) }, { count, 'DrillDim' } })
  table.insert(rows, rule)
  if not d then return rows end

  local tag = d.boss and '☠ BOSS  ' or d.warmup and '↺ WARMUP  ' or d.review and '↺ REVIEW  ' or ''
  table.insert(rows, { { ' ' .. tag, 'DrillWarn' }, { d.title, 'DrillTitle' } })
  for _, l in ipairs(vim.split(d.task, '\n')) do
    table.insert(rows, { { ' ' .. l } })
  end
  if d.goal.text then
    table.insert(rows, '')
    table.insert(rows, { { ' TARGET', 'DrillInfo' }, { '  (changed lines highlighted)', 'DrillDim' } })
    vim.list_extend(rows, target_rows(s.ctx and s.ctx.start_lines or {}, require('drill.goal').lines(d.goal.text), w))
  end
  if d.goal.cursor and not d.goal.file then table.insert(rows, { { ' TARGET ', 'DrillInfo' }, { 'the highlighted spot in the buffer', 'DrillDim' } }) end

  if s.hint_text then
    table.insert(rows, '')
    for i, l in ipairs(vim.split(s.hint_text, '\n')) do
      table.insert(rows, { { i == 1 and ' ? ' or '   ', 'DrillWarn' }, { l, 'DrillWarn' } })
    end
  end

  if s.result_rows then
    table.insert(rows, '')
    vim.list_extend(rows, s.result_rows)
  end

  table.insert(rows, rule)
  local a = s.attempt or {}
  local par = s.par or 0
  local keys_hl = (a.keys or 0) <= par and 'DrillGood' or (a.keys or 0) <= require('drill.score').budget(par) and 'DrillWarn' or 'DrillBad'
  local secs = a.t0 and ((a.t1 or vim.uv.hrtime()) - a.t0) / 1e9 or 0
  table.insert(rows, {
    { ' keys ' },
    { ('%d'):format(a.keys or 0), keys_hl },
    { ('/%d par'):format(par), 'DrillDim' },
    { '   ⏱ ' .. fmt_time(secs) },
    { ('   combo x%.1f'):format(require('drill.score').multiplier(s.combo)), s.combo > 0 and 'DrillGood' or 'DrillDim' },
  })
  table.insert(rows, {
    { (' L%d %s'):format(level, title), 'DrillInfo' },
    { ('  %d XP'):format(data.xp), 'DrillDim' },
    { ('  +%d this session'):format(s.xp_gained), 'DrillGood' },
  })
  if (a.spam or 0) + (a.arrows or 0) + (a.mouse or 0) > 0 then
    table.insert(rows, { { (' ✗ hjkl spam %d  arrows %d  mouse %d'):format(a.spam or 0, a.arrows or 0, a.mouse or 0), 'DrillBad' } })
  end
  if s.phase == 'loading' then table.insert(rows, { { ' … setting up (waiting for git / the language server)', 'DrillDim' } }) end
  if s.phase == 'attempt' or s.phase == 'loading' then
    table.insert(rows, { { ' <M-/>', 'DrillKey' }, { ' hint  ' }, { '<M-r>', 'DrillKey' }, { ' retry  ' }, { '<M-s>', 'DrillKey' }, { ' skip  ' }, { '<M-q>', 'DrillKey' }, { ' quit' } })
  elseif s.phase == 'passed' or s.phase == 'failed' then
    table.insert(rows, {
      { ' n/⏎', 'DrillKey' },
      { ' next  ' },
      { 'r', 'DrillKey' },
      { ' retry  ' },
      { '?', 'DrillKey' },
      { ' hint/solution  ' },
      { 's', 'DrillKey' },
      { ' skip  ' },
      { 'q', 'DrillKey' },
      { ' quit' },
    })
  end
  return rows
end

--- Create or refresh the panel float in the current tabpage.
function M.panel(s, rows)
  rows = rows or M.rows(s)
  local w = width()
  if not (s.panel_buf and api.nvim_buf_is_valid(s.panel_buf)) then
    s.panel_buf = api.nvim_create_buf(false, true)
    vim.bo[s.panel_buf].bufhidden = 'hide'
    vim.bo[s.panel_buf].filetype = 'drillpanel'
  end
  local lines = paint(s.panel_buf, rows, w)
  local height = math.max(1, math.min(#lines, vim.o.lines - 4))
  local cfg = {
    relative = 'editor',
    anchor = 'NE',
    row = 1,
    col = vim.o.columns - 1,
    width = w,
    height = height,
    style = 'minimal',
    border = 'rounded',
    focusable = s.phase == 'passed' or s.phase == 'failed' or s.phase == 'done',
    zindex = 45,
    title = ' drill ',
    title_pos = 'right',
  }
  local win = s.panel_win
  if win and api.nvim_win_is_valid(win) and api.nvim_win_get_tabpage(win) == api.nvim_get_current_tabpage() then
    api.nvim_win_set_config(win, cfg)
  else
    if win and api.nvim_win_is_valid(win) then pcall(api.nvim_win_close, win, true) end
    s.panel_win = api.nvim_open_win(s.panel_buf, false, cfg)
    vim.wo[s.panel_win].wrap = false
    vim.wo[s.panel_win].winhighlight = 'NormalFloat:NormalFloat,FloatBorder:FloatBorder'
  end
end

--- Result rows for a pass: banner, score lines.
function M.pass_rows(res, gained, drill)
  local rows = {}
  if drill.boss then
    for _, l in ipairs(BANNERS.boss) do
      table.insert(rows, { { l, 'DrillBanner' } })
    end
  end
  local b = BANNERS.pass
  table.insert(rows, { { ' ' .. b[1], 'DrillBanner' } })
  table.insert(rows, { { ' ' .. b[2]:format(res.label), 'DrillBanner' }, { ('  +%d XP'):format(gained), 'DrillGood' } })
  table.insert(rows, { { ' ' .. b[3], 'DrillBanner' } })
  for _, l in ipairs(res.lines) do
    table.insert(rows, { { '   ' .. l, 'DrillDim' } })
  end
  return rows
end

--- Short virtual text at the cursor line of the drill buffer.
function M.flash(buf, text, hl)
  if not api.nvim_buf_is_valid(buf) then return end
  local row = api.nvim_get_current_buf() == buf and api.nvim_win_get_cursor(0)[1] - 1 or 0
  pcall(api.nvim_buf_set_extmark, buf, M.ns, row, 0, { virt_text = { { '  ' .. text, hl } }, virt_text_pos = 'eol' })
end

--- Mark a cursor target in the drill buffer.
function M.mark_target(buf, row, col)
  local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ''
  local opts = { sign_text = '◎', sign_hl_group = 'DrillTarget' }
  if col and col < #line then
    opts.end_col = col + #vim.fn.strcharpart(line:sub(col + 1), 0, 1)
    opts.hl_group = 'DrillTarget'
  elseif col then
    opts.virt_text = { { ' ', 'DrillTarget' } }
    opts.virt_text_pos = 'overlay'
  end
  pcall(api.nvim_buf_set_extmark, buf, M.ns, row - 1, col and math.min(col, #line) or 0, opts)
end

--- A centered read-only float; returns win, buf.
function M.float(rows, title)
  local w = 0
  local lines, hls = flatten(rows)
  for _, l in ipairs(lines) do
    w = math.max(w, vim.fn.strdisplaywidth(l))
  end
  w = math.min(w + 2, vim.o.columns - 4)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for _, h in ipairs(hls) do
    pcall(api.nvim_buf_set_extmark, buf, M.ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
  end
  vim.bo[buf].modifiable = false
  local h = math.min(#lines, vim.o.lines - 4)
  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - h) / 2) - 1,
    col = math.floor((vim.o.columns - w) / 2),
    width = w,
    height = h,
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center',
  })
  for _, k in ipairs { 'q', '<Esc>', '<CR>' } do
    vim.keymap.set('n', k, function() pcall(api.nvim_win_close, win, true) end, { buffer = buf, nowait = true })
  end
  return win, buf
end

local function bar(frac, n)
  frac = math.max(0, math.min(1, frac))
  local full = math.floor(frac * n + 0.5)
  return string.rep('█', full) .. string.rep('░', n - full)
end

--- Rows describing overall progress (used by :DrillStats and the day-7 scorecard).
function M.stats_rows()
  local st = require 'drill.state'
  local cur = require 'drill.curriculum'
  local d = st.load()
  local level, title, into, need = st.level(d.xp)
  local rows = {
    { { (' Level %d · %s'):format(level, title), 'DrillTitle' } },
    { { ' ' .. bar(into / need, 24), 'DrillGood' }, { ('  %d XP (%d to next)'):format(d.xp, need - into), 'DrillDim' } },
    { { (' Streak %d day(s)  ·  best %d  ·  last active %s'):format(d.streak, d.best_streak or 0, d.last_active or 'never') } },
    '',
    { { ' DAYS', 'DrillInfo' } },
  }
  for n = 1, 7 do
    local day = cur.day(n)
    local rec = d.days[tostring(n)] or {}
    local mark = rec.completed and { '✔', 'DrillGood' } or rec.last and { '…', 'DrillWarn' } or { '·', 'DrillDim' }
    table.insert(rows, {
      { ('  %s '):format(mark[1]), mark[2] },
      { ('Day %d  %-34s'):format(n, day.title) },
      { rec.best and ('best %d XP, %d/%d passed'):format(rec.best, rec.passed or 0, rec.total or 0) or '', 'DrillDim' },
    })
  end
  table.insert(rows, '')
  table.insert(rows, { { ' SKILLS', 'DrillInfo' }, { '  Leitner box 1 (weak) … 5 (mastered)', 'DrillDim' } })
  local skills = {}
  for name, sk in pairs(d.skills) do
    table.insert(skills, { name = name, box = sk.box, due = sk.due })
  end
  table.sort(skills, function(a, b) return a.box == b.box and a.name < b.name or a.box < b.box end)
  if #skills == 0 then table.insert(rows, { { '  none yet: run :Drill', 'DrillDim' } }) end
  for _, sk in ipairs(skills) do
    local hl = sk.box <= 1 and 'DrillBad' or sk.box <= 3 and 'DrillWarn' or 'DrillGood'
    table.insert(rows, { { ('  %-28s '):format(sk.name) }, { string.rep('■', sk.box) .. string.rep('□', 5 - sk.box), hl }, { '  due ' .. (sk.due or '-'), 'DrillDim' } })
  end
  table.insert(rows, '')
  local sr = d.speedrun
  table.insert(rows, { { ' Speedrun PB: ', 'DrillInfo' }, { sr and ('%s · %d keys · %d drills'):format(fmt_time(sr.seconds), sr.keys, sr.count) or 'none (:Drill speedrun)' } })
  table.insert(rows, { { ' Data: ' .. st.path(), 'DrillDim' } })
  return rows
end

function M.stats() M.float(M.stats_rows(), ' Drill stats ') end

return M
