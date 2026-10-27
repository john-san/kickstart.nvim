local api = vim.api
local H = require 'drill.curriculum.helpers'

local PRICING = [[
public class PricingService
{
    public decimal Total(Order order, Customer customer)
    {
        var discount = Discounts.For(customer.Tier, order.Placed);
        if (order.Lines.Count == 0) return 0m;
        return order.Lines.Sum(l => l.Price * l.Quantity) * (1 - discount);
    }
}
]]

local REPO = [[
public class CustomerRepository
{
    private readonly AppDbContext _db;

    public Customer? Find(int id)
    {
        return _db.Customers.Find(id);
    }

    public void Touch(Customer customer)
    {
        customer.LastSeen = DateTime.UtcNow;
        _db.SaveChanges();
    }

    public IEnumerable<Customer> Active()
    {
        return _db.Customers.Where(c => c.IsActive);
    }
}
]]

local function edit(text, from, to) return (text:gsub(vim.pesc(from), (to:gsub('%%', '%%%%')), 1)) end

local GIT_BASE, GIT_DIRTY = H.INVOICE_BASE, H.INVOICE_DIRTY
local PROJECT = H.PROJECT
local GIT = H.GIT

return {
  title = 'Your plugins: surround, flash, treesitter, telescope, git',
  why = 'Your config already has power tools most people never learn: mini.surround on gs, flash on s/S, '
    .. 'treesitter functions and classes as text objects and jumps, parameter swapping, Telescope, '
    .. 'gitsigns hunks. Each one replaces a dozen keystrokes with three.',
  drills = {
    {
      id = 'd5.surround-add',
      skill = 'surround',
      title = 'Add parentheses',
      task = 'Wrap `subtotal + tax` in parentheses.',
      ft = 'cs',
      text = 'var total = subtotal + tax * rate;\n',
      cursor = { 'subtotal', 0 },
      goal = { text = 'var total = (subtotal + tax) * rate;\n' },
      solution = 'gsa3e)',
      hint = 'gsa + motion + char: 3e covers `subtotal + tax`. `)` adds no spaces, `(` adds them.',
      requires = { maps = { { 'n', 'gsa' } } },
    },
    {
      id = 'd5.surround-delete',
      skill = 'surround',
      title = 'Delete parentheses',
      task = 'Remove the redundant parentheses around the sum.',
      ft = 'cs',
      text = 'return (price + shipping);\n',
      cursor = { 'price', 0 },
      goal = { text = 'return price + shipping;\n' },
      solution = 'gsd)',
      hint = 'gsd + the surrounding char.',
      requires = { maps = { { 'n', 'gsd' } } },
    },
    {
      id = 'd5.surround-replace',
      skill = 'surround',
      title = 'Swap the quotes',
      task = 'Make the import use single quotes.',
      ft = 'typescript',
      text = 'import { map } from "rxjs";\n',
      cursor = { 'rxjs', 0 },
      goal = { text = "import { map } from 'rxjs';\n" },
      solution = 'gsr"\'',
      hint = 'gsr + old + new, with the cursor inside the pair.',
      requires = { maps = { { 'n', 'gsr' } } },
    },
    {
      id = 'd5.surround-call',
      skill = 'surround',
      title = 'Wrap in a function call',
      task = 'Parse the input: `input` → `int.Parse(input)`.',
      ft = 'cs',
      text = 'var count = input;\n',
      cursor = { 'input', 0 },
      goal = { text = 'var count = int.Parse(input);\n' },
      solution = 'gsaiwfint.Parse<CR>',
      hint = 'gsaiwf asks for a function name and wraps the word in name(...).',
      requires = { maps = { { 'n', 'gsa' } } },
    },
    {
      id = 'd5.flash-jump',
      skill = 'flash',
      title = 'Flash jump',
      task = 'Jump to `Placed` with flash: s, a few letters, then the label.',
      ft = 'cs',
      text = PRICING,
      cursor = { 1, 0 },
      goal = { cursor = { 'Placed', 0 } },
      solution = 'sPlac<CR>',
      hint = 's + 2-4 letters, then the label shown at the target (<CR> takes the nearest match).',
      requires = { maps = { { 'n', 's' } }, modules = { 'flash' } },
    },
    {
      id = 'd5.flash-treesitter',
      skill = 'flash',
      title = 'Select a syntax node',
      task = 'Yank the whole `Discounts.For(...)` call with flash treesitter.',
      ft = 'cs',
      text = PRICING,
      cursor = { 'Discounts', 0 },
      goal = { register = { '"', 'Discounts.For(customer.Tier, order.Placed)' } },
      solution = 'S;;<CR>y',
      hint = 'S labels the nodes around the cursor; ; and , grow/shrink, a label or <CR> selects. Then y.',
      requires = { maps = { { 'n', 'S' } }, modules = { 'flash' }, parsers = { 'c_sharp' } },
    },
    H.with({
      id = 'd5.ts-jumps',
      skill = 'treesitter jumps',
      title = 'Function to function',
      task = 'Visit: start of Find, end of Find, start of Active.',
      ft = 'cs',
      text = REPO,
      cursor = { 1, 0 },
      goal = {},
      solution = { ']f', ']F', ']f]f' },
      hint = ']f / [f next/previous function start, ]F / [F ends, ]] / [[ classes.',
      requires = { maps = { { 'n', ']f' } }, parsers = { 'c_sharp' } },
    }, H.tour { { 'public Customer? Find', 0 }, { '    }', 4 }, { 'public IEnumerable', 0 } }),
    {
      id = 'd5.yank-function',
      skill = 'treesitter objects',
      title = 'Yank a whole method',
      task = 'Yank the Touch method (signature to closing brace) from inside its body.',
      ft = 'cs',
      text = REPO,
      cursor = { '_db.SaveChanges', 0 },
      goal = { register = { '"', 'public void Touch(Customer customer)\n    {\n        customer.LastSeen = DateTime.UtcNow;\n        _db.SaveChanges();\n    }' } },
      solution = 'yaf',
      hint = 'Your mini.ai maps f to the treesitter @function: yaf / daf / vif. c is the class.',
      requires = { parsers = { 'c_sharp' }, modules = { 'mini.ai' } },
    },
    {
      id = 'd5.argument',
      skill = 'treesitter objects',
      title = 'Change an argument',
      task = 'Change the first parameter to `Invoice invoice`.',
      ft = 'cs',
      text = PRICING,
      cursor = { 'Order order', 0 },
      goal = { text = edit(PRICING, 'Total(Order order,', 'Total(Invoice invoice,') },
      solution = 'ciaInvoice invoice<Esc>',
      hint = 'ia = inside argument (mini.ai). Note: `daa` does not work in your config, because mini.ai\'s around_next is mapped to `aa`.',
      requires = { modules = { 'mini.ai' } },
    },
    {
      id = 'd5.swap-params',
      skill = 'treesitter swap',
      title = 'Swap parameters',
      task = 'Swap the two parameters of Total.',
      ft = 'cs',
      text = PRICING,
      cursor = { 'Order order', 0 },
      goal = { text = edit(PRICING, 'Total(Order order, Customer customer)', 'Total(Customer customer, Order order)') },
      solution = '<leader>a',
      hint = '<leader>a swaps the parameter with the next one, <leader>A with the previous.',
      requires = { maps = { { 'n', '<leader>a' } }, parsers = { 'c_sharp' } },
    },
    {
      id = 'd5.incremental',
      skill = 'incremental selection',
      title = 'Grow the selection',
      task = 'Replace the whole `order.Lines.Sum(...)` call with `subtotal`.\nGrow a selection out from `Sum`.',
      ft = 'cs',
      text = PRICING,
      cursor = { 'Sum(', 0 },
      goal = { text = edit(PRICING, 'order.Lines.Sum(l => l.Price * l.Quantity)', 'subtotal') },
      solution = 'vanananc' .. 'subtotal<Esc>',
      hint = 'Neovim 0.12: in visual mode `an` grows to the parent node, `in` shrinks.\nv an an an reaches the whole call, then c.',
      requires = { parsers = { 'c_sharp' } },
    },
    {
      id = 'd5.comment',
      skill = 'comment',
      title = 'Comment out two lines',
      task = 'Comment out the discount line and the if below it.',
      ft = 'cs',
      text = PRICING,
      cursor = { 'var discount', 0 },
      goal = { text = PRICING:gsub('        var discount', '        // var discount'):gsub('        if %(', '        // if (') },
      solution = 'gcj',
      hint = 'gc + motion (gcc for one line, gcip for a paragraph). Built into Neovim.',
    },
    {
      id = 'd5.telescope-buffers',
      skill = 'telescope',
      title = 'Fuzzy-switch buffers',
      task = 'Switch to the loaded OrderRepository.cs with your buffer picker.',
      ft = 'cs',
      file = 'Orders/OrderService.cs',
      text = PROJECT['Orders/OrderService.cs'],
      files = PROJECT,
      setup = function()
        vim.cmd 'badd Orders/OrderRepository.cs'
        vim.cmd 'badd Orders/Order.cs'
      end,
      goal = { file = 'Orders/OrderRepository%.cs$' },
      solution = { '<leader><leader>repo', H.wait_picker(), '<CR>' },
      hint = '<leader><leader> lists buffers (most recent first, current hidden); type a few letters, <CR>.',
      requires = { maps = { { 'n', '<leader><leader>' } } },
    },
    {
      id = 'd5.telescope-lines',
      skill = 'telescope',
      title = 'Fuzzy-find a line',
      task = 'Jump to the line containing `IsActive` with the in-buffer fuzzy finder.',
      ft = 'cs',
      text = REPO,
      cursor = { 1, 0 },
      goal = { cursor = { 'IsActive', line = true } },
      solution = { '<leader>/isact', H.wait_picker(), '<CR>' },
      hint = '<leader>/ fuzzy-searches the current buffer; <CR> jumps to the line.',
      requires = { maps = { { 'n', '<leader>/' } } },
    },
    {
      id = 'd5.telescope-help',
      skill = 'telescope',
      title = 'Search the help',
      task = 'Open the help for text objects (the `text-objects` tag).',
      ft = 'cs',
      text = REPO,
      goal = {
        check = function()
          return vim.bo.filetype == 'help' and api.nvim_get_current_line():find('*text-objects*', 1, true) ~= nil
        end,
      },
      solution = { '<leader>shtext-objects', H.wait_picker(), '<CR>' },
      hint = '<leader>sh fuzzy-searches every help tag.',
      requires = { maps = { { 'n', '<leader>sh' } } },
    },
    {
      id = 'd5.git-next-hunk',
      skill = 'gitsigns',
      title = 'Next git change',
      task = 'Jump to the second changed hunk (the Console lines).',
      ft = 'cs',
      file = 'InvoiceService.cs',
      text = GIT_DIRTY,
      git = { ['InvoiceService.cs'] = GIT_BASE },
      cursor = { 1, 0 },
      goal = { cursor = { 'Console.WriteLine("sending', line = true } },
      solution = ']c]c',
      hint = ']c / [c jump between hunks (gitsigns).',
      requires = GIT,
    },
    {
      id = 'd5.git-hunk-object',
      skill = 'gitsigns',
      title = 'Delete the hunk as a text object',
      task = 'Drop the two Console debug lines you added.',
      ft = 'cs',
      file = 'InvoiceService.cs',
      text = GIT_DIRTY,
      git = { ['InvoiceService.cs'] = GIT_BASE },
      cursor = { 'Console.WriteLine(invoice', 0 },
      goal = { text = GIT_DIRTY:gsub('        Console[^\n]*\n', '') },
      solution = 'dih',
      hint = 'ih is "inside hunk" (gitsigns): dih, yih, vih.',
      requires = GIT,
    },
    {
      id = 'd5.neo-tree',
      skill = 'neo-tree',
      title = 'Reveal in the tree',
      task = 'Reveal this file in neo-tree, then open Order.cs from the tree.',
      ft = 'cs',
      file = 'Orders/OrderService.cs',
      text = PROJECT['Orders/OrderService.cs'],
      files = PROJECT,
      goal = {
        file = 'Orders/Order%.cs$',
        check = function() return vim.bo.filetype ~= 'neo-tree' end,
      },
      solution = { '\\', { wait_for = function() return vim.bo.filetype == 'neo-tree' and api.nvim_get_current_line():find 'OrderService' end, settle = 200 }, '2k', 'l' },
      hint = '\\ reveals the current file in neo-tree; 2k up two entries; l (or <CR>) opens.',
      requires = { maps = { { 'n', '\\' } } },
      teardown = function() pcall(vim.cmd, 'Neotree close') end,
    },
    {
      id = 'd5.boss',
      skill = 'plugins-mixed',
      title = 'Fix up Price()',
      task = 'Match the target: swap the parameters, fix the char literal to a string,\nand make it Math.Round(…, 2).',
      ft = 'cs',
      text = [[
    public decimal Price(Customer customer, Order order)
    {
        var label = 'standard';
        return Round(order.Total * Rate(customer));
    }
]],
      cursor = { 'Customer customer', 0 },
      goal = {
        text = [[
    public decimal Price(Order order, Customer customer)
    {
        var label = "standard";
        return Math.Round(order.Total * Rate(customer), 2);
    }
]],
      },
      solution = { '<leader>a', '2j$b', 'gsr\'"', 'j^w', 'iMath.<Esc>', '$F)', 'i, 2<Esc>' },
      hint = '<leader>a · 2j$b gsr\'" · j^w iMath.<Esc> · $F) i, 2<Esc>',
      requires = { maps = { { 'n', '<leader>a' }, { 'n', 'gsr' } }, parsers = { 'c_sharp' } },
      boss = true,
    },
  },
}
