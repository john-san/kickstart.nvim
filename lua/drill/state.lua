-- Persistent progress: XP, streak, per-day results, per-drill bests and Leitner boxes per skill.
-- Stored as JSON in stdpath('data')/drill.json (override with setup { data_file = ... }).
local M = {}

local data ---@type table?

M.INTERVAL = { 1, 2, 4, 7, 14 } -- days until a skill in box N is due again
M.TITLES = {
  'Arrow-Key Tourist',
  'hjkl Hiker',
  'Word Walker',
  'Operator Apprentice',
  'Text-Object Tinkerer',
  'Register Wrangler',
  'Macro Mage',
  'Window Warden',
  'Motion Ninja',
  'Neovim Native',
}

function M.path() return require('drill').config.data_file or vim.fs.joinpath(vim.fn.stdpath 'data', 'drill.json') end

local function default()
  return { version = 1, xp = 0, streak = 0, best_streak = 0, last_active = nil, days = {}, skills = {}, drills = {}, misses = {}, speedrun = nil }
end

function M.load()
  if data then return data end
  data = default()
  local f = io.open(M.path(), 'r')
  if f then
    local ok, decoded = pcall(vim.json.decode, f:read '*a', { luanil = { object = true, array = true } })
    f:close()
    if ok and type(decoded) == 'table' then data = vim.tbl_extend('force', data, decoded) end
  end
  return data
end

function M.save()
  if not data then return end
  local path = M.path()
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local tmp = path .. '.tmp'
  local f = assert(io.open(tmp, 'w'))
  f:write(vim.json.encode(data))
  f:close()
  os.remove(path)
  os.rename(tmp, path)
end

--- Forget the cached copy (tests point data_file somewhere else and reload).
function M.unload() data = nil end

function M.reset()
  data = default()
  M.save()
end

function M.today() return os.date '%Y-%m-%d' end

local function to_time(date)
  local y, m, d = date:match '(%d+)-(%d+)-(%d+)'
  return os.time { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }
end

function M.add_days(date, n) return os.date('%Y-%m-%d', to_time(date) + n * 86400) end

function M.days_between(a, b) return math.floor((to_time(b) - to_time(a)) / 86400 + 0.5) end

--- XP needed to reach `level` (level 1 starts at 0).
function M.xp_for(level) return 100 * (level - 1) ^ 2 end

function M.level(xp)
  local level = 1
  while xp >= M.xp_for(level + 1) do
    level = level + 1
  end
  local title = M.TITLES[math.min(level, #M.TITLES)]
  return level, title, xp - M.xp_for(level), M.xp_for(level + 1) - M.xp_for(level)
end

--- Count today toward the daily streak.
function M.touch_streak(today)
  local d = M.load()
  today = today or M.today()
  if d.last_active == today then return end
  if d.last_active and M.days_between(d.last_active, today) == 1 then
    d.streak = d.streak + 1
  else
    d.streak = 1
  end
  d.best_streak = math.max(d.best_streak or 0, d.streak)
  d.last_active = today
end

--- Add XP; returns the new level when this crossed a level boundary.
function M.add_xp(n)
  local d = M.load()
  local before = M.level(d.xp)
  d.xp = d.xp + n
  local after = M.level(d.xp)
  if after > before then return after end
end

---@class drill.Record
---@field passed boolean
---@field failed_any boolean failed or skipped at least once before leaving
---@field hints integer
---@field keys integer? best keys when passed
---@field par integer
---@field seconds number?

--- Store the outcome of one drill and move its skill between Leitner boxes:
--- a clean pass (no fail, no hint, at or under par) promotes, a pass over par holds, anything else demotes to box 1.
---@param drill table
---@param rec drill.Record
function M.record(drill, rec, today)
  local d = M.load()
  today = today or M.today()
  local st = d.drills[drill.id] or { passes = 0, fails = 0 }
  if rec.passed then
    st.passes = st.passes + 1
    st.best_keys = math.min(st.best_keys or math.huge, rec.keys)
    st.best_time = math.min(st.best_time or math.huge, rec.seconds)
  end
  if rec.failed_any or not rec.passed then st.fails = st.fails + 1 end
  st.last = today
  d.drills[drill.id] = st

  local skill = drill.skill or drill.id
  local sk = d.skills[skill] or { box = 1, seen = 0 }
  local clean = rec.passed and not rec.failed_any and rec.hints == 0 and rec.keys <= rec.par
  if clean then
    sk.box = math.min(5, sk.box + 1)
  elseif not (rec.passed and not rec.failed_any) then
    sk.box = 1
  end
  sk.seen = sk.seen + 1
  sk.last = today
  sk.due = M.add_days(today, M.INTERVAL[sk.box])
  d.skills[skill] = sk

  if not rec.passed or rec.failed_any or rec.hints > 0 then
    d.misses[today] = d.misses[today] or {}
    if not vim.tbl_contains(d.misses[today], drill.id) then table.insert(d.misses[today], drill.id) end
  end
  M.touch_streak(today)
end

--- Drill ids missed on the most recent earlier day that has misses ("yesterday's misses").
function M.recent_misses(today)
  local d = M.load()
  today = today or M.today()
  local best
  for date in pairs(d.misses) do
    if date < today and (not best or date > best) then best = date end
  end
  return best and d.misses[best] or {}, best
end

--- Skills whose Leitner interval has elapsed, weakest box first.
function M.due_skills(today)
  local d = M.load()
  today = today or M.today()
  local out = {}
  for name, sk in pairs(d.skills) do
    if not sk.due or sk.due <= today then table.insert(out, { name = name, box = sk.box }) end
  end
  table.sort(out, function(a, b) return a.box == b.box and a.name < b.name or a.box < b.box end)
  return out
end

function M.box(skill)
  local sk = M.load().skills[skill]
  return sk and sk.box or 0
end

function M.day(n)
  local d = M.load()
  d.days[tostring(n)] = d.days[tostring(n)] or {}
  return d.days[tostring(n)]
end

return M
