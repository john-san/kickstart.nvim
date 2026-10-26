# My Neovim config

A fork of [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) with additions
for C# (.NET Framework 4.8 + modern .NET), TypeScript/Angular and T-SQL on Windows.
The kickstart `README.md` is left untouched so upstream merges stay clean; this file
is the personal one.

## Where things live

| Path | What |
|---|---|
| `init.lua` | kickstart itself, edited in place: `git diff upstream/master -- init.lua` shows every choice made on top of it |
| `lua/custom/settings/` | options, keymaps, autocommands, user commands |
| `lua/custom/plugins/` | one file per plugin kickstart does not ship (loaded automatically) |
| `lua/custom/lsp/` | long language-server configs referenced from init.lua (OmniSharp, Angular) |
| `lua/custom/local.lua` | **gitignored** per-machine settings; start from `local.example.lua` |
| `after/ftplugin/` | SQL query keys, markdown prose settings |
| `nvim-pack-lock.json` | exact plugin revisions; commit it whenever it changes |
| `docs/omnisharp-monorepo.md` | what OmniSharp needs for a large mixed solution, and its gaps |

## Setting up a new machine

### Windows

```powershell
winget install --id Neovim.Neovim
winget install --id Git.Git
winget install --id BurntSushi.ripgrep.MSVC
winget install --id OpenJS.NodeJS.LTS
winget install --id tree-sitter.tree-sitter-cli   # treesitter parser builds...
winget install --id zig.zig                       # ...with zig as the C compiler
winget install --id DEVCOM.JetBrainsMonoNerdFont  # then select it in your terminal
dotnet tool install -g csharpier
npm install -g prettier

git clone https://github.com/john-san/kickstart.nvim.git "$env:LOCALAPPDATA\nvim"
```

### Linux / WSL

```sh
git clone https://github.com/john-san/kickstart.nvim.git ~/.config/nvim
```

Plus `git`, `rg`, `tree-sitter` (0.26.1+, from the package manager, not npm), a C compiler,
and Node.js.

### Then, on either

1. Configure git for this repo so commits use your personal identity, not a work one:
   `git config user.email <personal email>`.
2. Start `nvim`. `vim.pack` asks to install the plugins: answer **Always**. Mason then
   installs the language servers in the background (`:Mason` to watch), and treesitter
   compiles parsers (`:checkhealth nvim-treesitter` if highlighting is missing).
3. Optional: `copy lua\custom\local.example.lua lua\custom\local.lua` and add database
   connections. Passwords stay in environment variables.

## Day-to-day git

- **Updating plugins.** `<leader>lu` (`vim.pack.update()`) shows what would change;
  `:w` applies it. Then commit `nvim-pack-lock.json` on its own:
  `git commit -m "Update plugins" nvim-pack-lock.json`.
- **Bad update?** `git checkout HEAD -- nvim-pack-lock.json`, `:restart`, then
  `:lua vim.pack.update(nil, { offline = true, target = 'lockfile' })`.
- **Picking up changes on another machine.** `git pull`, `:restart` (new plugins
  install at the locked revision), then
  `:lua vim.pack.update(nil, { target = 'lockfile' })` to move existing plugins to it.
- **Trying something risky.** Do it on a branch (`git switch -c try-roslyn`); `master`
  stays a known-good config to fall back to.
- **Pulling kickstart's improvements.** `git fetch upstream`, read
  `git log HEAD..upstream/master`, then `git merge upstream/master`. Conflicts can only
  happen in the parts of `init.lua` changed here; `lua/custom/` never conflicts.
  Pushing to `upstream` is disabled on purpose.

## Keys added on top of kickstart

`<leader>sk` searches every keymap, so this is only a map of where things are.

| Keys | What |
|---|---|
| `s` / `S` | flash jump / select syntax node |
| `gsa` `gsd` `gsr` | surround add / delete / replace (moved from `s` for flash) |
| `vaf` `cif` `vac` | treesitter function / class objects |
| `]f` `[f` `]]` `[[` | next/prev function / class; `<leader>a`/`A` swap parameters |
| `<leader>e`, `\` | file tree toggle / reveal |
| `<leader>x…` | Trouble: diagnostics, symbols, TODOs |
| `<leader>D…` | database drawer; `<leader>Dr` runs the query/selection in a `.sql` buffer |
| `<leader>n…` | notes (only when `~/notes` exists) |
| `<leader>l…` | LSP restart/info, Mason, plugin updates |
| `<leader>tf` `tW` `ts` `tr` `tH` | toggle format-on-save, wrap, spell, relative numbers, hardtime |
| `<A-j>` / `<A-k>` | move line or selection |
| `<C-\>` | floating terminal (toggleterm) |
| `<leader>z` | zen mode |

## Known gaps

- **C#**: OmniSharp gives completion, references and implementations, but no hover,
  rename or code actions. Go-to-definition goes through omnisharp-extended. See
  `docs/omnisharp-monorepo.md` section 8 for roslyn.nvim, the alternative.
- **Debugging .NET Framework 4.8** stays in Visual Studio: the usual Neovim .NET
  debugger (netcoredbg) does not support it.
- **Parser compilation on Windows** uses zig through `scripts/zig-cc.cmd` when no MSVC
  is on PATH. The first build takes a few minutes while zig compiles its C runtime.
