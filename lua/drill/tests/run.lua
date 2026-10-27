-- Headless tests for the drill course, run against your real config:
--   nvim --headless -l lua/drill/tests/run.lua            all drills
--   nvim --headless -l lua/drill/tests/run.lua 2           day 2 only
--   nvim --headless -l lua/drill/tests/run.lua motion.     ids containing "motion."
-- For every drill this config can run: the start state must NOT pass (a no-op fails), and the
-- known solution, replayed as typed keys through your mappings, must pass. Progress goes to a
-- temp file, never to your real drill.json.
local out = io.stdout
local function say(...)
  out:write(string.format(...), '\n')
  out:flush()
end

-- `-l` skips init.lua, so load the config the drills are meant to exercise.
if vim.g.mapleader == nil then vim.cmd.source(vim.fs.joinpath(vim.fn.stdpath 'config', 'init.lua')) end
-- Normal startup enables these after init.lua; `-l` does not, and without them ftplugins
-- (commentstring for gc, indent rules) and filetype detection for :edit are missing.
vim.cmd 'filetype plugin indent on'
vim.cmd 'syntax on'
vim.wait(200) -- let startup's vim.schedule work (clipboard, etc.) run
-- Note: do not resize the headless screen here; with no UI attached, nvim exits (code 127)
-- as soon as flash.nvim draws its labels on a resized grid.

local tmp = vim.fn.tempname() .. '-drill.json'
require('drill').setup()
require('drill').config.data_file = tmp
local state = require 'drill.state'
state.unload()

local failures, passes, skipped = {}, 0, {}
local function fail(name, msg)
  table.insert(failures, name .. ': ' .. msg)
  say('  FAIL %s: %s', name, msg)
end
local function expect(name, cond, msg)
  if cond then
    passes = passes + 1
  else
    fail(name, msg)
  end
end

-- [[ Unit checks ]]
do
  local keys = require 'drill.keys'
  expect('keys.count', keys.count 'ci"new<Esc>' == 7, 'ci"new<Esc> should be 7 keys')
  expect('keys.count', keys.count '<Space>sf' == 3, '<Space>sf should be 3 keys')
  expect('keys.cost', keys.cost '<leader>a' == 2, '<leader>a should cost 2')
  expect('keys.classify', keys.classify('j', 'n') == 'hjkl' and keys.classify('j', 'i') == nil, 'j is a motion only outside insert mode')
  expect('keys.classify', keys.classify('<Up>', 'i') == 'arrow' and keys.classify('<LeftMouse>', 'n') == 'mouse', 'arrows and mouse')

  local score = require 'drill.score'
  expect('score.label', score.label(4, 6) == 'EAGLE' and score.label(6, 6) == 'PAR' and score.label(7, 6) == 'BOGEY', 'golf labels')
  local base = { keys = 6, par = 6, seconds = 60, hints = 0, spam = 0, arrows = 0, mouse = 0, combo = 0 }
  local at_par = score.compute(base).score
  expect('score.par', at_par == 125, 'par with no bonus should score 125, got ' .. at_par)
  expect('score.over', score.compute(vim.tbl_extend('force', base, { keys = 12 })).score < at_par, 'over par scores less')
  expect('score.combo', score.compute(vim.tbl_extend('force', base, { combo = 5 })).score > at_par, 'combo multiplies')
  expect('score.spam', score.compute(vim.tbl_extend('force', base, { spam = 4, arrows = 1 })).score == 125 - 30, 'penalties subtract')

  local d0 = { id = 'unit.a', skill = 'unit.skill' }
  state.record(d0, { passed = true, failed_any = false, hints = 0, keys = 5, par = 5, seconds = 3 }, '2026-01-01')
  expect('leitner.promote', state.box 'unit.skill' == 2, 'clean pass promotes to box 2')
  state.record(d0, { passed = true, failed_any = false, hints = 0, keys = 9, par = 5, seconds = 3 }, '2026-01-02')
  expect('leitner.hold', state.box 'unit.skill' == 2, 'pass over par holds the box')
  state.record(d0, { passed = true, failed_any = true, hints = 0, keys = 5, par = 5, seconds = 3 }, '2026-01-03')
  expect('leitner.demote', state.box 'unit.skill' == 1, 'a fail demotes to box 1')
  expect('misses', vim.deep_equal(state.recent_misses '2026-01-04', { 'unit.a' }), 'yesterday\'s miss is listed')
  expect('streak', state.load().streak == 3, 'three consecutive days make a streak of 3, got ' .. state.load().streak)
  state.record(d0, { passed = true, failed_any = false, hints = 0, keys = 5, par = 5, seconds = 3 }, '2026-01-06')
  expect('streak.break', state.load().streak == 1, 'a missed day resets the streak')
  expect('level', state.level(0) == 1 and state.level(100) == 2 and state.level(8100) == 10, 'level curve')
  state.unload()
  os.remove(tmp)
end

-- [[ Drill replays ]]
local cur = require 'drill.curriculum'
local runner = require 'drill.runner'
local filter = arg and arg[1]

local function steps(sol)
  if type(sol) == 'string' then return { sol } end
  return sol
end

local function run_drill(d)
  local name = d.id
  local s = runner.start({ d }, { test = true, mode = 'single', header = 'TEST' })
  if not vim.wait(12000, function() return s.phase == 'attempt' end, 20) then
    fail(name, 'never became ready (phase ' .. tostring(s.phase) .. ')')
    return s:quit()
  end
  vim.wait(30)
  if s:check() or s.phase ~= 'attempt' then
    fail(name, 'passes from the starting state (a no-op must fail)')
    return s:quit()
  end
  for _, step in ipairs(steps(d.solution)) do
    if type(step) == 'string' then
      local ok, err = pcall(vim.api.nvim_feedkeys, vim.keycode(step), 'mtx', false)
      if not ok then fail(name, 'keys raised: ' .. tostring(err)) end
    elseif step.wait then
      vim.wait(step.wait)
    elseif step.wait_for then
      vim.wait(step.timeout or 4000, function()
        local ok, yes = pcall(step.wait_for, s.ctx)
        return ok and yes
      end, 20)
      if step.settle then vim.wait(step.settle) end
    end
    vim.wait(20)
  end
  local passed = vim.wait(4000, function() return s.phase == 'passed' end, 20)
  if not passed then
    local _, _, why = pcall(require('drill.goal').check, d, s.ctx or {})
    local buf = s.ctx and s.ctx.buf
    local detail = ''
    if buf and vim.api.nvim_buf_is_valid(buf) then
      local cur = vim.api.nvim_win_get_cursor(0)
      detail = ('\n      mode %s, cursor %d:%d in %s\n      | %s'):format(
        vim.api.nvim_get_mode().mode,
        cur[1],
        cur[2],
        vim.api.nvim_buf_get_name(0),
        table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n      | ')
      )
    end
    fail(name, ('solution did not pass (%s)%s'):format(tostring(why), detail))
  else
    passes = passes + 1
    local keys = s.attempt.keys
    if keys ~= s.par then say('  note %s: counted %d keys, par %d', name, keys, s.par) end
  end
  s:quit()
  if #vim.api.nvim_list_tabpages() ~= 1 then
    fail(name, 'left extra tabpages behind')
    vim.cmd 'silent! tabonly!'
  end
end

for n = 1, cur.DAYS do
  local day = cur.day(n)
  local ran = false
  for _, d in ipairs(day.drills) do
    if not filter or tostring(n) == filter or d.id:find(filter, 1, true) then
      if not ran then
        say('Day %d · %s', n, day.title)
        ran = true
      end
      local ok, why = cur.available(d)
      if ok and d.test_skip then
        table.insert(skipped, ('%s (not replayable here: %s)'):format(d.id, d.test_skip))
        say('  skip %-29s not replayable here: %s', d.id, d.test_skip)
      elseif ok then
        local t0 = vim.uv.hrtime()
        run_drill(d)
        say('  %-34s %5.0f ms', d.id, (vim.uv.hrtime() - t0) / 1e6)
      else
        table.insert(skipped, ('%s (%s)'):format(d.id, why))
        say('  skip %-29s %s', d.id, why)
      end
    end
  end
end

-- Sessions must restore what they borrowed.
expect('restore.clipboard', vim.o.clipboard == 'unnamedplus', 'clipboard option restored, got ' .. vim.o.clipboard)

os.remove(tmp)
say('\n%d checks passed, %d failed, %d drills skipped', passes, #failures, #skipped)
for _, f in ipairs(failures) do
  say('  ✘ %s', f)
end
os.exit(#failures == 0 and 0 or 1)
