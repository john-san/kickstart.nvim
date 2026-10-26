-- Format-on-save escape hatches; conform's format_on_save (init.lua SECTION 7) reads these flags.
vim.api.nvim_create_user_command('FormatDisable', function(args)
  if args.bang then
    vim.b.disable_autoformat = true
    vim.notify 'Format on save disabled for this buffer'
  else
    vim.g.disable_autoformat = true
    vim.notify 'Format on save disabled globally'
  end
end, { desc = 'Disable format on save (! for this buffer only)', bang = true })

vim.api.nvim_create_user_command('FormatEnable', function()
  vim.b.disable_autoformat = false
  vim.g.disable_autoformat = false
  vim.notify 'Format on save enabled'
end, { desc = 'Re-enable format on save' })

-- `dotnet format` honours .editorconfig and applies analyzer fixes, but it builds the
-- project and cannot read stdin, so it is a command rather than a format-on-save step.
vim.api.nvim_create_user_command('FormatDotnet', function()
  local file = vim.api.nvim_buf_get_name(0)
  local proj = vim.fs.find(function(name) return name:match '%.csproj$' or name:match '%.sln$' end, { upward = true, path = vim.fs.dirname(file) })[1]
  if not proj then
    vim.notify('No .csproj or .sln found above this file', vim.log.levels.ERROR)
    return
  end
  vim.notify('Running dotnet format on ' .. vim.fs.basename(proj) .. '...')
  vim.system(
    { 'dotnet', 'format', proj, '--include', file },
    { text = true },
    vim.schedule_wrap(function(res)
      if res.code == 0 then
        vim.cmd 'checktime'
        vim.notify 'dotnet format complete'
      else
        vim.notify('dotnet format failed:\n' .. (res.stderr or ''), vim.log.levels.ERROR)
      end
    end)
  )
end, { desc = 'Run dotnet format on the project containing this file' })
