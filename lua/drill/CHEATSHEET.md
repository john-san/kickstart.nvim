# Cheat sheet: your 40 most useful keys

Picked from your config plus the built-ins it leans on. `<leader>` is Space. ★ = your own
mapping (not a Vim/Neovim default).

## Move (7)

| Keys | Does |
|---|---|
| `w` `b` `e` / `W` `B` `E` | Word / WORD forward, back, end |
| `f` `t` `F` `T` then `;` `,` | To a character on any visible line (flash adds labels; after `d`/`c`/`y` + `f`/`t`, press `<CR>`) |
| `s` + 2–3 chars + label ★ | Flash jump anywhere on screen |
| `5j` / `12k` | Relative line jump (the numbers are in the gutter) |
| `{` `}` / `%` | Paragraph / matching bracket |
| `<C-d>` `<C-u>` ★ | Half page, cursor centred |
| `<C-o>` `<C-i>` ★ | Back / forward through the jump list, centred |

## Edit (9)

| Keys | Does |
|---|---|
| `ciw` `ci"` `ci(` `cit` | Change inside word / quotes / parens / tag |
| `cia` `vaf` `yac` | Argument / function / class (mini.ai + treesitter; `daa` is shadowed, see AUDIT) |
| `.` | Repeat the last change |
| `*` then `cgn`, then `.` `.` | Change this word, then each next match |
| `v` `an` `an` … `in` | Grow / shrink selection by syntax node (Neovim 0.12) |
| `<leader>d` ★ | Delete without touching your registers |
| `<A-j>` `<A-k>` ★ | Move line / selection down / up |
| `J` ★ | Join lines; the cursor stays put |
| `>` `<` in visual ★ | Indent; the selection stays, so press again |

## Surround and comment (4)

| Keys | Does |
|---|---|
| `gsaiw)` ★ | Wrap word in `()` (`(` adds spaces) |
| `gsd"` / `gsr'"` ★ | Delete / replace surrounding quotes |
| `gsaiwf` ★ | Wrap word in a function call (asks for the name) |
| `gcc` / `gc` + motion | Toggle comment |

## Repeat and bulk (4)

| Keys | Does |
|---|---|
| `qq` … `q`, then `@q`, `5@q`, `@@` | Record and replay a macro |
| `:%s/old/new/g` | Substitute (`inccommand` previews it) |
| `:g/pattern/d` / `:g/pattern/normal A;` | Act on every matching line |
| `<C-v>` … `I` / `A` | Block insert / append on many lines |

## Code (LSP) (8)

| Keys | Does |
|---|---|
| `grd` (`gd` in C#) | Go to definition, `<C-o>` back |
| `grr` | References |
| `gri` / `grt` | Implementations / type definition |
| `gO` / `gW` | Symbols in this file / in the workspace |
| `grn` | Rename (not in OmniSharp C#) |
| `gra` | Code action (not in OmniSharp C#) |
| `K` | Hover docs (not in OmniSharp C#) |
| `]d` `[d` / `<leader>q` | Next / previous diagnostic / all of them in the location list |

## Find (4)

| Keys | Does |
|---|---|
| `<leader><leader>` | Switch buffer |
| `<leader>/` | Fuzzy-find a line in this buffer |
| `<leader>sf` / `<leader>sg` | Find file / grep project (install ripgrep first) |
| `<leader>sk` / `<leader>sh` | Search your keymaps (`<CR>` runs one) / the help |

## Git (2)

| Keys | Does |
|---|---|
| `]c` `[c` / `ih` | Next / previous hunk, hunk text object (`dih`) |
| `<leader>hs` `hr` `hp` `hb` | Stage / reset / preview / blame the hunk or line |

## Windows and files (2)

| Keys | Does |
|---|---|
| `<leader>\|` `<leader>-` ★ then `<C-h/j/k/l>` | Split right / below, move between splits |
| `<C-^>` / `]q` `[q` ★ / `\` ★ | Alternate file / quickfix next-prev / reveal in neo-tree |
