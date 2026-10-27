-- On-disk sandbox for drills that need real files (multi-file navigation, gitsigns, :write,
-- LSP pickers). Each drill attempt gets a fresh directory under stdpath('cache')/drill.
-- Real files use .cs/.sql/.txt: your OmniSharp only starts beside a .sln/.csproj and SQL has
-- no server, so none of your language servers attach to them.
local M = {}

local counter = 0

function M.root() return vim.fs.joinpath(vim.fn.stdpath 'cache', 'drill') end

--- Delete old workspaces. This Neovim's own are removed a few seconds later, so plugins still
--- finishing async work on their files (gitsigns attaching to a buffer) never see them vanish.
function M.clean()
  local root = M.root()
  if vim.fn.isdirectory(root) == 0 then return end
  local mine, later = ('ws%d-'):format(vim.fn.getpid()), {}
  for name in vim.fs.dir(root) do
    local path = vim.fs.joinpath(root, name)
    if vim.startswith(name, mine) then
      table.insert(later, path)
    else
      vim.fn.delete(path, 'rf')
    end
  end
  if #later > 0 then
    vim.defer_fn(function()
      for _, path in ipairs(later) do
        vim.fn.delete(path, 'rf')
      end
    end, 5000)
  end
end

--- Create a fresh directory holding `files` ({ [relpath] = text }); returns its path.
function M.create(files)
  counter = counter + 1
  local dir = vim.fs.joinpath(M.root(), ('ws%d-%d'):format(vim.fn.getpid(), counter))
  vim.fn.delete(dir, 'rf')
  vim.fn.mkdir(dir, 'p')
  for rel, text in pairs(files or {}) do
    M.write(dir, rel, text)
  end
  return dir
end

function M.write(dir, rel, text)
  local path = vim.fs.joinpath(dir, rel)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile(require('drill.goal').lines(text), path)
  -- With 'undofile' on, a stale undo file from an earlier attempt would let `u` walk back into it.
  os.remove(vim.fn.undofile(path))
  return path
end

local function git(dir, args)
  local cmd = { 'git', '-c', 'user.name=drill', '-c', 'user.email=drill@example.invalid', '-c', 'core.autocrlf=false', '-c', 'commit.gpgsign=false' }
  vim.list_extend(cmd, args)
  local r = vim.system(cmd, { cwd = dir, text = true }):wait()
  assert(r.code == 0, ('git %s failed: %s'):format(table.concat(args, ' '), r.stderr or ''))
end

--- Commit `base` ({ [relpath] = text }) as the repo's first commit.
function M.git_init(dir, base)
  git(dir, { 'init', '-q' })
  for rel, text in pairs(base) do
    M.write(dir, rel, text)
  end
  git(dir, { 'add', '-A' })
  git(dir, { 'commit', '-qm', 'drill base' })
end

return M
