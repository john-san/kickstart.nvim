local H = require 'drill.curriculum.helpers'

local SERVICE = [[
using System;
using System.Linq;
using System.Threading.Tasks;

namespace Shop.Orders;

public class OrderService
{
    private readonly IOrderRepository _orders;
    private readonly ILogger<OrderService> _logger;

    public OrderService(IOrderRepository orders, ILogger<OrderService> logger)
    {
        _orders = orders;
        _logger = logger;
    }

    public async Task<Order> GetAsync(int orderId)
    {
        var order = await _orders.FindAsync(orderId);
        if (order is null)
        {
            throw new NotFoundException($"Order {orderId} not found");
        }
        return order;
    }

    public decimal ApplyDiscount(Customer customer, decimal amount)
    {
        var discount = customer.IsPremium ? 0.1m : 0m;
        return amount - amount * discount;
    }

    public async Task ProcessAsync(int orderId)
    {
        try
        {
            var order = await GetAsync(orderId);
            if (order.Lines.Any(l => l.Quantity <= 0 || l.Price < 0))
            {
                _logger.LogWarning("Order {OrderId} has invalid lines", orderId);
                return;
            }
            order.Status = OrderStatus.Processed;
            await _orders.SaveAsync(order);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Saving order {OrderId} failed", orderId);
            throw;
        }
    }
}
]]

local API = [[
import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, map } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class OrderApi {
  private readonly baseUrl = '/api/orders';

  constructor(private http: HttpClient) {}

  list(status: string, page = 1): Observable<Order[]> {
    const params = new HttpParams().set('status', status).set('page', page);
    return this.http.get<Order[]>(this.baseUrl, { params }).pipe(map((res) => res ?? []));
  }

  get(id: number): Observable<Order> {
    return this.http.get<Order>(`${this.baseUrl}/${id}`);
  }
}
]]

-- A long file for screen-relative motions (H/M/L, <C-d>).
local LONG = {}
for i = 1, 120 do
  LONG[#LONG + 1] = ('    public const int Code%03d = %d; // generated error code'):format(i, 1000 + i)
end

return {
  title = 'Motions: stop walking, start jumping',
  why = 'Every edit starts with getting somewhere. hjkl and arrows cost one key per character; '
    .. 'w/e/b, f/t, %, {}, counts with your relative numbers, marks and the jumplist get you anywhere '
    .. 'in two or three keys. Today every uncounted hjkl costs points.',
  drills = {
    {
      id = 'd1.w-count',
      skill = 'w/b/e',
      title = 'Count your words',
      task = 'Land on `customer` (the one after `=`).\nCount the words and put the count before w.',
      ft = 'cs',
      text = SERVICE,
      cursor = { 'var discount', 0 },
      goal = { cursor = { 'customer.IsPremium', 0 } },
      solution = '3w',
      hint = 'var · discount · = · customer: three w hops, so 3w.',
      strict = true,
    },
    {
      id = 'd1.W',
      skill = 'W/B/E',
      title = 'WORDs ignore punctuation',
      task = 'Land on `0.1m`.\nw stops at every `.`; W only stops at whitespace.',
      ft = 'cs',
      text = SERVICE,
      cursor = { 'customer.IsPremium', 0 },
      goal = { cursor = { '0.1m', 0 } },
      solution = '2W',
      hint = '`customer.IsPremium` is one WORD, `?` is the next: 2W.',
      strict = true,
    },
    {
      id = 'd1.e',
      skill = 'w/b/e',
      title = 'Ends of words',
      task = 'Put the cursor on the last letter of the second `amount` (before `*`).',
      ft = 'cs',
      text = SERVICE,
      cursor = { 'return amount', 0 },
      goal = { cursor = { 'amount *', 5 } },
      solution = '4e',
      hint = 'e goes to the end of the next word: return, amount, -, amount.',
      strict = true,
    },
    H.with({
      id = 'd1.line-ends',
      skill = '0/^/$',
      title = 'Line ends without walking',
      task = 'Visit the `;` at the end of the line, then the first non-blank character.',
      ft = 'cs',
      text = SERVICE,
      cursor = { 'return amount', 7 },
      goal = {},
      solution = { '$', '^' },
      hint = '$ goes to the end; ^ to the first non-blank (0 is column zero, before the indent).',
      strict = true,
    }, H.tour { { 'amount * discount;', 17 }, { 'return amount', 0 } }),
    {
      id = 'd1.f',
      skill = 'f/t',
      title = 'Find a character',
      task = 'Land on the `{` of `{ params }`.',
      ft = 'typescript',
      text = API,
      cursor = { 'return this.http.get<Order[]>', 0 },
      goal = { cursor = { '{ params }', 0 } },
      solution = 'f{',
      hint = 'f{ jumps to the next `{`. Your flash.nvim makes f/t reach past the line too.',
      strict = true,
    },
    {
      id = 'd1.f-repeat',
      skill = 'f/t',
      title = 'Repeat the find',
      task = 'Land on the `(` right before `res)`.\nIt is the fourth `(` on the line.',
      ft = 'typescript',
      text = API,
      cursor = { 'return this.http.get<Order[]>', 0 },
      goal = { cursor = { '(res)', 0 } },
      solution = 'f(;;;',
      hint = 'f( then ; repeats the same find forward (, goes back).',
      strict = true,
    },
    {
      id = 'd1.F',
      skill = 'f/t',
      title = 'Find backwards',
      task = 'From the end of the line, land on the `.` before `pipe`.',
      ft = 'typescript',
      text = API,
      cursor = { '[]));', 4 },
      goal = { cursor = { '.pipe', 0 } },
      solution = 'F.',
      hint = 'F searches backwards on the line.',
      strict = true,
    },
    {
      id = 'd1.percent',
      skill = '%',
      title = 'Bracket partner',
      task = 'Land on the `)` that closes this `if (` condition.',
      ft = 'cs',
      text = SERVICE,
      cursor = { 'if (order.Lines', 0 },
      goal = { cursor = { 'l.Price < 0))', 12 } },
      solution = '%',
      hint = '% on a non-bracket character jumps from the next bracket on the line to its partner.',
      strict = true,
    },
    {
      id = 'd1.paragraph',
      skill = '{ }',
      title = 'Paragraph hops',
      task = 'Land on the blank line just above `ApplyDiscount`.',
      ft = 'cs',
      text = SERVICE,
      cursor = { 'public OrderService(', 0 },
      goal = { cursor = { 'public decimal ApplyDiscount', dr = -1 } },
      solution = '2}',
      hint = '} jumps to the next blank line. Two methods down: 2}.',
      strict = true,
    },
    {
      id = 'd1.relative',
      skill = 'counts',
      title = 'Trust the relative numbers',
      task = 'Go down to the `public decimal ApplyDiscount` line.\nYour relativenumber column shows the distance.',
      ft = 'cs',
      text = SERVICE,
      cursor = { 'if (order is null)', 0 },
      goal = { cursor = { 'public decimal ApplyDiscount', line = true } },
      solution = '7j',
      hint = 'Read the relative number on the target line and type it before j: 7j. Counted j/k is never penalised.',
      strict = true,
    },
    {
      id = 'd1.G',
      skill = 'G/gg',
      title = 'Line from a stack trace',
      task = 'The stack trace says OrderService.cs:45. Go there.',
      ft = 'cs',
      text = SERVICE,
      goal = { cursor = { 45 } },
      solution = '45G',
      hint = '45G (or :45<CR>). gg/G alone go to the first/last line.',
      strict = true,
    },
    {
      id = 'd1.star',
      skill = 'search',
      title = 'Next use of this word',
      task = 'From the `baseUrl` field, jump to its use inside get() (the last one).',
      ft = 'typescript',
      text = API,
      cursor = { 'baseUrl =', 0 },
      goal = { cursor = { 'baseUrl}/', 0 } },
      solution = '*n',
      hint = '* searches for the word under the cursor; n goes to the next match.',
      strict = true,
    },
    {
      id = 'd1.L',
      skill = 'H/M/L',
      title = 'Bottom of the screen',
      task = 'Jump to the lowest line you can reach without scrolling.\n(H = high, M = middle, L = low; scrolloff keeps you 10 lines off the edge.)',
      ft = 'cs',
      text = LONG,
      goal = { check = function() return vim.api.nvim_win_get_cursor(0)[1] == H.simulate 'L' end },
      solution = 'L',
      hint = 'L. Then <C-d>/<C-u> scroll half a page and keep the cursor centred (your config adds zz).',
      strict = true,
      no_speedrun = true,
    },
    H.with({
      id = 'd1.marks',
      skill = 'marks',
      title = 'Leave a bookmark',
      task = 'Set mark `a` on this line, go check the usings at the top (gg),\nthen come back to the mark.',
      ft = 'cs',
      text = SERVICE,
      cursor = { 'var discount', 0 },
      goal = {},
      solution = { 'ma', 'gg', "'a" },
      hint = "ma sets mark a; gg goes to the top; 'a returns to the line (`a to the exact column).",
      strict = true,
    }, {
      setup = function(ctx) ctx.seen_top = false end,
      check = function(ctx)
        local row = vim.api.nvim_win_get_cursor(0)[1]
        if row <= 3 then ctx.seen_top = true end
        local m = vim.api.nvim_buf_get_mark(ctx.buf, 'a')
        local want = require('drill.goal').pos({ 'var discount', line = true }, ctx.start_lines)
        return ctx.seen_top and m[1] == want and row == want
      end,
    }),
    {
      id = 'd1.jumplist',
      skill = 'jumplist',
      title = 'Jump back',
      task = 'You just jumped here from the `GetAsync` call in ProcessAsync.\nGo back where you came from.',
      ft = 'cs',
      text = SERVICE,
      cursor = { 1, 0 },
      setup = function()
        local goal = require 'drill.goal'
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        vim.cmd(('normal! %dG'):format((goal.pos({ 'await GetAsync', line = true }, lines))))
        vim.cmd(('normal! %dG'):format((goal.pos({ 'public async Task<Order> GetAsync', line = true }, lines))))
      end,
      goal = { cursor = { 'await GetAsync', line = true } },
      solution = '<C-o>',
      hint = '<C-o> goes back in the jumplist, <C-i> (Tab) forward. Searches, G, %, marks are all jumps.',
      strict = true,
    },
    {
      id = 'd1.jumplist-forward',
      skill = 'jumplist',
      title = 'And forward again',
      task = 'You went back with <C-o>. Now go forward to GetAsync again.',
      ft = 'cs',
      text = SERVICE,
      cursor = { 1, 0 },
      setup = function()
        local goal = require 'drill.goal'
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        vim.cmd(('normal! %dG'):format((goal.pos({ 'await GetAsync', line = true }, lines))))
        vim.cmd(('normal! %dG'):format((goal.pos({ 'public async Task<Order> GetAsync', line = true }, lines))))
        vim.cmd(vim.keycode 'normal! <C-o>')
      end,
      goal = { cursor = { 'public async Task<Order> GetAsync', line = true } },
      solution = '<C-i>',
      hint = '<C-i> (same key as Tab in most terminals) moves forward in the jumplist.',
      strict = true,
    },
    H.with({
      id = 'd1.boss',
      skill = 'motions-mixed',
      title = 'Code review walk',
      task = 'Visit, in order (the ◎ shows the next stop):\n 1. `catch`   2. `DbUpdateException`\n 3. the `"` before Saving   4. back to where you started',
      ft = 'cs',
      text = SERVICE,
      cursor = { 1, 0 },
      goal = {},
      solution = { '/catch<CR>', '2w', '2jf"', '<C-o>' },
      hint = 'Search (/catch), count words (2w), counted j plus f", then <C-o> since the search was a jump.',
      boss = true,
      strict = true,
    }, H.tour { { 'catch (', 0 }, { 'DbUpdateException', 0 }, { '"Saving', 0 }, { 1, 0 } }),
  },
}
