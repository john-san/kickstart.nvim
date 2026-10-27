-- An in-process language server (vim.lsp.start with a Lua `cmd`), so the LSP drills run your
-- real LspAttach mappings (grn, gra, grr, grd, gri, grt, gO, K, <leader>th ...) against a server
-- that answers deterministically. It reads the buffer directly instead of tracking didChange.
local api = vim.api
local M = {}

local function is_word(c) return c ~= '' and c:match '[%w_]' ~= nil end

local function word_at(line, col)
  local s = col + 1
  if not is_word(line:sub(s, s)) then return end
  local a, b = s, s
  while a > 1 and is_word(line:sub(a - 1, a - 1)) do
    a = a - 1
  end
  while b < #line and is_word(line:sub(b + 1, b + 1)) do
    b = b + 1
  end
  return line:sub(a, b)
end

local function occurrences(lines, word)
  local out = {}
  for i, l in ipairs(lines) do
    local init = 1
    while true do
      local s, e = l:find(word, init, true)
      if not s then break end
      if not is_word(l:sub(s - 1, s - 1)) and not is_word(l:sub(e + 1, e + 1)) then table.insert(out, { row = i - 1, col = s - 1, len = #word }) end
      init = e + 1
    end
  end
  return out
end

local function range(o) return { start = { line = o.row, character = o.col }, ['end'] = { line = o.row, character = o.col + o.len } } end

-- Declaration shapes for the languages the drills use (C#, TypeScript, Lua).
local DECL = {
  '^%s*[%w%s]*class%s+W%f[^%w_]',
  '^%s*[%w%s]*interface%s+W%f[^%w_]',
  '^%s*[%w%s]*record%s+W%f[^%w_]',
  '^%s*[%w%s]*enum%s+W%f[^%w_]',
  'function%s+W%s*%(',
  '^%s*local%s+W%f[^%w_]',
  '^%s*[%w_]+%s+W%s*%(', -- `void Apply(` / `decimal Total(`
  '^%s*[%w%s<>%[%],?]-[%w_>%]?]%s+W%s*%(', -- `public async Task<Order> Load(`
  '^%s*[%w%s<>%[%],?]-[%w_>%]?]%s+W%s*[=;{]', -- fields and locals: `private readonly IClock _clock;`
  '^%s*[%w%s]*const%s+W%f[^%w_]',
  '^%s*[%w%s]*let%s+W%f[^%w_]',
  '^%s*W%s*%(.*%)%s*[:{]', -- TS method `total(items: Item[]): number {`
}

local function is_decl(line, word)
  local w = vim.pesc(word)
  for _, p in ipairs(DECL) do
    if line:find((p:gsub('W', w))) then return true end
  end
end

local function decls(lines, word)
  local out = {}
  for _, o in ipairs(occurrences(lines, word)) do
    if is_decl(lines[o.row + 1], word) then table.insert(out, o) end
  end
  return out
end

local function definition(lines, word) return decls(lines, word)[1] or occurrences(lines, word)[1] end

local KIND = { class = 5, method = 6, field = 8, interface = 11, ['function'] = 12, enum = 10 }

local function symbols(lines)
  local out = {}
  for i, l in ipairs(lines) do
    local kind, name = l:match '%f[%w](class)%s+([%w_]+)'
    if not name then
      kind, name = l:match '%f[%w](interface)%s+([%w_]+)'
    end
    if not name then
      kind, name = l:match '%f[%w](enum)%s+([%w_]+)'
    end
    if not name then
      name = l:match 'function%s+([%w_.:]+)%s*%('
      kind = name and 'function'
    end
    if not name and not l:match '^%s*return' and not l:match '^%s*if' and not l:match '^%s*new%s' then
      name = l:match '^%s*[%w%s<>%[%],?]-[%w_>%]?]%s+([%w_]+)%s*%(' or l:match '^%s*([%w_]+)%s*%(.*%)%s*[:{]'
      kind = name and 'method'
    end
    if name and not ({ ['if'] = 1, ['for'] = 1, ['while'] = 1, ['switch'] = 1, ['catch'] = 1, ['return'] = 1 })[name] then
      local col = l:find(name, 1, true) - 1
      table.insert(out, { name = name, kind = KIND[kind], row = i - 1, col = col, len = #name })
    end
  end
  return out
end

local function server(buf, spec, dispatchers)
  local closing = false
  local uri = vim.uri_from_bufnr(buf)
  local function lines() return api.nvim_buf_get_lines(buf, 0, -1, false) end
  local function loc(o) return { uri = uri, range = range(o) } end
  local function word_of(params)
    local p = params.position
    return word_at(lines()[p.line + 1] or '', p.character)
  end

  local function publish()
    if not spec.diagnostics then return end
    local diags = {}
    for _, d in ipairs(spec.diagnostics) do
      local row, col = require('drill.goal').pos(d, lines())
      local o = { row = row - 1, col = col, len = d.len or #(word_at(lines()[row], col) or ' ') }
      table.insert(diags, { range = range(o), message = d.message, severity = d.severity or 1, source = 'drill' })
    end
    dispatchers.notification('textDocument/publishDiagnostics', { uri = uri, diagnostics = diags })
  end

  local H = {}
  H['initialize'] = function()
    return {
      capabilities = {
        textDocumentSync = { openClose = true, change = 1 },
        renameProvider = true,
        codeActionProvider = true,
        referencesProvider = true,
        definitionProvider = true,
        declarationProvider = true,
        implementationProvider = true,
        typeDefinitionProvider = true,
        hoverProvider = true,
        documentSymbolProvider = true,
        workspaceSymbolProvider = true,
        inlayHintProvider = spec.inlay_hints and true or nil,
      },
      serverInfo = { name = 'drill-lsp' },
    }
  end
  H['shutdown'] = function() return vim.NIL end
  H['textDocument/rename'] = function(params)
    local word = word_of(params)
    if not word then return vim.NIL end
    local edits = {}
    for _, o in ipairs(occurrences(lines(), word)) do
      table.insert(edits, { range = range(o), newText = params.newName })
    end
    return { changes = { [uri] = edits } }
  end
  H['textDocument/references'] = function(params)
    local word = word_of(params)
    return word and vim.tbl_map(loc, occurrences(lines(), word)) or {}
  end
  H['textDocument/definition'] = function(params)
    local word = word_of(params)
    local o = word and definition(lines(), word)
    return o and loc(o) or {}
  end
  H['textDocument/declaration'] = H['textDocument/definition']
  H['textDocument/implementation'] = function(params)
    local word = word_of(params)
    if not word then return {} end
    local ls, out = lines(), {}
    -- Types implementing an interface (`class X : IFoo`), else later declarations of a member.
    for _, o in ipairs(occurrences(ls, word)) do
      local cls = ls[o.row + 1]:match('class%s+([%w_]+)[^{]*[:,]%s*[%w_.,%s]*%f[%w_]' .. vim.pesc(word) .. '%f[^%w_]')
      if cls then
        local s = ls[o.row + 1]:find(cls, 1, true)
        table.insert(out, loc { row = o.row, col = s - 1, len = #cls })
      end
    end
    if #out == 0 then
      out = vim.tbl_map(loc, vim.list_slice(decls(ls, word), 2))
    end
    return out
  end
  H['textDocument/typeDefinition'] = function(params)
    local word = word_of(params)
    if not word then return {} end
    local ls = lines()
    local ty = spec.types and spec.types[word]
    if not ty then
      for _, l in ipairs(ls) do
        ty = l:match('new%s+([%w_]+)') and l:match('%f[%w_]' .. vim.pesc(word) .. '%s*=') and l:match 'new%s+([%w_]+)'
          or l:match('([%w_]+)%??%s+' .. vim.pesc(word) .. '%f[^%w_]')
        if ty and ty ~= 'var' and ty ~= 'return' then break end
        ty = nil
      end
    end
    local o = ty and definition(ls, ty)
    return o and loc(o) or {}
  end
  H['textDocument/hover'] = function(params)
    local word = word_of(params)
    if not word then return vim.NIL end
    local text = spec.hover and spec.hover[word] or ('```\n' .. word .. '\n```')
    return { contents = { kind = 'markdown', value = text } }
  end
  H['textDocument/codeAction'] = function()
    local actions = {}
    for _, a in ipairs(spec.code_actions or {}) do
      local ls = lines()
      local new = a.apply(vim.deepcopy(ls))
      local edit = { range = { start = { line = 0, character = 0 }, ['end'] = { line = #ls, character = 0 } }, newText = table.concat(new, '\n') .. '\n' }
      table.insert(actions, { title = a.title, kind = a.kind or 'quickfix', edit = { changes = { [uri] = { edit } } } })
    end
    return actions
  end
  H['textDocument/documentSymbol'] = function()
    return vim.tbl_map(function(s) return { name = s.name, kind = s.kind, location = loc(s) } end, symbols(lines()))
  end
  H['workspace/symbol'] = function(params)
    local q = (params.query or ''):lower()
    local out = {}
    for _, s in ipairs(symbols(lines())) do
      if s.name:lower():find(q, 1, true) then table.insert(out, { name = s.name, kind = s.kind, location = loc(s) }) end
    end
    return out
  end
  H['textDocument/inlayHint'] = function()
    local out = {}
    for _, h in ipairs(spec.inlay_hints or {}) do
      local row, col = require('drill.goal').pos(h, lines())
      table.insert(out, { position = { line = row - 1, character = col }, label = h.label, paddingRight = true })
    end
    return out
  end

  local id = 0
  return {
    request = function(method, params, callback)
      id = id + 1
      local h = H[method]
      vim.schedule(function()
        if closing and method ~= 'shutdown' then return end
        local ok, result = pcall(h or function() return vim.NIL end, params)
        if ok then
          callback(nil, result)
        else
          callback({ code = -32603, message = tostring(result) }, nil)
        end
      end)
      return true, id
    end,
    notify = function(method)
      if method == 'textDocument/didOpen' then
        vim.schedule(publish)
      elseif method == 'exit' then
        closing = true
        vim.schedule(function() dispatchers.on_exit(0, 0) end)
      end
      return true
    end,
    is_closing = function() return closing end,
    terminate = function() closing = true end,
  }
end

--- Attach a fresh drill server to `buf`; returns the client id.
function M.start(buf, spec)
  return vim.lsp.start({
    name = 'drill-lsp',
    cmd = function(dispatchers) return server(buf, spec, dispatchers) end,
    root_dir = vim.fn.getcwd(),
  }, { bufnr = buf, reuse_client = function() return false end })
end

--- True once the server answered `initialize` and LspAttach mappings exist in `buf`.
function M.ready(buf)
  local c = vim.lsp.get_clients({ bufnr = buf, name = 'drill-lsp' })[1]
  if not (c and c.initialized) then return false end
  -- grn/grr also exist as global 0.12 defaults; the buffer-local copies mean LspAttach has run.
  for _, m in ipairs(api.nvim_buf_get_keymap(buf, 'n')) do
    if m.lhs == 'grr' then return true end
  end
  return false
end

function M.stop(id)
  local c = id and vim.lsp.get_client_by_id(id)
  if c then c:stop(true) end
end

M._symbols, M._occurrences, M._definition = symbols, occurrences, definition

return M
