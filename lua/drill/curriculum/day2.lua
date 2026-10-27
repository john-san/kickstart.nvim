local COMPONENT = [[
@Component({
  selector: 'app-order-list',
  templateUrl: './order-list.component.html',
})
export class OrderListComponent implements OnInit {
  orders: Order[] = [];
  loading = false;
  private defaults = { page: 1, size: 20 };

  constructor(private api: OrderApi, private toast: ToastService) {}

  ngOnInit(): void {
    this.load('pending');
  }

  load(status: string): void {
    this.loading = true;
    this.api.list(status, 1).subscribe({
      next: (orders) => (this.orders = orders),
      error: (err) => this.toast.error('Could not load orders', err),
    });
  }
}
]]

local function edit(text, from, to) return (text:gsub(vim.pesc(from), (to:gsub('%%', '%%%%')), 1)) end

local TEMPLATE = [[
<div class="order" *ngFor="let order of orders">
  <span class="badge">{{ order.status }}</span>
  <button (click)="cancel(order)">Cancel</button>
</div>
]]

local REPO = [[
public class CustomerRepository
{
    private readonly IClock _clock;
    private readonly AppDbContext _db;

    public Customer? Find(int id)
    {
        return _db.Customers.Find(id);
    }

    public void Touch(Customer customer)
    {
        customer.LastSeen = _clock.UtcNow;
        _db.SaveChanges();
    }

    public IEnumerable<Customer> Active()
    {
        return _db.Customers.Where(c => c.IsActive);
    }
}
]]

local CALLS = [[
var a = await client.FetchOrder(1);
var b = await client.FetchOrder(2);
var c = await client.FetchOrder(3);
]]

local BOSS = [[
  save(order: Order, notify: boolean): Observable<Order> {
    const url = '/api/v1/orders/' + order.id;
    return this.http.put<Order>(url, order, { headers: this.headers }).pipe(
      tap(() => this.toast.success('Saved order')),
    );
  }
]]

return {
  title = 'Operators + text objects',
  why = 'Vim edits are sentences: operator (d c y) + motion or text object (iw a( i" it ip). '
    .. 'Once you think "change inside quotes" instead of "move, select, delete, type", every edit '
    .. 'shrinks to 3-4 keys, and . repeats the whole sentence.',
  drills = {
    {
      id = 'd2.ci-quote',
      skill = 'i" i\'',
      title = 'Change inside quotes',
      task = "Change 'pending' to 'open'. Start from the beginning of the line.",
      ft = 'typescript',
      text = COMPONENT,
      cursor = { "this.load('pending')", 0 },
      goal = { text = edit(COMPONENT, "'pending'", "'open'") },
      solution = "ci'open<Esc>",
      hint = "ci' works even before the quotes: it finds the next quoted string on the line.",
    },
    {
      id = 'd2.dt',
      skill = 'dt / ct',
      title = 'Delete up to a character',
      task = 'Drop the page argument: `list(status, 1)` → `list(status)`.',
      ft = 'typescript',
      text = COMPONENT,
      cursor = { 'this.api.list', 0 },
      goal = { text = edit(COMPONENT, 'list(status, 1)', 'list(status)') },
      solution = { 'f,', 'dt)<CR>' },
      hint = 'f, to reach the comma, then dt) deletes up to (not including) the ). Your flash config labels the other `)`s and waits: <CR> accepts the nearest.',
    },
    {
      id = 'd2.ciw-dot',
      skill = 'iw + .',
      title = 'Rename a parameter, repeat with .',
      task = 'Rename the arrow-function parameter `orders` to `list`:\nthe parameter and its use after `=` (not `this.orders`).',
      ft = 'typescript',
      text = COMPONENT,
      cursor = { '(orders) =>', 1 },
      goal = { text = edit(COMPONENT, '(orders) => (this.orders = orders)', '(list) => (this.orders = list)') },
      solution = 'ciwlist<Esc>$2b.',
      hint = 'ciwlist<Esc> on the first one, move to the last one ($ then 2b), and . repeats the change.',
    },
    {
      id = 'd2.di-brace',
      skill = 'i{ i( i[',
      title = 'Empty an object literal',
      task = 'Make `defaults` an empty object: `{}`.',
      ft = 'typescript',
      text = COMPONENT,
      cursor = { 'private defaults', 0 },
      goal = { text = edit(COMPONENT, '{ page: 1, size: 20 }', '{}') },
      solution = 'di}',
      hint = 'With your mini.ai, di} (or dib) empties the braces; di{ keeps the inner padding: `{  }`. Either finds the next pair from before it.',
    },
    {
      id = 'd2.cit',
      skill = 'it at',
      title = 'Change inside a tag',
      task = 'Replace the badge text with `Pending`.',
      ft = 'html',
      text = TEMPLATE,
      cursor = { '{{ order.status }}', 0 },
      goal = { text = edit(TEMPLATE, '{{ order.status }}', 'Pending') },
      solution = 'citPending<Esc>',
      hint = 'cit changes everything between <span ...> and </span>.',
    },
    {
      id = 'd2.dap',
      skill = 'ip ap',
      title = 'Delete a whole method',
      task = 'Delete the Touch method, including the blank line after it.',
      ft = 'cs',
      text = REPO,
      cursor = { 'customer.LastSeen', 0 },
      goal = {
        text = edit(REPO, '    public void Touch(Customer customer)\n    {\n        customer.LastSeen = _clock.UtcNow;\n        _db.SaveChanges();\n    }\n\n', ''),
      },
      solution = 'dap',
      hint = 'ap is "a paragraph": the block of non-blank lines plus the blank after it.',
    },
    {
      id = 'd2.daw',
      skill = 'iw aw',
      title = 'Delete a word and its space',
      task = 'Remove `readonly` from the `_clock` field.',
      ft = 'cs',
      text = REPO,
      cursor = { 'readonly IClock', 0 },
      goal = { text = edit(REPO, 'private readonly IClock', 'private IClock') },
      solution = 'daw',
      hint = 'aw includes the trailing space, so no double space is left behind.',
    },
    {
      id = 'd2.yank-paste',
      skill = 'y + p',
      title = 'Copy the arguments over',
      task = 'Give the second call the same arguments as the first.',
      ft = 'cs',
      text = 'var total = Calculate(order.Lines, customer.Tier);\nvar preview = Calculate();\n',
      cursor = { 1, 0 },
      goal = { text = 'var total = Calculate(order.Lines, customer.Tier);\nvar preview = Calculate(order.Lines, customer.Tier);\n' },
      solution = { 'yi(j', 'f(', 'p' },
      hint = 'yi( yanks inside the parens (it finds the next pair), j f( to the empty call, p pastes after the (.',
    },
    {
      id = 'd2.cgn',
      skill = 'cgn + .',
      title = 'Change every match with cgn',
      task = 'Rename FetchOrder to GetOrder in all three calls.',
      ft = 'cs',
      text = CALLS,
      cursor = { 'FetchOrder', 0 },
      goal = { text = CALLS:gsub('FetchOrder', 'GetOrder') },
      solution = '*NcgnGetOrder<Esc>..',
      hint = '* searches the word (N comes back), cgn changes the next match, . repeats on the following one.',
    },
    {
      id = 'd2.semicolon-dot',
      skill = '; ,',
      title = 'Find, change, repeat',
      task = 'Put a space after every comma.',
      ft = 'typescript',
      text = 'const pageSizes = [10,20,50,100];\n',
      cursor = { 1, 0 },
      goal = { text = 'const pageSizes = [10, 20, 50, 100];\n' },
      solution = { 'f,', 'a <Esc>', ';', '.', ';', '.' },
      hint = 'f,a <Esc> once, then ; finds the next comma and . repeats the insert.',
    },
    {
      id = 'd2.C',
      skill = 'C D',
      title = 'Change to the end of the line',
      task = 'Replace `30 * 1000; // TODO tune` with `env.timeoutMs;`',
      ft = 'typescript',
      text = 'const retries = 3;\nconst timeout = 30 * 1000; // TODO tune\n',
      cursor = { 2, '30' },
      goal = { text = 'const retries = 3;\nconst timeout = env.timeoutMs;\n' },
      solution = 'Cenv.timeoutMs;<Esc>',
      hint = 'C = c$ (change to end of line); D = d$.',
    },
    {
      id = 'd2.boss',
      skill = 'operators-mixed',
      title = 'Clean up save()',
      task = 'Match the target: drop the notify parameter, bump v1 → v2,\ndrop the headers options and reword the toast.',
      ft = 'typescript',
      text = BOSS,
      cursor = { 1, 0 },
      goal = {
        text = [[
  save(order: Order): Observable<Order> {
    const url = '/api/v2/orders/' + order.id;
    return this.http.put<Order>(url, order).pipe(
      tap(() => this.toast.success('Order saved')),
    );
  }
]],
      },
      solution = { 'f,', 'dt)<CR>', 'j', 'f1', 'r2', 'j', 'f,', ';', 'dt)<CR>', "jci'Order saved<Esc>" },
      hint = "f, dt)<CR> · j f1 r2 · j f, ; dt)<CR> · j ci'…  (<CR> accepts flash's nearest target)",
      boss = true,
    },
  },
}
