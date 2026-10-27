local api = vim.api
local H = require 'drill.curriculum.helpers'

local SERVICE = [[
namespace Shop.Orders;

public class OrderService
{
    private readonly OrderRepository _repo;

    public OrderService(OrderRepository repo) => _repo = repo;

    public Order Load(int id)
    {
        // TODO: cache hot orders
        return _repo.GetById(id);
    }

    public void Save(Order order)
    {
        _repo.SaveAsync(order).GetAwaiter().GetResult();
    }
}
]]

local REPO = [[
namespace Shop.Orders;

// Used by OrderService; see Orders/Order.cs for the entity.
public class OrderRepository
{
    public Order GetById(int id)
    {
        // TODO: use AsNoTracking for reads
        return _db.Orders.Single(o => o.Id == id);
    }

    public Task SaveAsync(Order order) => _db.SaveChangesAsync();
}
]]

local ORDER = [[
namespace Shop.Orders;

public class Order
{
    public int Id { get; set; }
    public decimal Total { get; set; }
    public OrderStatus Status { get; set; }
}
]]

local FILES = { ['Orders/OrderRepository.cs'] = REPO, ['Orders/Order.cs'] = ORDER }

--- A drill that starts in Orders/OrderService.cs with the other two files on disk.
local function project(drill)
  drill.ft = 'cs'
  drill.file = drill.file or 'Orders/OrderService.cs'
  drill.text = drill.text or SERVICE
  drill.files = drill.files or FILES
  return drill
end

local function layout() return vim.fn.winlayout()[1] end

local function cur_file() return (api.nvim_buf_get_name(0):gsub('\\', '/')) end

--- Fill the quickfix list with every TODO in the workspace, current entry 1.
local function todo_qf()
  vim.cmd 'silent noautocmd vimgrep /TODO/j Orders/OrderService.cs Orders/OrderRepository.cs'
end

return {
  title = 'Windows, buffers, tabs, quickfix',
  why = 'Real work spans files: a definition here, a caller there, a list of compiler errors. '
    .. 'Splits, the alternate file, :b, the quickfix list and global marks let you move between them '
    .. 'without reaching for a file tree or the mouse.',
  drills = {
    project {
      id = 'd4.vsplit',
      skill = 'splits',
      title = 'Side by side',
      task = 'Split this window vertically.',
      goal = { windows = 2, check = function() return layout() == 'row' end },
      solution = '<C-w>v',
      hint = '<C-w>v splits vertically, <C-w>s horizontally (your <leader>| and <leader>- do the same).',
    },
    project {
      id = 'd4.window-nav',
      skill = 'window nav',
      title = 'Move between windows',
      task = 'Put the cursor in the window showing OrderRepository.cs (bottom right).',
      setup = function()
        vim.cmd 'rightbelow vsplit Orders/Order.cs'
        vim.cmd 'rightbelow split Orders/OrderRepository.cs'
        vim.cmd 'wincmd h'
      end,
      goal = { file = 'Orders/OrderRepository%.cs$', windows = 3 },
      solution = '<C-l><C-j>',
      hint = 'Your config maps <C-h/j/k/l> to <C-w>h/j/k/l.',
    },
    project {
      id = 'd4.only',
      skill = 'splits',
      title = 'Close everything else',
      task = 'Keep only the current window.',
      setup = function()
        vim.cmd 'rightbelow vsplit Orders/Order.cs'
        vim.cmd 'rightbelow split Orders/OrderRepository.cs'
        vim.cmd 'wincmd h'
      end,
      goal = { windows = 1, file = 'Orders/OrderService%.cs$' },
      solution = '<C-w>o',
      hint = '<C-w>o (:only). <C-w>c / :q close just the current window.',
    },
    project {
      id = 'd4.equalize',
      skill = 'splits',
      title = 'Even out the splits',
      task = 'Make both windows the same width again.',
      setup = function()
        vim.cmd 'rightbelow vsplit Orders/Order.cs'
        vim.cmd 'vertical resize 20'
        vim.cmd 'wincmd h'
      end,
      goal = {
        windows = 2,
        check = function()
          local w = H.win_with_ft 'cs' and vim.tbl_map(api.nvim_win_get_width, require('drill.goal').windows())
          return w and #w == 2 and math.abs(w[1] - w[2]) <= 1
        end,
      },
      solution = '<C-w>=',
      hint = '<C-w>= equalises every split. Your <C-Left>/<C-Right> resize by 2.',
    },
    project {
      id = 'd4.alternate',
      skill = 'buffers',
      title = 'The alternate file',
      task = 'You came here from Order.cs. Flip back to it with one key.',
      setup = function()
        vim.cmd 'edit Orders/Order.cs'
        vim.cmd 'edit Orders/OrderService.cs'
      end,
      goal = { file = 'Orders/Order%.cs$' },
      solution = '<C-^>',
      hint = '<C-^> (Ctrl-6) toggles between the current and the previous buffer.',
    },
    project {
      id = 'd4.buffer-name',
      skill = 'buffers',
      title = 'Switch buffer by name',
      task = 'Switch to OrderRepository.cs, which is already loaded, by typing part of its name.',
      setup = function()
        vim.cmd 'badd Orders/OrderRepository.cs'
        vim.cmd 'badd Orders/Order.cs'
      end,
      goal = { file = 'Orders/OrderRepository%.cs$' },
      solution = ':b Repo<CR>',
      hint = ':b takes any unique part of a buffer name (Tab completes). Your <leader><leader> is the fuzzy version.',
    },
    project {
      id = 'd4.gf',
      skill = 'gf',
      title = 'Go to the file under the cursor',
      task = 'The comment mentions the entity file. Open it straight from the path.',
      file = 'Orders/OrderRepository.cs',
      text = REPO,
      files = { ['Orders/Order.cs'] = ORDER },
      cursor = { 'Orders/Order.cs', 0 },
      goal = { file = 'Orders/Order%.cs$' },
      solution = 'gf',
      hint = 'gf opens the path under the cursor; <C-o> brings you back.',
    },
    project {
      id = 'd4.quickfix',
      skill = 'quickfix',
      title = 'Walk the quickfix list',
      task = 'The quickfix list holds both TODOs. Jump to the second one (in OrderRepository.cs).',
      setup = todo_qf,
      goal = { file = 'Orders/OrderRepository%.cs$', cursor = { 'TODO: use AsNoTracking', 0 } },
      solution = ']q',
      hint = ']q / [q are :cnext / :cprevious (your config centres after). :copen shows the list.',
    },
    project {
      id = 'd4.cdo',
      skill = 'quickfix',
      title = 'Rename across files with :cdo',
      task = 'The quickfix list has every `GetById`. Rename them all to FindById\n(two files; no need to save).',
      setup = function() vim.cmd 'silent noautocmd vimgrep /GetById/j Orders/*.cs' end,
      goal = {
        check = function()
          local found = 0
          for _, b in ipairs(api.nvim_list_bufs()) do
            if api.nvim_buf_is_loaded(b) and api.nvim_buf_get_name(b):match 'Order%a*%.cs$' then
              local text = table.concat(api.nvim_buf_get_lines(b, 0, -1, false), '\n')
              if text:find('GetById', 1, true) then return false end
              local _, n = text:gsub('FindById', '')
              found = found + n
            end
          end
          return found == 2
        end,
      },
      solution = ':cdo s/GetById/FindById/<CR>',
      hint = ':cdo runs a command on every quickfix entry (:cfdo once per file). Add | update to save.',
    },
    project {
      id = 'd4.tab-T',
      skill = 'tabs',
      title = 'Give a split its own tab',
      task = 'Move the Order.cs split into a new tab.',
      setup = function() vim.cmd 'rightbelow vsplit Orders/Order.cs' end,
      goal = { tabs = 1, file = 'Orders/Order%.cs$', windows = 1 },
      solution = '<C-w>T',
      hint = '<C-w>T moves the current window to a new tab. gt / gT switch tabs; :tabclose closes one.',
    },
    project {
      id = 'd4.gt',
      skill = 'tabs',
      title = 'Next tab',
      task = 'Order.cs is open in the next tab. Go there.',
      setup = function()
        vim.cmd 'tabedit Orders/Order.cs'
        vim.cmd 'tabprevious'
      end,
      goal = { file = 'Orders/Order%.cs$', check = function(ctx) return not ctx.base_tabs[api.nvim_get_current_tabpage()] end },
      solution = 'gt',
      hint = 'gt next tab, gT previous, 3gt tab number 3.',
    },
    H.with(project {
      id = 'd4.global-mark',
      skill = 'marks',
      title = 'A bookmark that crosses files',
      task = 'Set mark A on the SaveAsync line, hop to Order.cs (the alternate file),\nthen jump straight back with the mark.',
      cursor = { '_repo.SaveAsync', 0 },
      setup = function(ctx)
        vim.cmd 'edit Orders/Order.cs'
        vim.cmd 'edit Orders/OrderService.cs'
        local goal = require 'drill.goal'
        api.nvim_win_set_cursor(0, { goal.pos({ '_repo.SaveAsync', line = true }, ctx.start_lines), 8 })
        ctx.seen_order = false
      end,
      goal = {},
      solution = { 'mA', '<C-^>', "'A" },
      hint = "Uppercase marks are global: mA here, <C-^> away, 'A jumps back into this file.",
    }, {
      check = function(ctx)
        if cur_file():match 'Orders/Order%.cs$' then ctx.seen_order = true end
        local m = api.nvim_get_mark('A', {})
        local row = require('drill.goal').pos({ '_repo.SaveAsync', line = true }, ctx.start_lines)
        return ctx.seen_order and m[1] == row and cur_file():match 'OrderService%.cs$' and api.nvim_win_get_cursor(0)[1] == row
      end,
    }),
    project {
      id = 'd4.boss',
      skill = 'windows-mixed',
      title = 'Fix a TODO beside your code',
      task = 'Split vertically; in the new window jump to the next quickfix TODO (OrderRepository.cs),\nchange `TODO` to `DONE`, then return to the left window.',
      setup = todo_qf,
      goal = {
        windows = 2,
        file = 'Orders/OrderService%.cs$',
        check = function()
          if layout() ~= 'row' or vim.fn.winnr() ~= 1 then return false end
          local b = vim.fn.bufnr 'Orders/OrderRepository.cs'
          return b ~= -1 and table.concat(api.nvim_buf_get_lines(b, 0, -1, false), '\n'):find('// DONE: use AsNoTracking', 1, true) ~= nil
        end,
      },
      solution = { '<C-w>v', ']q', 'ciwDONE<Esc>', '<C-h>' },
      hint = '<C-w>v · ]q · ciwDONE<Esc> · <C-h>',
      boss = true,
    },
  },
}
