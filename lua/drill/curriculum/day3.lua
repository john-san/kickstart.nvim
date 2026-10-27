local IMPORT = [[
public async Task ImportAsync(IEnumerable<Row> rows)
{
    foreach (var r in rows)
    {
        Console.WriteLine("row " + r.Id);
        try
        {
            await _db.Customers.AddAsync(Map(r));
            Console.WriteLine("added");
        }
        catch (Exception e)
        {
            _logger.LogError(e, "Import failed for {Id}", r.Id);
        }
    }
    Console.WriteLine("done");
}
]]

local PRICING = [[
public decimal Total(Customer cust, Order order)
{
    var rate = cust.IsPremium ? 0.9m : 1m;
    if (cust.Country != order.Country) rate += 0.05m;
    return order.Subtotal * rate;
}
]]

local SCOPED = [[
function total(items: Item[]): number {
  return items.reduce((sum, x) => sum + x.price * x.qty, 0);
}

function count(items: Item[]): number {
  return items.filter((x) => x.qty > 0).length;
}
]]

local WORKER = [[
public async Task RunAsync(CancellationToken ct)
{
    _logger.LogDebug("Worker starting");
    while (!ct.IsCancellationRequested)
    {
        var batch = await _queue.TakeAsync(ct);
        _logger.LogDebug("Took {Count} messages", batch.Count);
        await _handler.HandleAsync(batch, ct);
        _logger.LogDebug("Batch handled");
    }
}
]]

return {
  title = 'Visual, registers, macros, :s and :g',
  why = 'This is where Vim stops being an editor and becomes a text-processing tool. '
    .. 'Block insert edits ten lines at once, registers keep several clipboards, a macro or :normal '
    .. 'repeats an edit on every line, and :s / :g do in one command what would take minutes by hand.',
  drills = {
    {
      id = 'd3.block-insert',
      skill = 'visual block',
      title = 'Block insert',
      task = 'Make all three fields `private`.',
      ft = 'cs',
      text = '    string Name;\n    string Email;\n    string Phone;\n',
      cursor = { 1, 4 },
      goal = { text = '    private string Name;\n    private string Email;\n    private string Phone;\n' },
      solution = '<C-v>2jIprivate <Esc>',
      hint = '<C-v> starts a block, 2j extends it, I inserts on every line when you press <Esc>.',
    },
    {
      id = 'd3.block-append',
      skill = 'visual block',
      title = 'Append to ragged lines',
      task = 'Add the missing `;` to the end of every line.',
      ft = 'typescript',
      text = "const a = 1\nconst label = 'total'\nconst items = []\n",
      cursor = { 1, 0 },
      goal = { text = "const a = 1;\nconst label = 'total';\nconst items = [];\n" },
      solution = '<C-v>2j$A;<Esc>',
      hint = 'In a block, $ extends every line to its own end, and A appends after it.',
    },
    {
      id = 'd3.visual-substitute',
      skill = 'visual + :s',
      title = 'Substitute inside a selection',
      task = 'Rename `x` to `item`, but only inside total().',
      ft = 'typescript',
      text = SCOPED,
      cursor = { 'items.reduce', 0 },
      goal = { text = SCOPED:gsub('sum, x%) => sum %+ x%.price %* x%.qty', 'sum, item) => sum + item.price * item.qty') },
      solution = 'vip:s/\\<lt>x\\>/item/g<CR>',
      hint = "vip selects the function; : then starts with '<,'> so :s only touches the selection. \\<x\\> matches x as a whole word.",
    },
    {
      id = 'd3.register-named',
      skill = 'registers',
      title = 'A register that survives dd',
      task = 'Pass the `conn` string to UseSqlServer(...) and delete the legacy line.\nThe delete overwrites the unnamed register, so keep the string in register a.',
      ft = 'cs',
      text = [[
// TODO: move to appsettings
var conn = "Server=sql01;Database=Shop;Trusted_Connection=True;";
var legacy = "Server=old;Database=Shop_Old;";
var options = new DbContextOptionsBuilder().UseSqlServer().Options;
]],
      cursor = { 2, 0 },
      goal = {
        text = [[
// TODO: move to appsettings
var conn = "Server=sql01;Database=Shop;Trusted_Connection=True;";
var options = new DbContextOptionsBuilder().UseSqlServer("Server=sql01;Database=Shop;Trusted_Connection=True;").Options;
]],
      },
      solution = { '"aya"jdd', 'f(', ';', '"ap' },
      hint = '"aya" yanks the quoted string into a. Then jdd, f( ; to the UseSqlServer paren, "ap. (\"0p would also work: register 0 holds the last yank.)',
    },
    {
      id = 'd3.insert-register',
      skill = 'registers',
      title = 'Paste a register while typing',
      task = 'Fill the log message so it reads "Processing orderId".',
      ft = 'cs',
      text = 'var orderId = request.OrderId;\n_logger.LogInformation("");\n',
      cursor = { 1, 'orderId' },
      goal = { text = 'var orderId = request.OrderId;\n_logger.LogInformation("Processing orderId");\n' },
      solution = 'yiwjci"Processing <C-r>0<Esc>',
      hint = 'yiw, then ci"… and <C-r>0 in insert mode. Not <C-r>": the ci" just replaced the unnamed register with the (empty) text it deleted; register 0 still holds the yank.',
    },
    {
      id = 'd3.macro',
      skill = 'macros',
      title = 'Record once, replay three times',
      task = 'Turn each property name into `dto.X = entity.X;`',
      ft = 'cs',
      text = 'Id\nName\nEmail\nCreatedAt\n',
      cursor = { 1, 0 },
      goal = { text = 'dto.Id = entity.Id;\ndto.Name = entity.Name;\ndto.Email = entity.Email;\ndto.CreatedAt = entity.CreatedAt;\n' },
      solution = 'qayiwIdto.<Esc>A = entity.<C-r>";<Esc>jq3@a',
      hint = 'qa starts recording into a; do line 1 and end with j; q stops; 3@a replays (@@ repeats the last macro).',
    },
    {
      id = 'd3.normal',
      skill = ':normal',
      title = 'Run normal-mode keys on a range',
      task = 'Add a trailing comma to every enum member.',
      ft = 'typescript',
      text = 'export enum Status {\n  Pending\n  Paid\n  Shipped\n  Cancelled\n}\n',
      cursor = { 1, 0 },
      goal = { text = 'export enum Status {\n  Pending,\n  Paid,\n  Shipped,\n  Cancelled,\n}\n' },
      solution = ':2,5norm A,<CR>',
      hint = ':2,5norm A, runs `A,` on lines 2-5. Also works on a visual selection: V…:norm A,',
    },
    {
      id = 'd3.star-substitute',
      skill = ':s',
      title = 'Search once, substitute with an empty pattern',
      task = 'Rename the parameter `cust` to `customer` everywhere.\n(Careful: `Customer` must stay.)',
      ft = 'cs',
      text = PRICING,
      cursor = { 'Customer cust', 9 },
      goal = { text = PRICING:gsub('cust([%.%,%s])', 'customer%1') },
      solution = '*:%s//customer/g<CR>',
      hint = '* searches \\<cust\\> (whole word). :%s//customer/g reuses the last search pattern.',
    },
    {
      id = 'd3.capture',
      skill = ':s',
      title = 'Capture groups',
      task = 'Strip the brackets: `[dbo].[Orders]` → `dbo.Orders` (all of them).',
      ft = 'sql',
      text = 'SELECT o.[Id], o.[Total]\nFROM [dbo].[Orders] o\nJOIN [dbo].[Customers] c ON c.[Id] = o.[CustomerId];\n',
      cursor = { 1, 0 },
      goal = { text = 'SELECT o.Id, o.Total\nFROM dbo.Orders o\nJOIN dbo.Customers c ON c.Id = o.CustomerId;\n' },
      solution = ':%s/\\[\\(\\w\\+\\)\\]/\\1/g<CR>',
      hint = ':%s/\\[\\(\\w\\+\\)\\]/\\1/g  (or very magic: :%s/\\v\\[(\\w+)\\]/\\1/g). \\1 is the captured name.',
    },
    {
      id = 'd3.g-delete',
      skill = ':g',
      title = 'Delete every matching line',
      task = 'Remove all the LogDebug lines.',
      ft = 'cs',
      text = WORKER,
      cursor = { 1, 0 },
      goal = { text = WORKER:gsub('        _logger%.LogDebug[^\n]*\n', ''):gsub('    _logger%.LogDebug[^\n]*\n', '') },
      solution = ':g/LogDebug/d<CR>',
      hint = ':g/pattern/d deletes every line matching pattern. :v/pattern/d deletes the others.',
    },
    {
      id = 'd3.g-normal',
      skill = ':g',
      title = ':g + :normal',
      task = 'Comment out (with `// `) every LogDebug line instead of deleting it.',
      ft = 'cs',
      text = WORKER,
      cursor = { 1, 0 },
      goal = { text = WORKER:gsub('(%s+)(_logger%.LogDebug)', '%1// %2') },
      solution = ':g/LogDebug/norm I// <CR>',
      hint = ':g/LogDebug/norm I// runs `I// ` on each matching line.',
    },
    {
      id = 'd3.boss',
      skill = 'ex-mixed',
      title = 'Import cleanup',
      task = 'Match the target: drop every Console.WriteLine,\nrename `r` → `row` and `e` → `ex` (whole words only).',
      ft = 'cs',
      text = IMPORT,
      cursor = { 1, 0 },
      goal = {
        text = [[
public async Task ImportAsync(IEnumerable<Row> rows)
{
    foreach (var row in rows)
    {
        try
        {
            await _db.Customers.AddAsync(Map(row));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Import failed for {Id}", row.Id);
        }
    }
}
]],
      },
      solution = { ':g/Console/d<CR>', ':%s/\\<lt>r\\>/row/g<CR>', ':%s/\\<lt>e\\>/ex/g<CR>' },
      hint = ':g/Console/d · :%s/\\<r\\>/row/g · :%s/\\<e\\>/ex/g',
      boss = true,
    },
  },
}
