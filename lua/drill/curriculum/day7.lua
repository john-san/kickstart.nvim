local api = vim.api
local H = require 'drill.curriculum.helpers'

local PRICING = [[
public class PricingService
{
    public decimal Total(Order order, decimal discount)
    {
        return order.Lines.Sum(l => l.Price * l.Quantity) * (1 - discount);
    }
}
]]

local function replace(text, from, to) return (text:gsub(vim.pesc(from), (to:gsub('%%', '%%%%')))) end

return {
  title = 'Real refactors, boss run, final scorecard',
  why = 'Nobody edits in single motions. Real changes chain them: select a node, cut it, name it, '
    .. 'paste it back; record a macro for the boring part; let the LSP do the renaming. Today mixes '
    .. 'everything in the languages you actually write. After this, run `:Drill speedrun` whenever '
    .. 'you have five minutes and `:Drill review` to keep the Leitner boxes moving.',
  drills = {
    {
      id = 'd7.extract-variable',
      skill = 'refactor-extract',
      title = 'Extract a variable (C#)',
      task = 'Pull the Sum(...) call into `var subtotal = ...;` on its own line and use it.',
      ft = 'cs',
      text = PRICING,
      cursor = { 'Sum(', 0 },
      goal = {
        text = replace(
          PRICING,
          '        return order.Lines.Sum(l => l.Price * l.Quantity) * (1 - discount);',
          '        var subtotal = order.Lines.Sum(l => l.Price * l.Quantity);\n        return subtotal * (1 - discount);'
        ),
      },
      solution = { 'vananan', 'csubtotal<Esc>', 'Ovar subtotal = <C-r>";<Esc>' },
      hint = 'v an an an selects the call, c cuts it into the unnamed register; then O and <C-r>" pastes it in insert mode.',
      requires = { parsers = { 'c_sharp' } },
    },
    {
      id = 'd7.guard-clause',
      skill = 'refactor-insert',
      title = 'Add a guard clause (C#)',
      task = 'Add `ArgumentNullException.ThrowIfNull(order);` as the first line of Total.',
      ft = 'cs',
      text = PRICING,
      cursor = { 'return', 0 },
      goal = {
        text = replace(PRICING, '    {\n        return', '    {\n        ArgumentNullException.ThrowIfNull(order);\n        return'),
      },
      solution = 'OArgumentNullException.ThrowIfNull(order);<Esc>',
      hint = 'O opens a line above with the right indent. (From anywhere in the method: [f to its start, then j o.)',
    },
    {
      id = 'd7.rename-local',
      skill = 'refactor-rename',
      title = 'Rename a local (TypeScript)',
      task = 'Rename `res` to `response` (three places), without the LSP.',
      ft = 'typescript',
      text = "async function load(url: string) {\n  const res = await fetch(url);\n  if (!res.ok) throw new Error(url);\n  return res.json();\n}\n",
      cursor = { 'res =', 0 },
      goal = { text = "async function load(url: string) {\n  const response = await fetch(url);\n  if (!response.ok) throw new Error(url);\n  return response.json();\n}\n" },
      solution = '*Ncgnresponse<Esc>..',
      hint = '* searches the whole word, N comes back, cgn changes the match, . repeats on the next. (Or :%s/\\<res\\>/response/g.)',
    },
    {
      id = 'd7.dto-macro',
      skill = 'refactor-macro',
      title = 'Fields to properties (C# macro)',
      task = 'Turn each field into a public auto-property with a capitalised name.',
      ft = 'cs',
      text = 'public class EmployeeDto\n{\n    string name;\n    int age;\n    decimal salary;\n}\n',
      cursor = { 'string', 0 },
      goal = { text = 'public class EmployeeDto\n{\n    public string Name { get; set; }\n    public int Age { get; set; }\n    public decimal Salary { get; set; }\n}\n' },
      solution = { 'qq^ipublic <Esc>WW~$C { get; set; }<Esc>jq', '2@q' },
      hint = 'qq · ^ipublic <Esc> · WW~ (capitalise) · $C { get; set; }<Esc> · j · q, then 2@q.',
    },
    {
      id = 'd7.sql-query',
      skill = 'refactor-sql',
      title = 'Tighten a query (SQL)',
      task = 'Select only `o.Id, o.Total, c.Name` and add `WHERE o.Status = \'Paid\'` above ORDER BY.',
      ft = 'sql',
      text = 'SELECT *\nFROM Orders o\nJOIN Customers c ON c.Id = o.CustomerId\nORDER BY o.PlacedAt DESC;\n',
      cursor = { 1, 0 },
      goal = { text = "SELECT o.Id, o.Total, c.Name\nFROM Orders o\nJOIN Customers c ON c.Id = o.CustomerId\nWHERE o.Status = 'Paid'\nORDER BY o.PlacedAt DESC;\n" },
      solution = { '$Co.Id, o.Total, c.Name<Esc>', "3jOWHERE o.Status = 'Paid'<Esc>" },
      hint = "$C rewrites the end of the line; 3j O opens a line above ORDER BY.",
    },
    {
      id = 'd7.lua-keymap',
      skill = 'refactor-lua',
      title = 'Copy a mapping (your Lua config)',
      task = 'Duplicate the wrap toggle and turn the copy into a `list` toggle on <leader>tl.',
      ft = 'lua',
      text = "map('n', '<leader>tW', function() vim.o.wrap = not vim.o.wrap end, { desc = '[T]oggle [W]rap' })\n",
      cursor = { 1, 0 },
      goal = {
        text = "map('n', '<leader>tW', function() vim.o.wrap = not vim.o.wrap end, { desc = '[T]oggle [W]rap' })\n"
          .. "map('n', '<leader>tl', function() vim.o.list = not vim.o.list end, { desc = '[T]oggle [L]ist' })\n",
      },
      solution = { 'yyp', ':s/wrap/list/g<CR>', 'fW', 'rl', ';', 'rL', '2lciwist<Esc>' },
      hint = 'yyp · :s/wrap/list/g · fW rl · ; rL · 2l ciwist<Esc>',
    },
    {
      id = 'd7.remove-only',
      skill = 'refactor-substitute',
      title = 'Un-focus the tests (TypeScript)',
      task = 'Someone left `.only` on two tests. Remove both.',
      ft = 'typescript',
      text = "describe('OrderApi', () => {\n  it.only('loads an order', async () => {});\n  it('saves an order', async () => {});\n  it.only('deletes an order', async () => {});\n});\n",
      goal = { text = "describe('OrderApi', () => {\n  it('loads an order', async () => {});\n  it('saves an order', async () => {});\n  it('deletes an order', async () => {});\n});\n" },
      solution = ':%s/\\.only//<CR>',
      hint = ':%s/\\.only// (the dot needs escaping). Or /\\.only<CR> d4l n .',
    },
    {
      id = 'd7.wrap-await',
      skill = 'refactor-surround',
      title = 'Await and wrap (TypeScript)',
      task = 'Make it `const items = await Promise.all(promises);`.',
      ft = 'typescript',
      text = 'const items = promises;\n',
      cursor = { 'promises', 0 },
      goal = { text = 'const items = await Promise.all(promises);\n' },
      solution = { 'gsaiwfPromise.all<CR>', 'Biawait <Esc>' },
      hint = 'gsaiwf wraps the word in a call (asks for the name) and leaves you on the word: B, then iawait.',
      requires = { maps = { { 'n', 'gsa' } } },
    },
    {
      id = 'd7.boss',
      skill = 'refactor-mixed',
      title = 'Review comments, all of them',
      task = 'Swap the parameters, delete the debug line (keep your registers),\nuse customer.Currency instead of "EUR", and rename `invoice` to `draft`.',
      ft = 'cs',
      file = 'InvoiceService.cs',
      text = [[
public class InvoiceService
{
    public Invoice Create(Customer customer, Order order)
    {
        Console.WriteLine("debug");
        var invoice = new Invoice(order.Id, "EUR");
        invoice.Lines.AddRange(order.Lines.Select(ToLine));
        return invoice;
    }
}
]],
      cursor = { 'Customer customer', 0 },
      lsp = {},
      goal = {
        text = [[
public class InvoiceService
{
    public Invoice Create(Order order, Customer customer)
    {
        var draft = new Invoice(order.Id, customer.Currency);
        draft.Lines.AddRange(order.Lines.Select(ToLine));
        return draft;
    }
}
]],
      },
      solution = {
        '<leader>a',
        '2j<leader>dd',
        'ca"customer.Currency<Esc>',
        '^w',
        'grn<C-u>draft<CR>',
      },
      hint = '<leader>a · 2j <leader>dd · ca"customer.Currency<Esc> · ^w grn',
      requires = { maps = { { 'n', '<leader>a' }, { 'n', '<leader>d' } }, parsers = { 'c_sharp' }, lsp_attach = true },
      boss = true,
    },
  },
}
