# drill: a 7-day course in your own Neovim

A pure-Lua plugin (no dependencies beyond Neovim 0.12 and the plugins your config already has) that
drills the motions, plugins and keymaps of **this** config inside the real editor. Every drill is a
starting state plus a goal; it passes when the editor state matches the goal (text, cursor, mode,
windows, registers, quickfix, files…), never by checking which keys you pressed. Keys are counted
only for scoring.

```
:DrillDay 1        start Day 1 (15–20 min)
:Drill             continue: the first day you have not cleared, or a Leitner review once all are done
:DrillStats        level, XP, streak, per-skill Leitner boxes, day results
```

## Commands

| Command | Does |
|---|---|
| `:DrillDay N` | Day N: a warmup of up to 4 drills you missed last time, the day's drills, up to 2 reviews of weak skills, then the boss |
| `:Drill` / `:Drill today` | The first day not yet cleared (a day is cleared when its boss passes and ≥60% of its drills pass) |
| `:Drill review` | Skills whose Leitner box is due |
| `:Drill warmup` | Only last session's misses |
| `:Drill speedrun` | 10 random drills from days you have reached, against the clock; keeps your personal best |
| `:Drill list` | Every drill, ✔ runnable / ✘ skipped (with the reason) |
| `:Drill <id>` | One drill, e.g. `:Drill d5.swap-params` (Tab completes) |
| `:Drill retry` / `skip` / `hint` / `next` | Same as `<M-r>` / `<M-s>` / `<M-/>` / `n`, for when Alt keys don't reach Neovim (the keys you type for the command are not counted) |
| `:Drill quit` | Leave the session (or `<M-q>`) |
| `:Drill! reset` | Erase all progress |

## During a drill

The session opens in its own tab. The panel (top right) shows the task, a **TARGET** diff of what
must change, par, your key count, the clock and your combo. Just edit until the goal is met; the
drill passes the moment the state matches.

| Keys | When | Does |
|---|---|---|
| `<M-r>` | any mode | Retry from the starting state |
| `<M-s>` | any mode | Skip (counts as a miss) |
| `<M-/>` | any mode | Hint (−30); press again for the full solution (−30 more) |
| `<M-q>` | any mode | Quit the session |
| `n` / `<CR>` | after a result | Next drill |
| `r` / `s` / `?` / `q` | after a result | Retry / skip / show solution / quit |

`<M-…>` means Alt. After a result, focus sits on the panel so these plain keys work; clicking or
`<C-w>`-ing back into the drill buffer returns focus to the panel.

## Scoring

- **Base** 100 points (boss: 300) × efficiency (par ÷ your keys, capped at 1).
- **At or under par:** +25, plus 15 per key under. Golf labels: ALBATROSS, EAGLE, BIRDIE, PAR, BOGEY…
- **Speed:** +20 if you finish within par + 4 seconds.
- **Penalties:** hjkl spam −5 each (the same h/j/k/l twice in a row without a count; on Day 1 any
  hjkl), arrow keys −10, mouse −15, hints −30.
- **Budget:** more than max(3 × par, par + 15) keys fails the attempt; you retry.
- **Combo:** each clean pass in a row adds ×0.1, up to ×2.0. A fail, skip or hint resets it.
- **XP and levels:** score becomes XP; level L needs 100 × (L−1)² XP. Titles go from
  *Arrow-Key Tourist* to *Neovim Native* (level 10).
- **Streak:** consecutive calendar days with at least one drill.
- **Leitner boxes per skill** (1–5, due again after 1, 2, 4, 7, 14 days): a clean pass (first try,
  no hints, at or under par) moves the skill up a box; a pass over par keeps it; a fail, skip or
  hint drops it to box 1. Misses feed the next day's warmup.

Progress lives in `stdpath('data')/drill.json` (`C:\Users\dapha\AppData\Local\nvim-data\drill.json`).

## The 7 days

| Day | Topic | Drills |
|---|---|---|
| 1 | Motions without hjkl or arrows (`w W e`, `0 ^ $`, `f t ; ,`, `%`, `{ }`, relative jumps, `G`, `*`, `H M L`, marks, jump list) | 17 |
| 2 | Operators + text objects, `.`, `;` `,`, `cgn` | 12 |
| 3 | Visual and block mode, registers, macros, `:normal`, search and replace, `:g` | 12 |
| 4 | Windows, buffers, tabs, quickfix, `:cdo`, global marks across files | 13 |
| 5 | Your plugins: mini.surround, flash, mini.ai + treesitter objects and jumps, parameter swap, incremental selection, comments, Telescope, gitsigns, neo-tree | 19 |
| 6 | Every custom keymap, the gitsigns leader maps, LSP actions (rename, code action, references, definition, implementation, type, symbols, hover, diagnostics, inlay hints), Trouble | 47 |
| 7 | Mixed refactors in C#, TypeScript, SQL and Lua, final boss, final scorecard | 9 |

Day 6 is the long one (about 25 minutes): most of its drills are one mapping each.

## Decisions I made (you asked me not to ask)

1. **Location.** The plugin, its docs (README, AUDIT, CHEATSHEET) and its tests all live in
   `lua/drill/`, so the course is one folder you can delete. The only config change is
   `require('drill').setup()` in `init.lua`, right after the custom settings in section 10.
2. **Control keys are on Alt.** `r`, `s` and `?` are Vim keys you need inside drills (and flash owns
   `s`), so during an attempt retry/skip/hint are `<M-r>`/`<M-s>`/`<M-/>`. Between drills, plain
   `r`/`s`/`?` work as asked.
3. **The clipboard is detached during a session** (`clipboard=''`, restored on quit) so drills
   never read from or write to your system clipboard. Registers a–z, 0–9, `"`, `-`, `/`, marks
   A–Z, the quickfix list and the options drills touch are saved and restored too.
4. **Sessions run in their own tab** and clean up every window, buffer and tab they create.
5. **Real files when a drill needs them.** Multi-file, git, `:write` and picker drills get a fresh
   directory under `stdpath('cache')/drill` (deleted afterwards); git drills get a throwaway
   repository with one commit. Other drills use scratch buffers named `drill://<id>`.
6. **A fake in-process language server for the LSP drills.** Your OmniSharp needs a .sln/.csproj
   and takes many seconds to start (and has no rename, code actions or hover). The drills attach a
   tiny deterministic server through `vim.lsp.start` instead, so `grn`, `gra`, `grr`, `grd`, `gri`,
   `grt`, `gO`, `gW`, `K`, `]d` and `<leader>th` run your real LspAttach mappings and Telescope
   pickers. In your own C# buffers, `grd`/`grr`/`gri`/`grt`/`gd` go through omnisharp-extended;
   `grn`/`gra`/`K` work in your TypeScript, Angular, Lua and JSON/YAML buffers.
7. **Format-on-save is off during sessions** (`vim.g.disable_autoformat`, restored afterwards), so
   saving a drill file never reformats it. Inlay-hint state is restored too.
8. **Key counting** uses `vim.on_key` on typed keys. which-key reads a key sequence and re-feeds it,
   which would double-count, so during a session the plugin recognises those re-feeds and ignores
   them (a small wrapper around `nvim_feedkeys`, removed on quit).
9. **Par is the key count of the reference solution.** One exception: running a mapping from the
   `<leader>sk` picker replays its keys, so that drill's par includes them.
10. **Flash char mode is respected, not worked around.** Where your flash config changes Vim
    behaviour (`dt)` needs `<CR>`), drills say so in the hint and solutions include it.
11. **Drills that need something you lack are skipped automatically** (missing mapping, executable,
    treesitter parser, plugin module or LSP setup) and listed by `:Drill list` and in AUDIT.md.
    They turn on by themselves when the requirement appears (ripgrep, for example).
12. **"Days" are content, not calendar locks.** You can run any day any time; the streak counts
    calendar days, and Day N is "cleared" once its boss passes with ≥60% of its drills.
13. **Speedrun skips bosses and four drills whose time is not yours** (H/M/L and half-page depend
    on window size; the terminal and `:checkhealth` drills wait on external processes).

## Tests

```
nvim --headless -l lua/drill/tests/run.lua         # everything (about 10 minutes)
nvim --headless -l lua/drill/tests/run.lua 5       # one day
nvim --headless -l lua/drill/tests/run.lua cgn     # drills whose id contains "cgn"
```

The tests load your real config, check the scoring and Leitner rules, and then, for every drill
your config can run, assert that the starting state does **not** pass (a no-op fails) and that
replaying the reference solution as typed keys through your mappings **does** pass. Progress goes to
a temp file. Notes:

- Run them from PowerShell or Windows Terminal, or unset `SHELL` first if you use Git Bash.
- Each run makes vim.pack re-add the orphaned DAP plugins to `nvim-pack-lock.json` (see AUDIT
  flag 9); `git checkout -- nvim-pack-lock.json` undoes it.
- `d6.terminal` is listed as not replayable headless (the shell exits at once without a UI);
  it works in the course.
- Headless replay has quirks real typing does not: keys typed right after a flash `f`/`t` must be a
  separate step, and pickers that open asynchronously need a wait. Solutions are split into steps
  for that reason; the hints show them as you would type them.

## Drill format

Each `curriculum/dayN.lua` returns `{ title, why, drills }`. A drill:

```lua
{
  id = 'd2.ci-quote',          -- unique; also the :Drill <id> name
  skill = 'text-objects',      -- Leitner skill it trains
  title = 'Change inside quotes',
  task = 'Replace the message with "Order not found".',
  ft = 'cs',                   -- filetype of the buffer
  text = [[...]],              -- starting text (or file = 'path' for a real file, plus files = {...})
  cursor = { 'needle', 0 },    -- {row, col} | {row} | {'needle', offset, nth} | {'needle', line = true}
  goal = { text = [[...]], cursor = {...}, mode = 'n', windows = 2, register = {'"', '...'},
           qf = 2, file = 'pattern', check = function(ctx) ... end },
  solution = 'ci"Order not found<Esc>',  -- or a list of steps / { wait_for = fn } for the tests
  hint = '...',
  requires = { maps = {{'n', 'gsa'}}, exe = {'git'}, parsers = {'c_sharp'}, modules = {'flash'}, lsp_attach = true },
  -- optional: setup(ctx), teardown(ctx), registers, marks, diagnostics, lsp = {...}, git = {...},
  -- boss = true, strict = true (any hjkl is spam), par = N, no_speedrun = true, test_skip = 'why'
}
```
