# Config audit

Read-only audit of `C:\Users\dapha\AppData\Local\nvim` (Neovim 0.12.4, Windows 11), done before
building the drill course. The only change made to the config itself is one line in `init.lua`
(see README.md). Everything else lives in `lua/drill/`.

- **Plugin manager:** built-in `vim.pack` (`nvim-pack-lock.json`). `lazy-lock.json` is an untracked
  leftover from lazy.nvim and is not read by anything.
- **Leader / localleader:** `<Space>` / `<Space>`.
- **Structure:** kickstart-style `init.lua` in sections, plus `lua/custom/settings/*.lua` (options,
  keymaps, navigation, autocmds, commands), `lua/custom/plugins/*.lua` (one file per plugin) and
  `after/ftplugin/{markdown,sql}.lua`.

The **Drill** column names the drill that exercises each item (`d6.write` = Day 6, drill `write`).
`—` = covered only as a hint or in the cheat sheet; reasons for anything skipped are in the
"Skipped drills" section.

## Options worth knowing

| Option | Value | Effect on how you move |
|---|---|---|
| `number` + `relativenumber` | on | Relative counts (`5j`, `3k`) are always on screen. Day 1 leans on this. |
| `mouse` | `a` | Mouse works everywhere; drills penalise it. |
| `clipboard` | `unnamedplus` (scheduled) | Every yank/delete goes to the system clipboard. Drills set it to `''` for the session and restore it. |
| `ignorecase` + `smartcase` | on | `/foo` is case-insensitive, `/Foo` is not. Also affects `:s`. |
| `timeoutlen` | 300 | which-key pops up fast; multi-key maps must be typed quickly. |
| `scrolloff` / `sidescrolloff` | 10 / 8 | `H`/`L` stop 10 lines short of the edge. |
| `wrap` | off (markdown: on) | Long lines scroll sideways; `<leader>tW` toggles. |
| `splitright` / `splitbelow` | on | New splits open right / below. |
| `inccommand` | `split` | `:s` previews every change in a split. |
| `virtualedit` | `block` | Visual-block can extend past line ends (`<C-v>…$A`). |
| `expandtab`, `sw`/`ts`/`sts` | 2 (cs/sql/xml: 4) | Indents in drills follow this. |
| `undofile` / `noswapfile` | on / on | Undo survives restarts. |
| `foldlevel` | 99 | Folds start open. |
| `laststatus` | 3 | One global statusline. |
| `confirm` | on | `:q` on a modified buffer asks instead of failing. |

Autocmds: trim trailing whitespace on write (except markdown), restore last cursor position,
`q` closes help/qf/man/checkhealth, create missing directories on write, terminal buffers without
numbers, highlight on yank, centre the screen after a `/` or `?` search.
Commands: `:FormatDisable[!]`, `:FormatEnable`, `:FormatDotnet`.

## Keymaps

### Core editing (`lua/custom/settings/keymaps.lua`, kickstart)

| Mode | Keys | Does | Drill |
|---|---|---|---|
| n | `<Esc>` | `:nohlsearch` | d6.nohlsearch |
| n | `<leader>w` | `:write` | d6.write |
| n | `<leader>Q` | `:qall` | skipped (quits Neovim) |
| x | `<` / `>` | Outdent / indent, keep selection | d6.indent-keep |
| n, i, x | `<A-j>` / `<A-k>` | Move line / selection down / up, reindent | d6.move-line, d6.move-block |
| n, x | `<leader>d` | Delete into the black-hole register | d6.blackhole, d7.boss |
| n | `J` | Join lines, cursor stays (`mzJ\`z`) | d6.join |
| t | `<Esc><Esc>` | Leave terminal mode | d6.terminal |

### Navigation (`lua/custom/settings/navigation.lua`, kickstart)

| Mode | Keys | Does | Drill |
|---|---|---|---|
| n | `<C-h/j/k/l>` | Focus window left/down/up/right | d4.window-nav, d4.boss, d6.trouble-symbols |
| n | `<C-d>` / `<C-u>` / `<C-f>` / `<C-b>` | Scroll, then `zz` | d6.half-page |
| n | `G` / `gg` | Jump, then `zz` | d1.G |
| n | `n` `N` `*` `#` `g*` `g#` | Search, then `zz` (`zv` for n/N) | d1.star, d2.cgn, d7.rename-local |
| n | `<C-o>` / `<C-i>` | Jump list, then `zz` | d1.jumplist, d1.jumplist-forward |
| n | `]q` / `[q` | `:cnext` / `:cprevious`, then `zz` | d4.quickfix, d4.boss |

### Windows and splits (`keymaps.lua`)

| Mode | Keys | Does | Drill |
|---|---|---|---|
| n | `<leader>-` / `<leader>\|` | Split below / right | d6.splits |
| n | `<C-Up>` `<C-Down>` `<C-Left>` `<C-Right>` | Resize by 2 | d6.resize |

### Toggles (`keymaps.lua`, kickstart)

| Mode | Keys | Does | Drill |
|---|---|---|---|
| n | `<leader>tW` | Wrap | d6.toggles |
| n | `<leader>ts` | Spell | d6.toggles, d6.keymaps |
| n | `<leader>tr` | Relative numbers | d6.toggles |
| n | `<leader>tf` | Format on save | d6.format-toggle |
| n | `<leader>th` | Inlay hints (only when the server supports them) | d6.inlay-hints |
| n | `<leader>tb` | Inline git blame (gitsigns) | d6.git-toggles |
| n | `<leader>tw` | Git word diff (gitsigns) | d6.git-toggles |

### LSP and plugin management (`keymaps.lua`)

| Mode | Keys | Does | Drill |
|---|---|---|---|
| n | `<leader>f` | Format buffer (conform) | d6.format |
| n | `<leader>li` | `:checkhealth vim.lsp` | d6.lsp-info |
| n | `<leader>lr` | `:lsp restart` | skipped (restarts your real servers) |
| n | `<leader>lm` | `:Mason` | skipped (network, external state) |
| n | `<leader>lu` | `vim.pack.update()` | skipped (network, changes plugins) |

### LSP (kickstart `LspAttach`, Telescope versions, plus 0.12 defaults)

| Mode | Keys | Does | Drill |
|---|---|---|---|
| n | `grn` | Rename | d6.rename, d6.boss, d7.boss |
| n, x | `gra` | Code action | d6.code-action, d6.boss |
| n | `grr` | References (Telescope) | d6.references |
| n | `grd` | Definition (Telescope) | d6.definition |
| n | `grD` | Declaration | — (hint in d6.definition) |
| n | `gri` | Implementations (Telescope) | d6.implementation |
| n | `grt` | Type definition (Telescope) | d6.type-definition |
| n | `gO` | Document symbols (Telescope) | d6.document-symbols |
| n | `gW` | Workspace symbols (Telescope, dynamic) | d6.workspace-symbols |
| n | `K` | Hover | d6.hover |
| n | `]d` `[d` `]D` `[D` `<C-w>d` | Diagnostics (0.12 defaults) | d6.next-diagnostic |
| n | `<leader>q` | Diagnostics to the location list | d6.diagnostic-list |
| n | `gd` `grd` `grt` `grr` `gri` (C# only) | omnisharp-extended versions | — (fake server is not OmniSharp) |

### Telescope (kickstart, `keymaps.lua`)

| Mode | Keys | Does | Drill |
|---|---|---|---|
| n | `<leader><leader>` | Buffers | d5.telescope-buffers |
| n | `<leader>/` | Fuzzy search in this buffer | d5.telescope-lines |
| n | `<leader>sh` | Help tags | d5.telescope-help |
| n | `<leader>sk` | Keymaps (`<CR>` runs one) | d6.keymaps |
| n | `<leader>sG` / `<leader>sC` | Git status / commits | d6.git-status, d6.git-commits |
| n | `<leader>sf` | Find files | d6.find-files (**needs rg**) |
| n | `<leader>sg` | Live grep | d6.live-grep (**needs rg**) |
| n, v | `<leader>sw` | Grep word / selection | — (**needs rg**) |
| n | `<leader>s/` | Grep open files | — (**needs rg**) |
| n | `<leader>sn` | Find files in your config | — (**needs rg**) |
| n | `<leader>sd` `<leader>sr` `<leader>s.` `<leader>sc` `<leader>ss` | Diagnostics, resume, recent files, commands, pickers | — (cheat sheet) |

### Git (gitsigns, buffer-local in git files)

| Mode | Keys | Does | Drill |
|---|---|---|---|
| n | `]c` / `[c` | Next / previous hunk | d5.git-next-hunk |
| o, x | `ih` | Hunk text object | d5.git-hunk-object |
| n, v | `<leader>hs` / `<leader>hr` | Stage / reset hunk (or selection) | d6.git-stage-hunk, d6.git-reset-hunk |
| n | `<leader>hS` / `<leader>hR` | Stage / reset buffer | d6.git-stage-buffer, d6.git-reset-buffer |
| n | `<leader>hp` / `<leader>hi` | Preview hunk (float / inline) | d6.git-preview |
| n | `<leader>hb` | Blame line (full) | d6.git-blame |
| n | `<leader>hd` / `<leader>hD` | Diff vs index / last commit | d6.git-diff |
| n | `<leader>hq` / `<leader>hQ` | Hunks to quickfix (file / repo) | d6.git-qf |

### Motion and text-object plugins

| Mode | Keys | Plugin | Does | Drill |
|---|---|---|---|---|
| n, x, o | `s` | flash | Jump to any visible text | d5.flash-jump |
| n, x, o | `S` | flash | Select a treesitter node | d5.flash-treesitter |
| o | `r` | flash | Remote action (`yr<jump>iw`) | skipped (see below) |
| o, x | `R` | flash | Treesitter search | skipped (see below) |
| c | `<C-s>` | flash | Toggle flash labels in `/` | — |
| n, x, o | `f F t T ; ,` | flash (char mode) | Multi-line f/t with labels | d1.f, d1.f-repeat, d1.F, d2.dt, d2.semicolon-dot |
| n, x | `gsa` `gsd` `gsr` `gsf` `gsF` `gsh` `gsn` | mini.surround | Add / delete / replace / find / highlight surroundings | d5.surround-add, d5.surround-delete, d5.surround-replace, d5.surround-call, d7.wrap-await |
| o, x | `a` / `i` + `f` `c` `a` `(` `"` `q` `b` `t`… | mini.ai | Text objects; `f` = function and `c` = class via treesitter, `a` = argument | d2.*, d5.yank-function, d5.argument |
| o, x | `an` / `in` / `]n` / `[n` | 0.12 built-in | Grow / shrink treesitter selection | d5.incremental, d7.extract-variable |
| n, x, o | `]f` `[f` `]F` `[F` `]]` `[[` | treesitter-textobjects | Function start/end, class | d5.ts-jumps |
| n | `<leader>a` / `<leader>A` | treesitter-textobjects | Swap parameter with next / previous | d5.swap-params, d5.boss, d7.boss |
| n, x, o | `gc` / `gcc` | built-in | Comment | d5.comment |

### Panels and tools

| Mode | Keys | Plugin | Does | Drill |
|---|---|---|---|---|
| n | `\` | neo-tree | Reveal current file | d5.neo-tree |
| n | `<leader>e` | neo-tree | Toggle tree | d6.tree-toggle |
| n | `<leader>xx` / `<leader>xX` | trouble | Diagnostics (all / buffer) | d6.trouble-diagnostics |
| n | `<leader>xs` | trouble | Symbol outline | d6.trouble-symbols |
| n | `<leader>xq` | trouble | Quickfix list | d6.trouble-quickfix |
| n | `<leader>xl` | trouble | LSP refs/defs | — (hint) |
| n | `<leader>xt` | trouble | TODOs (todo-comments) | — (**needs rg**) |
| n, t | `<C-\>` | toggleterm | Floating terminal | d6.terminal |
| n | `<leader>z` | zen-mode | Zen mode | d6.zen |
| n | `<leader>Du` `Df` `Dn` `Dl` `Da` | dadbod-ui | DB drawer and buffers | skipped (needs a database) |
| n, x (sql) | `<leader>Dr` `Dw` `De` | dadbod-ui | Run query, save, bind params | skipped (needs a database) |
| n | `<leader>nf` `ng` `nn` `ni` `nd` `ny` `nb` `nt` `nl` `ns` | obsidian | Notes | skipped (vault `~/notes` does not exist, so the maps are never created) |

Plugins with no mappings of their own: blink.cmp (completion, default preset), nvim-autopairs,
LuaSnip + friendly-snippets, conform, nvim-lint, which-key, todo-comments, fidget, guess-indent,
indent-blankline, render-markdown, gen.nvim (Ollama; commands only), SchemaStore, mason.

Language servers configured: omnisharp, vtsls, angularls, html, cssls, jsonls, yamlls, lua_ls, and
stylua (see flags).

## Flags: conflicts, shadowed and unused mappings

1. **mini.ai `around_next = 'aa'` shadows "around argument".** `daa` / `caa` wait for another key
   instead of acting on the argument. `cia` / `dia` still work (d5.argument uses `cia`). Fix: set
   `mappings.around_next` to something else, such as `'an'`, though that is also 0.12's treesitter
   `an`. `'aN'` would be safe.
2. **flash char mode with `jump_labels = true`.** After `d`/`c`/`y` + `f`/`t`, flash waits for a
   label or `<CR>` (Esc cancels the whole operator), so `dt)` needs `dt)<CR>`. In normal mode the
   key *after* `f(` can be eaten as a label if it labels a match (only `hjkliardc` are excluded):
   `f(p` may jump instead of paste. The drills tell you where `<CR>` is needed.
3. **flash `s` / `S` replace Vim's `s` (substitute char) and `S` (substitute line).** Use `cl` and
   `cc`. Visual `R` (replace lines) is also gone.
4. **`gs` group shadows Vim's `gs`** (sleep). Harmless.
5. **`J` mapping overwrites mark `z`** on every join (`mzJ\`z`).
6. **`<C-i>` is mapped**, and in most terminals `<Tab>` and `<C-i>` are the same key, so Tab in
   normal mode also gets the `zz`. Harmless, but worth knowing if you ever map Tab.
7. **Case-only pairs that are easy to fat-finger:** `<leader>tw` (gitsigns word diff) vs
   `<leader>tW` (wrap); `<leader>q` (diagnostics list) vs `<leader>Q` (**quit all**). Consider moving
   `qall` to something longer.
8. **Stale comment:** `after/ftplugin/markdown.lua` says its `j`/`k` maps mirror "global maps in
   keymaps.lua". There are no global `j`/`k` maps any more.
9. **Unused files:** `lua/kickstart/plugins/debug.lua` and `lua/kickstart/plugins/neo-tree.lua` are
    never required. The DAP plugins (nvim-dap, nvim-dap-ui, nvim-dap-go, mason-nvim-dap, nvim-nio)
    and tokyonight are still on disk; **every start re-adds them to `nvim-pack-lock.json`** ("vim.pack:
    Repaired corrupted lock data…"). Running `:lua vim.pack.del { 'nvim-dap', … }` once, or
    deleting them from `site/pack/core/opt`, stops it. The drill tests restore the lockfile after
    every run.
10. **ripgrep is not installed.** `<leader>sf`, `<leader>sg`, `<leader>sw`, `<leader>s/`,
    `<leader>sn`, the notes grep and `<leader>xt` all depend on it. `winget install BurntSushi.ripgrep.MSVC`.
11. **stylua is enabled as a language server** (`servers.stylua = {}` in init.lua), but the
    mason-installed stylua is 2.0.2, which has no `--lsp` mode: every Lua buffer logs "Client
    stylua quit with exit code 2". Updating stylua in `:Mason` (`U` on the package) or dropping
    it from `servers` fixes it. Formatting via conform is unaffected.
12. **OmniSharp does not provide rename, code actions or hover** (your own note in
    `lua/custom/lsp/omnisharp.lua`). So in real C# buffers `grn`, `gra` and `K` do nothing. The Day 6
    drills teach them against a built-in fake server; in your work they apply to TypeScript/Angular
    (vtsls, angularls), Lua (lua_ls), JSON/YAML/HTML/CSS. `grd`/`grr`/`gri`/`grt`/`gd` work in C#
    through omnisharp-extended.
13. **`$SHELL` from Git Bash.** Started from Git Bash, Neovim takes `shell=/usr/bin/bash` but keeps
    cmd.exe's `shellcmdflag=/s /c`, so `:!`, `:terminal` and toggleterm fail. Not an issue when
    started from Windows Terminal or PowerShell.
14. **The treesitter `sql` parser compiles very slowly** (zig) on first install. It is installed now.
15. **gitsigns' cwd watcher can loop on Windows.** gitsigns watches `.git/HEAD` of the current
    directory and restarts the watcher on every event. On this machine, once it gets an event
    (always in a freshly created repo, and sometimes in this config repo during a session), it
    keeps re-firing and runs `git rev-parse` many times a second until Neovim exits: about 120 calls
    in a few seconds against 1 in 6 seconds when quiet. It is a gitsigns bug, not your config. It
    slows gitsigns' own attach, so the Day 6 git drills can take 4–10 s to load. The drill re-asks
    gitsigns to attach, keeps it from watching the drill repos, and lets you retry or skip while
    loading.

## Skipped drills

Drills whose requirements this config does not meet are skipped automatically and listed by
`:Drill list`. Right now:

| Drill | Why |
|---|---|
| d6.find-files | `rg` is not on PATH |
| d6.live-grep | `rg` is not on PATH |

They turn on by themselves once ripgrep is installed.

Not given a drill on purpose:

| Mapping | Why |
|---|---|
| `<leader>Q` | Quits Neovim, which would end the session. |
| `<leader>lu` | Runs `vim.pack.update()`: network access, and it changes your plugins. |
| `<leader>lr` | Restarts your real language servers. |
| `<leader>lm` | Opens Mason (network, external state). |
| `<leader>D*` (dadbod) | Needs a database connection; with none the UI is empty. |
| `<leader>n*` (obsidian) | The vault `~/notes` does not exist, so the mappings are never created. A drill would also create real notes. |
| flash `r` / `R` | Remote and treesitter-search pick their target by label at run time, so there is no fixed key sequence to check or replay. |
| `<leader>sw`, `<leader>s/`, `<leader>sn`, `<leader>xt` | Need rg (two rg drills already cover the pattern). |
| `<leader>sd` `sr` `s.` `sc` `ss`, `<leader>xX`, `<leader>xl`, `gsf` `gsF` `gsh` `gsn`, `grD`, `<leader>hi` `hD` `hQ` | Variants of a drilled mapping; named in that drill's hint and in the cheat sheet. |
| gen.nvim | No mappings; needs a running Ollama. |

Not replayable in the headless tests (but in the course):

| Drill | Why |
|---|---|
| d6.terminal | In a headless Neovim the shell exits at once, so toggleterm closes the float. It needs a real UI. |
