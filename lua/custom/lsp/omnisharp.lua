-- OmniSharp for a large mixed .NET Framework 4.8 + modern .NET solution.
-- Background and troubleshooting: docs/omnisharp-monorepo.md.
--
-- Measured against OmniSharp v1.39.15 in --languageserver mode: it does NOT advertise hover,
-- definition, rename, code actions or formatting. Definition is routed through
-- omnisharp-extended-lsp (lua/custom/plugins/csharp.lua); CSharpier formats. Hover, rename
-- and code actions stay unavailable unless you switch to roslyn.nvim (doc section 8).

local exe = vim.fn.has 'win32' == 1 and 'OmniSharp.cmd' or 'OmniSharp'

---@type vim.lsp.Config
return {
  -- Mason's shim by full path: on Windows a bare `omnisharp` resolves unpredictably via PATHEXT.
  -- Behaviour is configured in ~/.omnisharp/omnisharp.json, OmniSharp's own mechanism.
  cmd = { vim.fs.joinpath(vim.fn.stdpath 'data', 'mason', 'bin', exe), '--languageserver', '--hostPID', tostring(vim.fn.getpid()) },

  -- Root on the .sln so the whole solution loads; a csproj root would load one project
  -- with no cross-project navigation.
  root_dir = function(bufnr, on_dir)
    -- Diffview's staged-file buffers (diffview://...) aren't on disk: the search below comes back
    -- as ".", which becomes a drive-root workspace that the LSP file watcher fails on (EPERM).
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname:match '^%w%w+://' then return end
    local dir = vim.fs.dirname(bufname)
    local sln = vim.fs.find(function(name) return name:match '%.slnx?$' end, { upward = true, path = dir })[1]
    if sln then return on_dir(vim.fs.dirname(sln)) end
    local proj = vim.fs.find(function(name) return name:match '%.csproj$' end, { upward = true, path = dir })[1]
    if proj then on_dir(vim.fs.dirname(proj)) end
  end,

  settings = {
    FormattingOptions = { EnableEditorConfigSupport = true, OrganizeImports = true },
    -- UseLegacySdkResolver=false lets OmniSharp use Visual Studio's MSBuild, which
    -- non-SDK-style 4.8 projects need.
    MsBuild = { UseLegacySdkResolver = false, LoadProjectsOnDemand = true },
    RoslynExtensionsOptions = {
      EnableAnalyzersSupport = true,
      EnableImportCompletion = true,
      EnableDecompilationSupport = true,
      AnalyzeOpenDocumentsOnly = true, -- full-solution analysis is too slow for ~30 projects
    },
    Sdk = { IncludePrereleases = false },
  },

  on_attach = function(client)
    -- OmniSharp's semantic-token modifiers contain spaces, which Neovim's highlighter rejects.
    local legend = client.server_capabilities.semanticTokensProvider and client.server_capabilities.semanticTokensProvider.legend
    if legend and legend.tokenModifiers then
      for i, v in ipairs(legend.tokenModifiers) do
        legend.tokenModifiers[i] = v:gsub(' ', '_')
      end
    end
  end,
}
