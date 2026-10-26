-- Angular language service: template completion and template <-> component navigation.
-- It loads the project's own @angular/language-service, so `npm install` must have run.

---@type vim.lsp.Config
return {
  -- nvim-lspconfig ships a root_dir *function* for angularls, and a function beats
  -- root_markers, so without this override it attaches to every plain TypeScript project.
  root_dir = function(bufnr, on_dir)
    local marker = vim.fs.find({ 'angular.json', 'nx.json' }, { upward = true, path = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)) })[1]
    if marker then on_dir(vim.fs.dirname(marker)) end
  end,

  filetypes = { 'html', 'htmlangular', 'typescript', 'typescriptreact' },

  on_attach = function(client)
    -- vtsls owns rename in .ts files; two servers renaming the same symbol conflicts.
    client.server_capabilities.renameProvider = false
  end,
}
