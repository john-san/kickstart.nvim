-- drill: a gamified 7-day course that drills this config's own motions, plugins and keymaps
-- inside the real editor. setup() only defines commands; everything else loads on first use.
-- See lua/drill/README.md.
local M = {}

M.config = {
  data_file = nil, -- default: stdpath('data')/drill.json
  warmup = 4, -- max warmup drills (yesterday's misses) before a day
  speedrun = 10, -- drills per speedrun
}

local SUBCOMMANDS = { 'today', 'review', 'warmup', 'speedrun', 'list', 'reset', 'quit', 'retry', 'skip', 'hint', 'next' }

local function start_day(n)
  local cur = require 'drill.curriculum'
  if not n or n < 1 or n > cur.DAYS then return vim.notify(('drill: day must be 1-%d'):format(cur.DAYS), vim.log.levels.ERROR) end
  local day = cur.day(n)
  local queue = cur.build_day(n, { warmup = M.config.warmup })
  vim.notify(('Day %d · %s\n%s'):format(n, day.title, day.why), vim.log.levels.INFO, { title = 'drill' })
  require('drill.runner').start(queue, { mode = 'day', day = n, header = ('DAY %d · %s'):format(n, day.title) })
end

--- First day not completed yet.
local function current_day()
  local d = require('drill.state').load()
  for n = 1, require('drill.curriculum').DAYS do
    if not (d.days[tostring(n)] or {}).completed then return n end
  end
end

local function list()
  local cur = require 'drill.curriculum'
  local rows = {}
  for n = 1, cur.DAYS do
    local day = cur.day(n)
    table.insert(rows, { { ('Day %d · %s'):format(n, day.title), 'DrillTitle' } })
    for _, d in ipairs(day.drills) do
      local ok, why = cur.available(d)
      table.insert(rows, {
        { ok and '  ✔ ' or '  ✘ ', ok and 'DrillGood' or 'DrillBad' },
        { ('%-30s'):format(d.id), 'DrillDim' },
        { d.title .. (d.boss and '  ☠' or '') },
        { ok and '' or ('  (' .. why .. ')'), 'DrillWarn' },
      })
    end
  end
  require('drill.ui').float(rows, ' Drills (:Drill <id> runs one) ')
end

function M.drill(args)
  local a = vim.trim(args.args or '')
  local cur = require 'drill.curriculum'
  local runner = require 'drill.runner'
  if a == '' or a == 'today' then
    local n = current_day()
    if n then return start_day(n) end
    a = 'review'
  end
  if a == 'review' then
    local q = cur.review(12)
    if #q == 0 then return vim.notify('drill: nothing is due. Try :Drill speedrun', vim.log.levels.INFO) end
    return runner.start(q, { mode = 'review', header = 'LEITNER REVIEW' })
  elseif a == 'warmup' then
    local q = cur.warmup(M.config.warmup)
    if #q == 0 then return vim.notify('drill: no misses to warm up on', vim.log.levels.INFO) end
    return runner.start(q, { mode = 'warmup', header = 'WARMUP' })
  elseif a == 'speedrun' then
    return runner.start(cur.speedrun(M.config.speedrun), { mode = 'speedrun', header = 'SPEEDRUN' })
  elseif a == 'list' then
    return list()
  elseif a == 'quit' then
    if runner.current then runner.current:quit() end
    return
  elseif a == 'retry' or a == 'skip' or a == 'hint' or a == 'next' then
    -- The same as <M-r>/<M-s>/<M-/> and the panel's `n`, for terminals that eat Alt keys.
    local s = runner.current
    if not s then return vim.notify('drill: no session is running', vim.log.levels.WARN) end
    -- Typing the command is not part of the drill: refund its keys.
    local typed = vim.fn.histget(':', -1)
    if s.phase == 'attempt' and typed:match '^%s*Dri' then
      s.attempt.keys = math.max(0, s.attempt.keys - require('drill.keys').count(':' .. typed) - 1)
    end
    if a ~= 'next' then return s:control(a) end
    if s.phase == 'passed' or s.phase == 'failed' or s.phase == 'done' then s:advance() end
    return
  elseif a == 'reset' then
    if not args.bang then return vim.notify('drill: :Drill! reset erases all progress', vim.log.levels.WARN) end
    require('drill.state').reset()
    return vim.notify('drill: progress reset', vim.log.levels.INFO)
  end
  local d = cur.by_id(a)
  if not d then return vim.notify('drill: unknown drill or subcommand: ' .. a, vim.log.levels.ERROR) end
  local ok, why = cur.available(d)
  if not ok then return vim.notify(('drill: %s is unavailable: %s'):format(a, why), vim.log.levels.WARN) end
  runner.start({ d }, { mode = 'single', header = 'DRILL · ' .. d.id })
end

local did_setup = false

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  if did_setup then return end
  did_setup = true
  local cmd = vim.api.nvim_create_user_command
  cmd('Drill', M.drill, {
    nargs = '?',
    bang = true,
    desc = 'Run today\'s drills (or: review, warmup, speedrun, list, retry, skip, hint, next, quit, <drill id>)',
    complete = function(lead)
      local items = vim.deepcopy(SUBCOMMANDS)
      if lead ~= '' and not vim.tbl_contains(SUBCOMMANDS, lead) then
        for _, d in ipairs(require('drill.curriculum').all()) do
          table.insert(items, d.id)
        end
      end
      return vim.tbl_filter(function(s) return s:find(lead, 1, true) == 1 end, items)
    end,
  })
  cmd('DrillDay', function(a) start_day(tonumber(a.args)) end, {
    nargs = 1,
    desc = 'Run day N of the drill course',
    complete = function() return { '1', '2', '3', '4', '5', '6', '7' } end,
  })
  cmd('DrillStats', function() require('drill.ui').stats() end, { desc = 'Drill progress, skills and streak' })
end

return M
