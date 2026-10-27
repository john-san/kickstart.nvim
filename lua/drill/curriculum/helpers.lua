-- Building blocks shared by the day files.
local api = vim.api
local goal = require 'drill.goal'
local H = {}

--- Visit positions in order. The session re-checks after every key, so each stop is seen
--- even when the next motion follows immediately. Returns fields to merge into a drill.
function H.tour(targets)
  local function mark(ctx)
    api.nvim_buf_clear_namespace(ctx.buf, require('drill.ui').ns, 0, -1)
    local p = ctx.tour[ctx.stage + 1]
    if p then require('drill.ui').mark_target(ctx.buf, p[1], p[2]) end
  end
  return {
    setup = function(ctx)
      ctx.stage = 0
      ctx.tour = vim.tbl_map(function(t) return { goal.pos(t, ctx.start_lines) } end, targets)
      vim.schedule(function() mark(ctx) end)
    end,
    check = function(ctx)
      local p = ctx.tour[ctx.stage + 1]
      if p and api.nvim_get_current_buf() == ctx.buf and api.nvim_get_mode().mode == 'n' then
        local c = api.nvim_win_get_cursor(0)
        if c[1] == p[1] and (p[2] == nil or c[2] == p[2]) then
          ctx.stage = ctx.stage + 1
          mark(ctx)
        end
      end
      return ctx.stage == #ctx.tour, ('stop %d/%d'):format(ctx.stage, #ctx.tour)
    end,
  }
end

--- Merge `extra` into a drill's fields (goal.check is combined with tour/flag checks).
function H.with(drill, extra)
  for k, v in pairs(extra) do
    if k == 'check' then
      drill.goal = drill.goal or {}
      drill.goal.check = v
    else
      drill[k] = v
    end
  end
  return drill
end

--- Row the cursor would land on after `keys` (run with normal!, view and jumps untouched).
function H.simulate(keys)
  local view = vim.fn.winsaveview()
  vim.cmd('keepjumps normal! ' .. vim.keycode(keys))
  local row = api.nvim_win_get_cursor(0)[1]
  vim.fn.winrestview(view)
  return row
end

--- A window whose buffer has filetype `ft` is open in the current tabpage.
function H.win_with_ft(ft)
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    if vim.bo[api.nvim_win_get_buf(w)].filetype == ft then return w end
  end
end

--- A floating window (other than the drill panel) whose text contains `needle`.
function H.float_with(needle)
  local panel = require('drill.runner').current and require('drill.runner').current.panel_win
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    if w ~= panel and api.nvim_win_get_config(w).relative ~= '' then
      local text = table.concat(api.nvim_buf_get_lines(api.nvim_win_get_buf(w), 0, -1, false), '\n')
      if not needle or text:find(needle, 1, true) then return w end
    end
  end
end

function H.telescope_open() return H.win_with_ft 'TelescopePrompt' ~= nil end

--- Solution step for the tests: wait until a Telescope prompt is open, then let results settle.
function H.wait_picker(ms) return { wait_for = H.telescope_open, timeout = 4000, settle = ms or 400 } end

--- Title of the open Telescope picker, if any.
function H.picker_title()
  local w = H.win_with_ft 'TelescopePrompt'
  if not w then return end
  local ok, picker = pcall(require('telescope.actions.state').get_current_picker, api.nvim_win_get_buf(w))
  return ok and picker and picker.prompt_title or nil
end

--- Close an open Telescope picker (teardown for drills whose goal leaves one open).
function H.close_picker()
  local w = H.win_with_ft 'TelescopePrompt'
  if w then pcall(require('telescope.actions').close, api.nvim_win_get_buf(w)) end
end

--- Passes once `seen(ctx)` has been true at some point and `done(ctx)` is true now:
--- "open X, then close it again" drills.
function H.round_trip(seen, done)
  return function(ctx)
    if seen(ctx) then ctx.seen = true end
    return ctx.seen and done(ctx), ctx.seen and 'not closed yet' or 'not opened yet'
  end
end

-- [[ Shared sample code ]]

-- InvoiceService.cs as committed, and a working copy with one changed line and an added debug block.
H.INVOICE_BASE = [[
public class InvoiceService
{
    public Invoice Create(Order order)
    {
        var invoice = new Invoice(order.Id);
        invoice.Lines.AddRange(order.Lines.Select(ToLine));
        return invoice;
    }

    public void Send(Invoice invoice)
    {
        _mailer.Send(invoice.Customer.Email, Render(invoice));
    }
}
]]

H.INVOICE_DIRTY = [[
public class InvoiceService
{
    public Invoice Create(Order order)
    {
        var invoice = new Invoice(order.Id, order.Currency);
        invoice.Lines.AddRange(order.Lines.Select(ToLine));
        return invoice;
    }

    public void Send(Invoice invoice)
    {
        Console.WriteLine("sending " + invoice.Id);
        Console.WriteLine(invoice.Customer.Email);
        _mailer.Send(invoice.Customer.Email, Render(invoice));
    }
}
]]

H.PROJECT = {
  ['Orders/OrderService.cs'] = 'namespace Shop.Orders;\n\npublic class OrderService { }\n',
  ['Orders/OrderRepository.cs'] = 'namespace Shop.Orders;\n\npublic class OrderRepository { }\n',
  ['Orders/Order.cs'] = 'namespace Shop.Orders;\n\npublic class Order { }\n',
}

H.GIT = { exe = { 'git' }, modules = { 'gitsigns' } }

return H
