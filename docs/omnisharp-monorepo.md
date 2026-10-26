# OmniSharp in a ~30-project mixed .NET Framework 4.8 + modern .NET solution

This is the part of the setup most likely to bite you. OmniSharp is not a
compiler — it is a host around MSBuild and Roslyn. Almost every "no
IntelliSense" or "type or namespace not found" problem in Neovim is really
MSBuild failing to evaluate a project, and OmniSharp reporting nothing about
it. What follows is what it actually needs.

## 1. MSBuild discovery is the whole ballgame

OmniSharp does not parse `.csproj` itself; it asks MSBuild to evaluate each
project and hand back the source files, references, defines and target
framework. So the MSBuild instance it picks determines what loads.

There are two flavours of the OmniSharp binary:

| Flavour | What it runs on | Can load .NET Framework 4.8 / non-SDK projects? |
|---|---|---|
| "modern net" build (`--useModernNet`, the mason default) | the .NET runtime | **Only if it can find desktop MSBuild** |
| Mono build | Mono | Yes, via Mono's MSBuild (worse fidelity on Windows) |

On **Windows specifically**, the modern build locates MSBuild from your
Visual Studio installation using `vswhere`. That desktop MSBuild is what can
evaluate old-style, non-SDK `.csproj` files — the `<Project ToolsVersion=...>`
format with explicit `<Compile Include=.../>` lists that 4.8 projects use.

**Practical requirement:** you need Visual Studio (any edition) *or* Build
Tools for Visual Studio installed, with the **".NET desktop build tools"**
workload and the **.NET Framework 4.8 targeting pack**. Without the targeting
pack, MSBuild evaluates the project but cannot resolve `mscorlib` /
`System.Web` etc., and you get a project that loads with thousands of
phantom errors.

This is why Mono is *not* needed on your machine, and why the config sets
`MsBuild.UseLegacySdkResolver: false`.

## 2. Point it at the solution, not a project

With 30 projects this matters enormously. OmniSharp picks a workspace root
and then decides what to load:

- Root contains **exactly one `.sln`** → it loads that solution. Cross-project
  go-to-definition, find-references and rename all work. **This is what you want.**
- Root contains **several `.sln`** files → OmniSharp picks one, effectively
  arbitrarily. Half your references resolve, half don't.
- Root contains **no `.sln`** → it globs for `.csproj` files and loads them
  individually. Each project is an island; navigation across projects breaks.

The `root_dir` function in `lua/custom/lsp/omnisharp.lua` walks upward from the file
you opened and stops at the directory containing a `.sln`/`.slnx`, so opening
`src/Foo.Web/Controllers/HomeController.cs` starts OmniSharp at the solution
root rather than at the project or the git root.

**If your monorepo has more than one `.sln`** (common at 30 projects — e.g. a
big `Everything.sln` plus per-area solutions), pick the one you want as
canonical and either:

- open Neovim from that directory, or
- drop an `omnisharp.json` next to the intended `.sln` (solution-level config
  beats the global one), or
- put a `.sln` filter (`.slnf`) in place and point at that instead — this is
  the best option if you only ever work in a subset of the 30 projects,
  because it cuts load time and memory dramatically.

## 3. Restore must have happened first

OmniSharp reads `obj/project.assets.json` (SDK-style) and
`packages.config` + `packages/` (old-style) to resolve NuGet references. It
does **not** reliably restore for you — and this config sets
`EnablePackageAutoRestore: false` deliberately, so an editor-triggered
restore never fights with a build you're running elsewhere.

Before expecting working IntelliSense in a fresh clone:

```powershell
# modern / SDK-style projects
dotnet restore Everything.sln

# old-style projects using packages.config need NuGet, not dotnet
nuget restore Everything.sln
# (or just build once in Visual Studio, which does both)
```

A project whose restore is missing loads with every external type unresolved.
That is the single most common cause of "OmniSharp is broken".

## 4. Pin the SDK with global.json

In a mixed solution, the .NET SDK that MSBuild runs under affects how the
modern projects evaluate. If your CI builds with a specific SDK, put a
`global.json` at the repo root so OmniSharp uses the same one:

```json
{
  "sdk": {
    "version": "8.0.400",
    "rollForward": "latestFeature"
  }
}
```

Without this, OmniSharp uses the newest SDK on the machine — you have 10.0.400
installed — which may evaluate projects differently than your build does.

## 5. Load-on-demand and analyzer cost

Two settings dominate responsiveness at this scale, both set in
`%USERPROFILE%\.omnisharp\omnisharp.json`:

- **`MsBuild.LoadProjectsOnDemand: true`** — projects are evaluated when you
  first touch a file in them rather than all 30 at startup. Startup goes from
  minutes to seconds. The tradeoff: a workspace-wide "find all references"
  only searches projects already loaded, so the first search after opening may
  under-report. Open a file from a project to force it in.
- **`RoslynExtensionsOptions.AnalyzeOpenDocumentsOnly: true`** — Roslyn
  analyzers run only for open files. With `EnableAnalyzersSupport: true` and
  30 projects, full-solution background analysis will comfortably use several
  GB of RAM and keep a core busy. If you want solution-wide analyzer
  diagnostics, flip this to `false` and expect the cost.

`DocumentAnalysisTimeoutMs` is raised from the 10s default to 30s, because the
first analysis pass on a large Framework project can exceed 10s and then
silently produce no diagnostics at all.

## 6. Expect a slow first load, and know how to watch it

On a cold start against 30 projects, OmniSharp can take 30–90 seconds before
diagnostics settle, even with load-on-demand. Useful things:

- The statusline shows attached clients, so you can see when `omnisharp` arrives.
- `:checkhealth vim.lsp` shows the attached client and its root dir — check the
  root dir is your solution directory.
- `:LspLog` (or `:lua vim.cmd('e '..vim.lsp.get_log_path())`) shows MSBuild's
  actual project-load output. Failures to load a project appear here and
  **nowhere else** — this is the first place to look.
- `<leader>lr` restarts the server when a `.csproj` change or a branch switch
  leaves the workspace stale. OmniSharp does not reliably pick up project file
  changes; restarting after editing a `.csproj` or switching branches is
  normal practice.

## 7. What OmniSharp's LSP mode actually implements

This was **measured on your machine**, not assumed — dumped from a live
OmniSharp v1.39.15 session against a loaded solution. OmniSharp in
`--languageserver` mode implements only part of LSP:

**Advertised and working:**

| Feature | Keymap |
|---|---|
| completion (incl. import completion) | `<C-Space>` / as you type |
| signature help | `<C-s>` |
| find references | `gr` |
| go to implementation | `gI` |
| go to type definition | `gy` |
| document symbols | `gO` |
| workspace symbols | `gW` |
| document highlight, code lens, folding, semantic tokens | automatic |
| on-type formatting | automatic |

**NOT advertised — these genuinely do not work in C# buffers:**

| Missing | Consequence | Mitigation in this config |
|---|---|---|
| `definitionProvider` | plain `gd` does nothing | `omnisharp-extended-lsp.nvim` routes `gd` through OmniSharp's own `o#/v2/gotodefinition` — **see the caveat below** |
| `hoverProvider` | `K` shows nothing | none available — use `<C-s>` signature help, or `gO` |
| `renameProvider` | `grn` does nothing | none — rename in Visual Studio |
| `codeActionProvider` | `gra` does nothing | none — no quick fixes / usings auto-add |
| `documentFormattingProvider` | LSP cannot format | irrelevant: CSharpier formats on save |

This is a property of omnisharp-roslyn, not of this config. TypeScript,
Angular, JSON, YAML and Lua all have the full feature set — verified:
angularls and vtsls both report `hoverProvider=true`, `definitionProvider=true`.

### Caveat on `gd` — verify this yourself

Be aware of exactly how far the verification went. Against a freshly created
test solution, in headless Neovim:

- OmniSharp attached at the **solution root** ✔
- completion returned 301 items including BCL types (`Action`,
  `AggregateException`), proving the project and framework references
  resolved ✔
- `omnisharp-extended-lsp` loaded and exposed the right functions ✔
- but a direct, correctly-formed `o#/v2/gotodefinition` request **never
  returned within 60 seconds** ✘

That last point could not be resolved here. It is plausibly an artifact of a
cold, headless server on a just-created solution rather than a real defect —
the same request returned an immediate (different) error when deliberately
malformed, so the endpoint is reachable. But it was not confirmed working.

**So: the first thing to check on your real solution** is whether `gd` on a
type actually jumps, once OmniSharp has fully warmed up (watch the statusline
for the `omnisharp` client, then give it a minute). If it does not:

1. `:LspLog` — look for project-load failures first.
2. Try `:lua require("omnisharp_extended").lsp_definition()` directly.
3. If it consistently hangs, that is a strong argument for moving to
   `roslyn.nvim` (section 8), since go-to-definition is not optional.

`gr` (references) and `gI` (implementation) are advertised by OmniSharp
natively, so those do not depend on this path.

**If rename and code actions matter to you more than non-SDK 4.8 project
support, switch C# to `roslyn.nvim` — see section 8.** That is the single
biggest quality-of-life decision in this setup, and it is genuinely a
tradeoff rather than a clear win, which is why this config ships what you
asked for and documents the alternative.

## 7b. Things that will still be worse than Visual Studio

Stated plainly so you're not surprised:

- **XAML / WinForms designers**: not supported at all.
- **ASP.NET Razor / `.cshtml`**: OmniSharp's Razor support is weak-to-absent
  in Neovim. Treesitter gives you highlighting; expect no real IntelliSense.
- **Source generators**: supported, but refresh lazily; a restart is sometimes
  needed after regenerating.
- **Find references across 30 projects** is slower than VS's cached index, and
  is affected by load-on-demand as described above.

## 8. The alternative worth knowing about

OmniSharp is in maintenance mode. Microsoft's current C# language server is
**Roslyn LSP** (`Microsoft.CodeAnalysis.LanguageServer`, the engine behind the
modern C# Dev Kit), wired into Neovim by
[`seblj/roslyn.nvim`](https://github.com/seblj/roslyn.nvim). It is markedly
faster on large solutions and has better modern-.NET support.

The reason this config uses OmniSharp as you asked, and not Roslyn LSP:
Roslyn LSP's support for **non-SDK-style .NET Framework projects is weaker**
than OmniSharp's — which is exactly the half of your solution that is hardest
to serve. If you later migrate the 4.8 projects to SDK-style `.csproj`
(possible while still targeting `net48`), switching to `roslyn.nvim` is the
upgrade worth making.
