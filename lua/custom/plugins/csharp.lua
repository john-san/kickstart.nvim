-- OmniSharp's LSP mode does not advertise definitionProvider, so kickstart's grd silently
-- does nothing in C#. omnisharp-extended calls OmniSharp's own endpoints instead, and can
-- step into decompiled framework/NuGet sources. See docs/omnisharp-monorepo.md section 7.
vim.pack.add { 'https://github.com/Hoffs/omnisharp-extended-lsp.nvim' }

-- Created after kickstart's telescope LspAttach (init.lua SECTION 5), so these win in C# buffers.
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('custom-omnisharp-attach', { clear = true }),
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client or client.name ~= 'omnisharp' then return end

    local ext = require 'omnisharp_extended'
    local function map(lhs, fn, desc) vim.keymap.set('n', lhs, fn, { buffer = event.buf, desc = 'LSP: ' .. desc }) end
    map('grd', ext.telescope_lsp_definition, '[G]oto [D]efinition (OmniSharp)')
    map('gd', ext.telescope_lsp_definition, '[G]oto [D]efinition (OmniSharp)')
    map('grt', ext.telescope_lsp_type_definition, '[G]oto [T]ype Definition (OmniSharp)')
    map('grr', ext.telescope_lsp_references, '[G]oto [R]eferences (OmniSharp)')
    map('gri', ext.telescope_lsp_implementation, '[G]oto [I]mplementation (OmniSharp)')
  end,
})
