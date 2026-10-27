-- The 7-day course. Each day file returns { title, why, drills }; a drill is a table of
-- starting state + goal (see README.md, "Drill format"). This module filters out drills
-- whose requirements this config cannot meet and assembles day / review / speedrun queues.
local M = {}

M.DAYS = 7

local cache = {}

function M.day(n)
  if not cache[n] then
    local day = require('drill.curriculum.day' .. n)
    day.n = n
    for i, d in ipairs(day.drills) do
      d.day = n
      d.order = i
      d.skill = d.skill or d.id
    end
    cache[n] = day
  end
  return cache[n]
end

function M.all()
  local out = {}
  for n = 1, M.DAYS do
    vim.list_extend(out, M.day(n).drills)
  end
  return out
end

function M.by_id(id)
  for _, d in ipairs(M.all()) do
    if d.id == id then return d end
  end
end

--- Whether this config can run `d`; the reason names what is missing.
---@return boolean, string?
function M.available(d)
  local req = d.requires or {}
  for _, m in ipairs(req.maps or {}) do
    if vim.fn.maparg(m[2], m[1]) == '' then return false, ('no %s-mode mapping for %s'):format(m[1], m[2]) end
  end
  for _, exe in ipairs(req.exe or {}) do
    if vim.fn.executable(exe) ~= 1 then return false, ('`%s` is not on PATH'):format(exe) end
  end
  for _, p in ipairs(req.parsers or {}) do
    local ok, added = pcall(vim.treesitter.language.add, p)
    if not (ok and added) then return false, ('treesitter parser `%s` is not installed'):format(p) end
  end
  for _, mod in ipairs(req.modules or {}) do
    if not pcall(require, mod) then return false, ('plugin module `%s` is not loaded'):format(mod) end
  end
  if req.lsp_attach and #vim.api.nvim_get_autocmds { event = 'LspAttach' } == 0 then return false, 'no LspAttach mappings' end
  if req.check then
    local ok, why = req.check()
    if not ok then return false, why end
  end
  return true
end

--- Every drill this config cannot run, with the reason.
function M.skipped()
  local out = {}
  for _, d in ipairs(M.all()) do
    local ok, why = M.available(d)
    if not ok then table.insert(out, { drill = d, why = why }) end
  end
  return out
end

local function tagged(d, tag) return setmetatable({ [tag] = true }, { __index = d }) end

local function shuffle(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

--- Warmup: yesterday's misses first, then drills of skills sitting in Leitner box 1 (max `limit`).
function M.warmup(limit, exclude)
  local st = require 'drill.state'
  exclude = exclude or {}
  local out, seen = {}, {}
  local function add(d)
    if #out >= limit or not d or seen[d.id] or exclude[d.id] or d.boss or not M.available(d) then return end
    seen[d.id] = true
    table.insert(out, tagged(d, 'warmup'))
  end
  for _, id in ipairs((st.recent_misses())) do
    add(M.by_id(id))
  end
  for _, sk in ipairs(st.due_skills()) do
    if sk.box <= 1 then
      for _, d in ipairs(M.all()) do
        if d.skill == sk.name then add(d) end
      end
    end
  end
  return out
end

--- A day's queue: warmup, the day's drills, up to two weak-skill reviews, then the boss.
function M.build_day(n, opts)
  opts = opts or {}
  local day = M.day(n)
  local main, boss, ids = {}, {}, {}
  for _, d in ipairs(day.drills) do
    if M.available(d) then
      table.insert(d.boss and boss or main, d)
      ids[d.id] = true
    end
  end
  local queue = M.warmup(opts.warmup or 4, ids)
  vim.list_extend(queue, main)
  local st = require 'drill.state'
  local reviews = 0
  for _, sk in ipairs(st.due_skills()) do
    if reviews >= 2 or sk.box > 1 then break end
    for _, d in ipairs(M.all()) do
      if d.skill == sk.name and d.day < n and not ids[d.id] and not d.boss and M.available(d) then
        local already = false
        for _, q in ipairs(queue) do
          already = already or q.id == d.id
        end
        if not already then
          table.insert(queue, tagged(d, 'review'))
          reviews = reviews + 1
          break
        end
      end
    end
  end
  vim.list_extend(queue, boss)
  return queue
end

--- Random non-boss drills from the days you have reached.
function M.speedrun(count)
  local st = require 'drill.state'
  local reached = 1
  for n = 1, M.DAYS do
    if (st.load().days[tostring(n)] or {}).last then reached = math.max(reached, n) end
  end
  local pool = {}
  for n = 1, reached do
    for _, d in ipairs(M.day(n).drills) do
      if not d.boss and not d.no_speedrun and M.available(d) then table.insert(pool, d) end
    end
  end
  math.randomseed(os.time())
  return vim.list_slice(shuffle(pool), 1, count)
end

--- Leitner review: drills of skills that are due, weakest first.
function M.review(limit)
  local st = require 'drill.state'
  local out, seen = {}, {}
  for _, sk in ipairs(st.due_skills()) do
    for _, d in ipairs(M.all()) do
      if #out < limit and d.skill == sk.name and not seen[d.skill] and not d.boss and M.available(d) then
        seen[d.skill] = true
        table.insert(out, tagged(d, 'review'))
      end
    end
  end
  return out
end

return M
