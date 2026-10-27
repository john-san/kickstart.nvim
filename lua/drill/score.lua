-- Pure scoring rules, kept free of editor state so the tests can call them directly.
local M = {}

M.BASE = 100
M.BOSS_BASE = 300
M.PENALTY = { spam = 5, arrow = 10, mouse = 15, hint = 30 }

--- Keystrokes allowed before an attempt counts as failed.
---@param par integer
function M.budget(par) return math.max(par * 3, par + 15) end

--- Golf name for a key count against par.
function M.label(keys, par)
  local d = keys - par
  if d <= -3 then return 'ALBATROSS' end
  if d == -2 then return 'EAGLE' end
  if d == -1 then return 'BIRDIE' end
  if d == 0 then return 'PAR' end
  if d == 1 then return 'BOGEY' end
  if d == 2 then return 'DOUBLE BOGEY' end
  return ('+%d OVER PAR'):format(d)
end

--- Multiplier for `combo` consecutive clean passes before this one (caps at x2.0).
function M.multiplier(combo) return 1 + 0.1 * math.min(combo or 0, 10) end

---@class drill.ScoreInput
---@field keys integer
---@field par integer
---@field seconds number
---@field hints integer
---@field spam integer
---@field arrows integer
---@field mouse integer
---@field boss boolean?
---@field combo integer

---@param r drill.ScoreInput
---@return { score: integer, label: string, mult: number, lines: string[] }
function M.compute(r)
  local base = r.boss and M.BOSS_BASE or M.BASE
  local eff = r.par / math.max(r.keys, r.par)
  local pts = base * eff
  local lines = { ('base %d x efficiency %.0f%%'):format(base, eff * 100) }
  if r.keys <= r.par then
    local bonus = 25 + 15 * (r.par - r.keys)
    pts = pts + bonus
    lines[#lines + 1] = ('+%d at/under par'):format(bonus)
  end
  -- A drill should take roughly a second per key once it is in your fingers.
  local target = r.par * 1.0 + 4
  if r.seconds <= target then
    pts = pts + 20
    lines[#lines + 1] = '+20 speed'
  end
  local P = M.PENALTY
  local penalty = r.spam * P.spam + r.arrows * P.arrow + r.mouse * P.mouse + r.hints * P.hint
  if penalty > 0 then
    pts = pts - penalty
    lines[#lines + 1] = ('-%d (hjkl spam %d, arrows %d, mouse %d, hints %d)'):format(penalty, r.spam, r.arrows, r.mouse, r.hints)
  end
  local mult = M.multiplier(r.combo)
  pts = math.max(math.floor(base * 0.05), pts) * mult
  if mult > 1 then lines[#lines + 1] = ('x%.1f combo'):format(mult) end
  return { score = math.floor(pts + 0.5), label = M.label(r.keys, r.par), mult = mult, lines = lines }
end

return M
