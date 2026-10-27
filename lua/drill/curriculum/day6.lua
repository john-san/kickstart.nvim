local api = vim.api
local H = require 'drill.curriculum.helpers'

-- One file with everything the LSP drills point at: an interface and its implementation, an
-- entity type, and a service that calls its own helpers.
local CHECKOUT = [[
public interface IClock
{
    DateTime Now { get; }
}

public class SystemClock : IClock
{
    public DateTime Now => DateTime.UtcNow;
}

public class Order
{
    public int Id { get; set; }
    public decimal Total { get; set; }
}

public class Checkout
{
    private readonly IClock _clock;

    public decimal Charge(Order order, decimal rate)
    {
        var total = CalcTotal(order, rate);
        Audit(order, total);
        return total;
    }

    private decimal CalcTotal(Order order, decimal rate)
    {
        return order.Total * rate;
    }

    private void Audit(Order order, decimal total)
    {
        Console.WriteLine($"{_clock.Now}: {order.Id} charged {total}");
    }
}
]]

local function replace(text, from, to) return (text:gsub(vim.pesc(from), (to:gsub('%%', '%%%%')))) end

local LOGGER_ACTION = {
  title = 'Use the injected ILogger instead of Console',
  apply = function(lines)
    for i, l in ipairs(lines) do
      lines[i] = l:gsub('Console%.WriteLine%(', '_logger.LogInformation(')
    end
    return lines
  end,
}
local DECOY_ACTION = {
  title = 'Suppress CA1303 with #pragma',
  apply = function(lines)
    table.insert(lines, 1, '#pragma warning disable CA1303')
    return lines
  end,
}

local WARNINGS = {
  { 'order.Total * rate', 0, message = 'Decimal multiplication may overflow', severity = 2 },
  { '_clock.Now', 0, message = 'Possible null reference: _clock is never assigned', severity = 2 },
}

local LSP = { lsp_attach = true }
local GIT = H.GIT

local LONG = { 'public class Rates', '{' }
for i = 1, 70 do
  table.insert(LONG, ('    public decimal Rate%02d { get; set; } = %d.%02dm;'):format(i, i % 7, i))
end
LONG = table.concat(LONG, '\n') .. '\n}\n'

--- Output of `git <args>` in the workspace, from the last finished run (nil before the first).
--- Runs in the background: goal checks fire on every key, and a blocking git call would lag.
local function git(ctx, args)
  local key = table.concat(args, ' ')
  ctx.git = ctx.git or { out = {}, busy = {} }
  if not ctx.git.busy[key] then
    ctx.git.busy[key] = true
    vim.system(vim.list_extend({ 'git', '-C', ctx.dir }, args), { text = true }, function(r)
      ctx.git.out[key] = r.stdout or ''
      ctx.git.busy[key] = nil
    end)
  end
  return ctx.git.out[key]
end

local function gs_config() return require('gitsigns.config').config end

--- A gitsigns drill on the dirty InvoiceService.cs, base committed.
local function invoice(drill)
  drill.ft = 'cs'
  drill.file = 'InvoiceService.cs'
  drill.text = H.INVOICE_DIRTY
  drill.git = { ['InvoiceService.cs'] = H.INVOICE_BASE }
  drill.requires = drill.requires or GIT
  return drill
end

--- A drill on CHECKOUT as a real file. Telescope and Trouble preview their results by file
--- name, and on Windows a scratch name like drill://x.cs reads as a network path (slow).
local function on_file(drill)
  drill.ft = 'cs'
  drill.file = 'Checkout.cs'
  drill.text = drill.text or CHECKOUT
  return drill
end

--- An LSP drill on CHECKOUT with the drill language server attached.
local function checkout(drill)
  on_file(drill)
  drill.lsp = drill.lsp or {}
  drill.requires = drill.requires or LSP
  return drill
end

local function trouble_open() return H.win_with_ft 'trouble' ~= nil end
local function close_trouble() pcall(function() require('trouble').close() end) end

return {
  title = 'Your keymaps and LSP actions',
  why = 'A mapping you never use is a mapping you pay for in memory and get nothing back. Today every '
    .. 'custom map in your config gets used at least once, plus the LSP actions (rename, code action, '
    .. 'references, definitions, symbols, diagnostics) you will reach for a hundred times a day in C#.',
  drills = {
    -- [[ keymaps.lua ]]
    {
      id = 'd6.write',
      skill = 'leader-w',
      title = 'Save with <leader>w',
      task = 'Change `draft` to `done` and save the file.',
      file = 'status.txt',
      text = 'status: draft\n',
      cursor = { 'draft', 0 },
      goal = {
        check = function(ctx)
          local ok, disk = pcall(vim.fn.readfile, ctx.dir .. '/status.txt')
          return not vim.bo[ctx.buf].modified and ok and disk[1] == 'status: done', 'save it'
        end,
      },
      solution = 'ciwdone<Esc><leader>w',
      hint = '<leader>w writes the file (your keymaps.lua).',
      requires = { maps = { { 'n', '<leader>w' } } },
    },
    {
      id = 'd6.indent-keep',
      skill = 'visual-indent',
      title = 'Indent twice, one selection',
      task = 'Indent both expect lines two levels so they sit inside the `it` block.',
      ft = 'typescript',
      text = "describe('checkout', () => {\n  it('charges the card', () => {\nexpect(charge(order)).toBe(true);\nexpect(audit).toHaveBeenCalled();\n  });\n});\n",
      cursor = { 'expect(charge', 0 },
      goal = {
        mode = false,
        text = "describe('checkout', () => {\n  it('charges the card', () => {\n    expect(charge(order)).toBe(true);\n    expect(audit).toHaveBeenCalled();\n  });\n});\n",
      },
      solution = 'Vj>>',
      hint = 'Your visual < and > keep the selection, so V j > > indents twice without reselecting.',
      requires = { maps = { { 'x', '>' } } },
    },
    {
      id = 'd6.move-line',
      skill = 'move-lines',
      title = 'Move a line down',
      task = 'Move the `total` line below the `items` line it depends on.',
      ft = 'typescript',
      text = 'const total = sum(items);\nconst items = await load(id);\nreturn total;\n',
      cursor = { 1, 0 },
      goal = { text = 'const items = await load(id);\nconst total = sum(items);\nreturn total;\n' },
      solution = '<A-j>',
      hint = '<A-j> / <A-k> move the line (or the visual selection, or from insert mode) and reindent.',
      requires = { maps = { { 'n', '<A-j>' } } },
    },
    {
      id = 'd6.move-block',
      skill = 'move-lines',
      title = 'Move a block up',
      task = 'Move both log lines above the return.',
      ft = 'typescript',
      text = "function total(items: Item[]): number {\n  const sum = items.reduce((s, i) => s + i.price, 0);\n  return sum;\n  log('total');\n  log(sum);\n}\n",
      cursor = { "log('total')", 0 },
      goal = {
        mode = false,
        text = "function total(items: Item[]): number {\n  const sum = items.reduce((s, i) => s + i.price, 0);\n  log('total');\n  log(sum);\n  return sum;\n}\n",
      },
      solution = 'Vj<A-k>',
      hint = 'Select the lines (V j), then <A-k>. The selection stays, so you can keep pressing it.',
      requires = { maps = { { 'x', '<A-k>' } } },
    },
    {
      id = 'd6.blackhole',
      skill = 'blackhole-delete',
      title = 'Delete without clobbering',
      task = 'The unnamed register holds `customer.FullName`, ready to paste.\nDelete the debug line without overwriting it.',
      ft = 'cs',
      text = 'var name = customer.Name;\nvar debug = true;\nvar city = customer.City;\n',
      cursor = { 'var debug', 0 },
      registers = { ['"'] = 'customer.FullName' },
      goal = { text = 'var name = customer.Name;\nvar city = customer.City;\n', register = { '"', 'customer.FullName' } },
      solution = '<leader>dd',
      hint = '<leader>d is d into the black-hole register: <leader>dd, <leader>diw, or visual <leader>d.',
      requires = { maps = { { 'n', '<leader>d' } } },
    },
    {
      id = 'd6.join',
      skill = 'join',
      title = 'Join, cursor stays put',
      task = 'Join the split string concatenation into one line.',
      ft = 'cs',
      text = 'var message = "Order " + order.Id +\n    " shipped";\n',
      cursor = { 'message', 0 },
      goal = { text = 'var message = "Order " + order.Id + " shipped";\n', cursor = { 'message', 0 } },
      solution = 'J',
      hint = 'Your J keeps the cursor where it was (mzJ`z), so you can keep joining or keep editing.',
      requires = { maps = { { 'n', 'J' } } },
    },
    {
      id = 'd6.splits',
      skill = 'leader-splits',
      title = 'Three-pane layout',
      task = 'Make this layout: this file on the left, two stacked windows on the right.',
      ft = 'cs',
      text = CHECKOUT,
      goal = {
        windows = 3,
        check = function()
          local l = vim.fn.winlayout()
          return l[1] == 'row' and #l[2] == 2 and l[2][2][1] == 'col'
        end,
      },
      solution = '<leader>|<leader>-',
      hint = '<leader>| splits right, <leader>- splits below.',
      requires = { maps = { { 'n', '<leader>|' }, { 'n', '<leader>-' } } },
    },
    {
      id = 'd6.resize',
      skill = 'resize',
      title = 'Widen a split',
      task = 'Make this (left) window 4 columns wider.',
      ft = 'cs',
      text = CHECKOUT,
      setup = function(ctx)
        vim.cmd 'vsplit'
        vim.cmd 'wincmd h'
        ctx.width = api.nvim_win_get_width(0)
      end,
      goal = { windows = 2, check = function(ctx) return api.nvim_win_get_width(0) == ctx.width + 4, 'width' end },
      solution = '<C-Right><C-Right>',
      hint = '<C-Left>/<C-Right> change the width by 2, <C-Up>/<C-Down> the height. <C-w>= evens them out.',
      requires = { maps = { { 'n', '<C-Right>' } } },
    },
    {
      id = 'd6.half-page',
      skill = 'scroll',
      title = 'Half a page, centred',
      task = 'Scroll down a full page in two half-page jumps. Your maps keep the cursor centred.',
      ft = 'cs',
      text = LONG,
      setup = function(ctx) ctx.target = H.simulate '<C-d><C-d>' end,
      goal = { check = function(ctx) return api.nvim_win_get_cursor(0)[1] == ctx.target, 'row' end },
      solution = '<C-d><C-d>',
      hint = '<C-d> / <C-u> half-page down/up (+ zz in your navigation.lua); <C-f>/<C-b> a full page.',
      no_speedrun = true,
    },
    {
      id = 'd6.nohlsearch',
      skill = 'search-clear',
      title = 'Search, then clear the highlight',
      task = 'Search for the `Audit(order` call, then clear the search highlight.',
      ft = 'cs',
      text = CHECKOUT,
      setup = function() vim.o.hlsearch = true end,
      goal = {
        cursor = { 'Audit(order', 0 },
        check = function() return vim.v.hlsearch == 0, 'highlight still on' end,
      },
      solution = { '/Audit(o<CR>', '<Esc>' },
      hint = 'Your <Esc> in normal mode runs :nohlsearch.',
      requires = { maps = { { 'n', '<Esc>' } } },
    },
    {
      id = 'd6.toggles',
      skill = 'option-toggles',
      title = 'Flip three options',
      task = 'Turn wrap ON, spell ON and relative numbers OFF.',
      ft = 'markdown',
      text = '# Release notes\n\nThis release adds multi-currency invoices and fixes the rounding of discounted totals on very long orders.\n',
      setup = function()
        vim.wo.wrap, vim.wo.spell, vim.wo.relativenumber = false, false, true
      end,
      goal = {
        check = function() return vim.wo.wrap and vim.wo.spell and not vim.wo.relativenumber end,
      },
      solution = '<leader>tW<leader>ts<leader>tr',
      hint = '<leader>tW wrap (capital W: lowercase tw is gitsigns word diff), <leader>ts spell, <leader>tr relative numbers.',
      requires = { maps = { { 'n', '<leader>tW' }, { 'n', '<leader>ts' }, { 'n', '<leader>tr' } } },
    },
    {
      id = 'd6.format-toggle',
      skill = 'format-toggle',
      title = 'Toggle format on save',
      task = 'Flip format-on-save (drills keep it off; the message tells you the new state).',
      ft = 'lua',
      text = 'return {}\n',
      goal = { check = function(ctx) return vim.g.disable_autoformat ~= ctx.opts.autoformat end },
      solution = '<leader>tf',
      hint = '<leader>tf toggles format-on-save for the session. :FormatDisable / :FormatEnable do the same, with ! for this buffer only.',
      requires = { maps = { { 'n', '<leader>tf' } } },
    },
    {
      id = 'd6.format',
      skill = 'format',
      title = 'Format the buffer',
      task = 'Format this file with your formatter (stylua).',
      ft = 'lua',
      file = 'pricing.lua',
      text = "local total=price*qty+tax\nlocal names={'a','b'}\n",
      goal = { text = 'local total = price * qty + tax\nlocal names = { "a", "b" }\n' },
      solution = '<leader>f',
      hint = '<leader>f runs conform (stylua for Lua, csharpier for C# when installed).',
      requires = { maps = { { 'n', '<leader>f' } }, exe = { 'stylua' } },
    },
    {
      id = 'd6.keymaps',
      skill = 'search-keymaps',
      title = 'Run a mapping you forgot',
      task = 'You forgot the spell toggle. Find it with the keymap search and run it from there.',
      ft = 'markdown',
      text = '# Notes\n\nTeh quick brwon fox.\n',
      setup = function() vim.wo.spell = false end,
      goal = { check = function() return vim.wo.spell end },
      solution = { '<leader>sktoggle spell', H.wait_picker(), '<CR>' },
      par = 19, -- running the mapping from the picker replays its 3 keys, and those count too
      hint = '<leader>sk searches every mapping by key or description; <CR> runs the selected one.',
      requires = { maps = { { 'n', '<leader>sk' } } },
    },
    {
      id = 'd6.git-status',
      skill = 'git-pickers',
      title = 'Open a changed file',
      task = 'Open the file with uncommitted changes from the git status picker.',
      ft = 'markdown',
      file = 'README.md',
      text = '# Shop\n',
      files = { ['InvoiceService.cs'] = H.INVOICE_DIRTY },
      git = { ['README.md'] = '# Shop\n', ['InvoiceService.cs'] = H.INVOICE_BASE },
      ready = function() return true end,
      goal = { file = 'InvoiceService%.cs$' },
      solution = { '<leader>sG', H.wait_picker(800), '<CR>' },
      hint = '<leader>sG: git status in Telescope, with the diff in the preview. <leader>sC: commit log.',
      requires = { maps = { { 'n', '<leader>sG' } }, exe = { 'git' } },
    },
    {
      id = 'd6.git-commits',
      skill = 'git-pickers',
      title = 'Browse the commit log',
      task = 'Open the git commit picker (preview shows each commit\'s diff).',
      ft = 'cs',
      file = 'InvoiceService.cs',
      text = H.INVOICE_BASE,
      git = { ['InvoiceService.cs'] = H.INVOICE_BASE },
      ready = function() return true end,
      goal = { mode = false, check = function() return H.picker_title() == 'Git Commits' end },
      solution = '<leader>sC',
      hint = '<leader>sC. <CR> on a commit checks it out (detached), so <Esc> when you are done looking.',
      requires = { maps = { { 'n', '<leader>sC' } }, exe = { 'git' } },
      teardown = H.close_picker,
    },
    {
      id = 'd6.terminal',
      skill = 'toggleterm',
      title = 'Floating terminal round trip',
      task = 'Open the floating terminal, leave terminal mode, then hide it again.',
      ft = 'cs',
      text = CHECKOUT,
      goal = {
        check = H.round_trip(
          function() return vim.bo.buftype == 'terminal' and api.nvim_get_mode().mode == 'n' end,
          function(ctx) return api.nvim_get_current_buf() == ctx.buf end
        ),
      },
      solution = {
        '<C-\\>',
        { wait_for = function() return api.nvim_get_mode().mode == 't' end, timeout = 8000, settle = 300 },
        '<Esc><Esc>',
        { wait = 100 },
        '<C-\\>',
      },
      hint = '<C-\\> toggles the float (from normal or terminal mode); <Esc><Esc> leaves terminal mode.',
      requires = { maps = { { 'n', '<C-\\>' }, { 't', '<Esc><Esc>' } } },
      no_speedrun = true,
      test_skip = 'in a headless Neovim the shell exits at once and toggleterm closes the float',
    },
    {
      id = 'd6.zen',
      skill = 'zen',
      title = 'Zen mode round trip',
      task = 'Enter zen mode, then leave it.',
      ft = 'cs',
      text = CHECKOUT,
      goal = {
        check = H.round_trip(
          function() return require('zen-mode.view').is_open() end,
          function() return not require('zen-mode.view').is_open() end
        ),
      },
      solution = { '<leader>z', { wait = 200 }, '<leader>z' },
      hint = '<leader>z toggles zen mode (a centred 120-column float).',
      requires = { maps = { { 'n', '<leader>z' } }, modules = { 'zen-mode.view' } },
      teardown = function() pcall(function() require('zen-mode').close() end) end,
    },
    {
      id = 'd6.tree-toggle',
      skill = 'neo-tree',
      title = 'File tree round trip',
      task = 'Open the file tree, then close it.',
      ft = 'cs',
      file = 'Orders/OrderService.cs',
      text = H.PROJECT['Orders/OrderService.cs'],
      files = H.PROJECT,
      goal = {
        check = H.round_trip(function() return H.win_with_ft 'neo-tree' ~= nil end, function() return H.win_with_ft 'neo-tree' == nil end),
      },
      solution = { '<leader>e', { wait_for = function() return vim.bo.filetype == 'neo-tree' end, settle = 200 }, '<leader>e' },
      hint = '<leader>e toggles neo-tree; \\ reveals the current file in it.',
      requires = { maps = { { 'n', '<leader>e' } } },
      teardown = function() pcall(vim.cmd, 'Neotree close') end,
    },
    {
      id = 'd6.lsp-info',
      skill = 'lsp-info',
      title = 'LSP health check',
      task = 'Open the LSP health report, then close it with q.',
      ft = 'cs',
      text = CHECKOUT,
      goal = {
        check = H.round_trip(function() return vim.bo.filetype == 'checkhealth' end, function(ctx) return api.nvim_get_current_buf() == ctx.buf end),
      },
      solution = { '<leader>li', { wait_for = function() return vim.bo.filetype == 'checkhealth' end, timeout = 8000, settle = 200 }, 'q' },
      hint = '<leader>li is :checkhealth vim.lsp (what attached, with which config). q closes it.',
      requires = { maps = { { 'n', '<leader>li' } } },
      no_speedrun = true,
    },

    -- [[ gitsigns ]]
    invoice {
      id = 'd6.git-stage-hunk',
      skill = 'git-hunks',
      title = 'Stage one hunk',
      task = 'Stage only the Console hunk; leave the constructor change unstaged.',
      cursor = { 'Console.WriteLine("sending', 0 },
      goal = {
        check = function(ctx)
          local staged = git(ctx, { 'diff', '--cached' }) or ''
          return staged:find('Console', 1, true) and not staged:find('Currency', 1, true), 'staged'
        end,
      },
      solution = '<leader>hs',
      hint = '<leader>hs stages the hunk under the cursor (visual: just the selected lines). <leader>hS stages the buffer.',
    },
    invoice {
      id = 'd6.git-stage-buffer',
      skill = 'git-hunks',
      title = 'Stage the whole file',
      task = 'Stage every change in this file.',
      goal = {
        check = function(ctx)
          local unstaged, staged = git(ctx, { 'diff', '--name-only' }), git(ctx, { 'diff', '--cached', '--name-only' })
          return unstaged == '' and staged ~= nil and staged ~= ''
        end,
      },
      solution = '<leader>hS',
      hint = '<leader>hS stages the buffer, <leader>hR resets it.',
    },
    invoice {
      id = 'd6.git-reset-hunk',
      skill = 'git-hunks',
      title = 'Throw away one hunk',
      task = 'Discard the Console debug hunk (back to the committed version).',
      cursor = { 'Console.WriteLine(invoice', 0 },
      goal = { text = H.INVOICE_DIRTY:gsub('        Console[^\n]*\n', '') },
      solution = '<leader>hr',
      hint = '<leader>hr resets the hunk under the cursor; dih does the same edit as a text object.',
    },
    invoice {
      id = 'd6.git-reset-buffer',
      skill = 'git-hunks',
      title = 'Throw away every change',
      task = 'Reset the whole file to the last commit.',
      goal = { text = H.INVOICE_BASE },
      solution = '<leader>hR',
      hint = '<leader>hR resets every hunk in the buffer (u brings them back).',
    },
    invoice {
      id = 'd6.git-preview',
      skill = 'git-inspect',
      title = 'Preview a hunk',
      task = 'Show the diff of the hunk under the cursor in a popup.',
      cursor = { 'Console.WriteLine("sending', 0 },
      goal = { check = function() return H.float_with 'sending' ~= nil end },
      solution = '<leader>hp',
      hint = '<leader>hp previews in a float, <leader>hi inline in the buffer.',
    },
    invoice {
      id = 'd6.git-blame',
      skill = 'git-inspect',
      title = 'Who wrote this line?',
      task = 'Show the full blame (commit message included) for the _mailer line.',
      cursor = { '_mailer', 0 },
      goal = { check = function() return H.float_with 'drill base' ~= nil end },
      solution = '<leader>hb',
      hint = '<leader>hb blames the line in a popup; <leader>tb toggles inline blame on every line.',
    },
    invoice {
      id = 'd6.git-diff',
      skill = 'git-inspect',
      title = 'Diff against the index',
      task = 'Open a side-by-side diff of this file against what git has.',
      goal = {
        windows = 2,
        check = function()
          for _, w in ipairs(require('drill.goal').windows()) do
            if not vim.wo[w].diff then return false end
          end
          return true
        end,
      },
      solution = '<leader>hd',
      hint = '<leader>hd diffs against the index, <leader>hD against the last commit. :diffoff! and <C-w>o to leave.',
    },
    invoice {
      id = 'd6.git-qf',
      skill = 'git-inspect',
      title = 'Every hunk in the quickfix list',
      task = 'Put this file\'s hunks in the quickfix list.',
      goal = { qf = 2 },
      solution = '<leader>hq',
      hint = '<leader>hq: this file\'s hunks; <leader>hQ: every changed file in the repo. Then ]q / [q.',
    },
    invoice {
      id = 'd6.git-toggles',
      skill = 'git-toggles',
      title = 'Inline blame and word diff',
      task = 'Turn on inline blame for the current line and intra-line word diff.',
      setup = function(ctx)
        ctx.blame, ctx.word_diff = gs_config().current_line_blame, gs_config().word_diff
        require('gitsigns').toggle_current_line_blame(false)
        require('gitsigns').toggle_word_diff(false)
      end,
      goal = { check = function() return gs_config().current_line_blame and gs_config().word_diff end },
      solution = '<leader>tb<leader>tw',
      hint = '<leader>tb inline blame, <leader>tw word diff (lowercase w; <leader>tW is wrap).',
      teardown = function(ctx)
        pcall(require('gitsigns').toggle_current_line_blame, ctx.blame)
        pcall(require('gitsigns').toggle_word_diff, ctx.word_diff)
      end,
    },

    -- [[ LSP ]]
    checkout {
      id = 'd6.rename',
      skill = 'lsp-rename',
      title = 'Rename a symbol',
      task = 'Rename CalcTotal to ComputeTotal everywhere.',
      cursor = { 'CalcTotal(order', 0 },
      goal = { text = replace(CHECKOUT, 'CalcTotal', 'ComputeTotal') },
      solution = 'grn<C-u>ComputeTotal<CR>',
      hint = 'grn prompts with the old name; <C-u> clears it (or <C-w>/edit it), <CR> renames every reference.',
    },
    checkout {
      id = 'd6.code-action',
      skill = 'lsp-code-action',
      title = 'Apply a code action',
      task = 'Apply the "Use the injected ILogger" fix to the Console line.',
      cursor = { 'Console', 0 },
      lsp = { code_actions = { LOGGER_ACTION, DECOY_ACTION } },
      goal = { text = replace(CHECKOUT, 'Console.WriteLine(', '_logger.LogInformation(') },
      solution = { 'gra', H.wait_picker(), '<CR>' },
      hint = 'gra lists code actions (Telescope dropdown); type to filter, <CR> applies. Works on a visual range too.',
    },
    checkout {
      id = 'd6.references',
      skill = 'lsp-references',
      title = 'Find the caller',
      task = 'From the Audit declaration, list its references and jump to the call.',
      cursor = { 'Audit(Order', 0 },
      goal = { cursor = { 'Audit(order', 0 } },
      solution = { 'grr', H.wait_picker(), '<CR>' },
      hint = 'grr lists references in Telescope (in OmniSharp buffers via omnisharp-extended).',
    },
    checkout {
      id = 'd6.definition',
      skill = 'lsp-definition',
      title = 'Go to definition',
      task = 'Jump from the CalcTotal call to its definition.',
      cursor = { 'CalcTotal(order', 0 },
      goal = { cursor = { 'CalcTotal(Order', 0 } },
      solution = 'grd',
      hint = 'grd (also gd in C# buffers, and the built-in <C-]>). <C-o> takes you back. grD is the declaration.',
    },
    checkout {
      id = 'd6.implementation',
      skill = 'lsp-implementation',
      title = 'Go to implementation',
      task = 'Jump from the IClock interface to the class that implements it.',
      cursor = { 'IClock', 0 },
      goal = { cursor = { 'SystemClock :', 0 } },
      solution = 'gri',
      hint = 'gri: implementations of an interface or abstract member.',
    },
    checkout {
      id = 'd6.type-definition',
      skill = 'lsp-type-definition',
      title = 'Go to the type',
      task = 'Jump from the `order` variable in CalcTotal to the definition of its type.',
      cursor = { 'order.Total * rate', 0 },
      goal = { cursor = { 'class Order', 6 } },
      solution = 'grt',
      hint = 'grt jumps to the type of the symbol under the cursor, not the symbol itself.',
    },
    checkout {
      id = 'd6.document-symbols',
      skill = 'lsp-symbols',
      title = 'Jump by symbol',
      task = 'Jump to the Audit method via the symbol list for this file.',
      cursor = { 1, 0 },
      goal = { cursor = { 'Audit(Order', line = true } },
      solution = { 'gO', H.wait_picker(), 'audit', { wait = 300 }, '<CR>' },
      hint = 'gO: symbols in this file (Telescope). <leader>xs shows them as an outline in Trouble.',
    },
    checkout {
      id = 'd6.workspace-symbols',
      skill = 'lsp-symbols',
      title = 'Find a type anywhere',
      task = 'Jump to the SystemClock class using the workspace symbol search.',
      cursor = { 'Charge', 0 },
      goal = { cursor = { 'SystemClock :', line = true } },
      solution = { 'gWsystemclock', H.wait_picker(1000), '<CR>' },
      hint = 'gW searches symbols across the workspace as you type.',
    },
    checkout {
      id = 'd6.hover',
      skill = 'lsp-hover',
      title = 'Hover documentation',
      task = 'Show the hover docs for _clock.',
      cursor = { '_clock.Now', 0 },
      lsp = { hover = { _clock = '```csharp\nprivate readonly IClock _clock\n```\nClock used for audit timestamps.' } },
      goal = { check = function() return H.float_with 'private readonly IClock _clock' ~= nil end },
      solution = 'K',
      hint = 'K shows hover docs; K again enters the float (q closes it).',
    },
    checkout {
      id = 'd6.next-diagnostic',
      skill = 'diagnostics',
      title = 'Next diagnostic',
      task = 'Jump to the second warning in the file.',
      cursor = { 1, 0 },
      diagnostics = WARNINGS,
      goal = { cursor = { '_clock.Now', 0 } },
      solution = ']d]d',
      hint = ']d / [d next/previous diagnostic, ]D / [D last/first, <C-w>d shows the message in a float.',
    },
    on_file {
      id = 'd6.diagnostic-list',
      skill = 'diagnostics',
      title = 'Diagnostics as a list',
      task = 'Open the location list of diagnostics and jump to the second one from it.',
      diagnostics = WARNINGS,
      goal = { cursor = { '_clock.Now', 0 } },
      solution = { '<leader>q', 'j<CR>' },
      hint = '<leader>q fills the location list with this buffer\'s diagnostics and opens it; <CR> jumps.',
      requires = { maps = { { 'n', '<leader>q' } } },
    },
    checkout {
      id = 'd6.inlay-hints',
      skill = 'inlay-hints',
      title = 'Inlay hints',
      task = 'Turn on inlay hints (parameter names appear in the calls).',
      lsp = { inlay_hints = { { 'order, rate);', 0, label = 'order:' }, { 'order, total);', 0, label = 'order:' } } },
      setup = function() vim.lsp.inlay_hint.enable(false) end,
      goal = { check = function(ctx) return vim.lsp.inlay_hint.is_enabled { bufnr = ctx.buf } end },
      solution = '<leader>th',
      hint = '<leader>th toggles inlay hints (only mapped when the server supports them).',
    },
    on_file {
      id = 'd6.trouble-diagnostics',
      skill = 'trouble',
      title = 'Diagnostics in Trouble',
      task = 'Open the diagnostics panel and jump to the first warning from it.',
      diagnostics = WARNINGS,
      goal = { cursor = { 'order.Total * rate', 0 } },
      solution = { '<leader>xx', { wait_for = trouble_open, settle = 300 }, '2j<CR>' },
      hint = '<leader>xx all diagnostics, <leader>xX this buffer only. Rows are folder, file, then the\nwarnings: 2j, then <CR> jumps. q closes.',
      requires = { maps = { { 'n', '<leader>xx' } }, modules = { 'trouble' } },
      teardown = close_trouble,
    },
    checkout {
      id = 'd6.trouble-symbols',
      skill = 'trouble',
      title = 'Symbol outline',
      task = 'Open the symbol outline and jump to Audit from it.',
      cursor = { 1, 0 },
      goal = { cursor = { 'Audit(Order', line = true } },
      solution = { '<leader>xs', { wait_for = trouble_open, settle = 500 }, '<C-l>', '/Audit<CR>', '<CR>' },
      hint = '<leader>xs opens the outline on the right without focus: <C-l> into it, / to search, <CR> jumps.',
      requires = { maps = { { 'n', '<leader>xs' } }, modules = { 'trouble' }, lsp_attach = true },
      teardown = close_trouble,
    },
    {
      id = 'd6.trouble-quickfix',
      skill = 'trouble',
      title = 'Quickfix in Trouble',
      task = 'The quickfix list has both TODOs. Open it in Trouble and jump to the second.',
      ft = 'cs',
      file = 'Jobs.cs',
      text ='class Jobs\n{\n    // TODO: retry failed jobs\n    void Run() { }\n\n    // TODO: log duration\n    void Stop() { }\n}\n',
      setup = function(ctx)
        vim.fn.setqflist({}, 'r', {
          title = 'TODOs',
          items = {
            { bufnr = ctx.buf, lnum = 3, col = 8, text = 'TODO: retry failed jobs' },
            { bufnr = ctx.buf, lnum = 6, col = 8, text = 'TODO: log duration' },
          },
        })
      end,
      goal = { cursor = { 'TODO: log', 0 } },
      solution = { '<leader>xq', { wait_for = trouble_open, settle = 300 }, '/duration<CR>', '<CR>' },
      hint = '<leader>xq shows the quickfix list in Trouble; <leader>xl shows LSP references/definitions.',
      requires = { maps = { { 'n', '<leader>xq' } }, modules = { 'trouble' } },
      teardown = close_trouble,
    },

    -- [[ Needs ripgrep (rg) ]]
    {
      id = 'd6.find-files',
      skill = 'telescope-files',
      title = 'Find a file by name',
      task = 'Open Order.cs by fuzzy file name.',
      ft = 'cs',
      file = 'Orders/OrderService.cs',
      text = H.PROJECT['Orders/OrderService.cs'],
      files = H.PROJECT,
      goal = { file = 'Orders/Order%.cs$' },
      solution = { '<leader>sforder.cs', H.wait_picker(800), '<CR>' },
      hint = '<leader>sf finds files by name; <leader>s. recent files; <leader>sn your Neovim config.',
      requires = { maps = { { 'n', '<leader>sf' } }, exe = { 'rg' } },
    },
    {
      id = 'd6.live-grep',
      skill = 'telescope-grep',
      title = 'Grep the project',
      task = 'Jump to the line that mentions AsNoTracking, wherever it is.',
      ft = 'cs',
      file = 'Orders/OrderService.cs',
      text = H.PROJECT['Orders/OrderService.cs'],
      files = vim.tbl_extend('force', H.PROJECT, {
        ['Orders/OrderRepository.cs'] = 'namespace Shop.Orders;\n\npublic class OrderRepository\n{\n    // TODO: AsNoTracking for reads\n}\n',
      }),
      goal = { file = 'OrderRepository%.cs$', cursor = { 'AsNoTracking', line = true } },
      solution = { '<leader>sgAsNoTracking', H.wait_picker(1000), '<CR>' },
      hint = '<leader>sg greps as you type; <leader>sw greps the word under the cursor.',
      requires = { maps = { { 'n', '<leader>sg' } }, exe = { 'rg' } },
    },

    checkout {
      id = 'd6.boss',
      skill = 'lsp-mixed',
      title = 'Review feedback, the LSP way',
      task = 'Rename CalcTotal to ComputeTotal, then jump to the warning on the Console line\nand apply the ILogger code action.',
      cursor = { 'CalcTotal(order', 0 },
      lsp = { code_actions = { LOGGER_ACTION, DECOY_ACTION } },
      diagnostics = { { 'Console', 0, message = 'CA1303: use the injected ILogger', severity = 2 } },
      goal = { text = replace(replace(CHECKOUT, 'CalcTotal', 'ComputeTotal'), 'Console.WriteLine(', '_logger.LogInformation(') },
      solution = {
        'grn<C-u>ComputeTotal<CR>',
        { wait_for = function(ctx) return api.nvim_buf_get_lines(ctx.buf, 0, -1, false)[23]:find 'ComputeTotal' end },
        ']d',
        'gra',
        H.wait_picker(),
        '<CR>',
      },
      hint = 'grn<C-u>ComputeTotal<CR> · ]d · gra <CR>',
      boss = true,
    },
  },
}
