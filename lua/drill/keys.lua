-- Keystroke accounting. vim.on_key reports typed keys in chunks (a whole mapping lhs such as
-- `gsa` arrives at once), so everything here works on keytrans() notation.
local M = {}

--- Number of keys in a notation string: each <...> token is one key, every other character is one.
---@param notation string
---@return integer
function M.count(notation)
  local n, i = 0, 1
  while i <= #notation do
    local tok = notation:match('^<[^<>]+>', i)
    if tok then
      i = i + #tok
    else
      local c = notation:byte(i)
      i = i + (c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or 4)
    end
    n = n + 1
  end
  return n
end

--- Keys a solution costs, with <leader> resolved the same way a mapping would.
---@param keys string
function M.cost(keys) return M.count(vim.fn.keytrans(vim.keycode(keys))) end

--- Total keys of a solution: a key string or a list of key strings and { wait = ms } steps.
---@param solution string|table
function M.solution_cost(solution)
  if type(solution) == 'string' then return M.cost(solution) end
  local n = 0
  for _, step in ipairs(solution) do
    if type(step) == 'string' then n = n + M.cost(step) end
  end
  return n
end

local ARROWS = { ['<Up>'] = true, ['<Down>'] = true, ['<Left>'] = true, ['<Right>'] = true }
local HJKL = { h = true, j = true, k = true, l = true }
local MOTION_MODES = { n = true, v = true, V = true, ['\22'] = true }

---@param t string keytrans() of one typed chunk
---@return 'arrow'|'mouse'|'hjkl'|'count'|'mouse_noise'|nil
function M.classify(t, mode)
  if ARROWS[t] then return 'arrow' end
  if t:match 'Mouse>$' or t:match '^<.*ScrollWheel' then return 'mouse' end
  if t:match 'Release>$' or t:match 'Drag>$' or t == '<MouseMove>' then return 'mouse_noise' end
  if HJKL[t] and MOTION_MODES[mode] then return 'hjkl' end
  if t:match '^%d$' and mode == 'n' then return 'count' end
end

return M
