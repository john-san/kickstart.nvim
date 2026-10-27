-- Goal checks inspect real editor state (buffer text, cursor, mode, windows, registers...),
-- never the keys that were pressed, so any valid solution passes.
local api = vim.api
local M = {}

--- Split a drill text block into lines. A single leading newline is dropped so
--- [[
--- text]] reads naturally in the curriculum files.
---@param s string|string[]
function M.lines(s)
  if type(s) == 'table' then return s end
  s = s:gsub('^\n', '')
  local out = vim.split(s, '\n', { plain = true })
  if #out > 1 and out[#out] == '' then table.remove(out) end
  return out
end

--- Resolve a position against buffer lines. Rows are 1-based, columns 0-based
--- (nvim_win_get_cursor convention). Accepted forms:
---   { row, col }  { row }  (any column)
---   { row, 'needle', offset, nth }  needle on that row
---   { 'needle', offset, nth, line = true, dr = n }  nth occurrence anywhere; `line` = any column, `dr` shifts the row
---@return integer row, integer? col
function M.pos(spec, lines)
  if type(spec[1]) == 'string' then
    local needle, off, nth, k = spec[1], spec[2] or 0, spec[3] or 1, 0
    for r, l in ipairs(lines) do
      local init = 1
      while true do
        local s = l:find(needle, init, true)
        if not s then break end
        k = k + 1
        if k == nth then
          if spec.line or spec.dr then return r + (spec.dr or 0), nil end
          return r, s - 1 + off
        end
        init = s + 1
      end
    end
    error(('needle %q not found'):format(needle))
  end
  local row, col = spec[1], spec[2]
  if type(col) == 'string' then
    local line = lines[row] or ''
    local init = 1
    for _ = 1, (spec[4] or 1) do
      local s = line:find(col, init, true)
      assert(s, ('needle %q not found on line %d: %q'):format(col, row, line))
      col, init = s - 1, s + 1
    end
    col = col + (spec[3] or 0)
  end
  return row, col
end

local function norm(p) return (p:gsub('\\', '/')) end

local function session_tabs(ctx)
  local n = 0
  for _, t in ipairs(api.nvim_list_tabpages()) do
    if not ctx.base_tabs[t] then n = n + 1 end
  end
  return n
end

M.session_tabs = session_tabs

--- Normal (non-floating) windows in the current tabpage.
function M.windows()
  local out = {}
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_get_config(w).relative == '' then table.insert(out, w) end
  end
  return out
end

---@param drill table
---@param ctx table
---@return boolean ok, string? why
function M.check(drill, ctx)
  local g = drill.goal
  local want_mode = g.mode == nil and 'n' or g.mode
  if want_mode and api.nvim_get_mode().mode ~= want_mode then return false, 'mode' end

  if g.text then
    local want = M.lines(g.text)
    if not api.nvim_buf_is_valid(ctx.buf) then return false, 'buffer gone' end
    local have = api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
    if #have ~= #want then return false, 'text' end
    for i = 1, #want do
      if have[i] ~= want[i] then return false, 'text' end
    end
  end

  if g.file and not norm(api.nvim_buf_get_name(0)):match(g.file) then return false, 'file' end

  if g.cursor then
    if not g.file and api.nvim_get_current_buf() ~= ctx.buf then return false, 'cursor buffer' end
    -- Needles resolve against the target text once, at load (ctx.goal_pos); other files resolve live.
    local row, col
    if ctx.goal_pos then
      row, col = ctx.goal_pos[1], ctx.goal_pos[2]
    else
      local ok, r, c = pcall(M.pos, g.cursor, api.nvim_buf_get_lines(0, 0, -1, false))
      if not ok then return false, 'cursor' end
      row, col = r, c
    end
    local cur = api.nvim_win_get_cursor(0)
    if cur[1] ~= row or (col and cur[2] ~= col) then return false, 'cursor' end
  end

  if g.windows and #M.windows() ~= g.windows then return false, 'windows' end
  if g.tabs and session_tabs(ctx) ~= g.tabs then return false, 'tabs' end

  if g.register then
    local r = g.register
    local val = vim.fn.getreg(r[1])
    if r.type and vim.fn.getregtype(r[1]):sub(1, 1) ~= r.type then return false, 'register type' end
    if r[2] and val:gsub('\n$', '') ~= r[2] then return false, 'register' end
    if r.contains and not val:find(r.contains, 1, true) then return false, 'register' end
  end

  if g.qf then
    local n = #vim.fn.getqflist()
    if (type(g.qf) == 'number' and n ~= g.qf) or (g.qf == true and n == 0) then return false, 'quickfix' end
  end

  if g.check then
    local ok, why = g.check(ctx)
    if not ok then return false, why or 'check' end
  end
  return true
end

return M
