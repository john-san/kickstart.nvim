-- Copy to lua/custom/local.lua (gitignored) for settings that belong to one machine only.
-- Every field is optional, and a missing local.lua is fine.
return {
  -- vim-dadbod connections for the <leader>Du drawer. Never put a password here: write
  -- {pw} in the url and name the environment variable that holds it. The password is
  -- URL-encoded on the way in, and the entry is skipped while the variable is unset.
  dbs = {
    -- { name = 'local-dev', url = 'sqlserver://sa:{pw}@localhost:1433/MyDatabase', password_env = 'DB_SA_PW' },
  },
}
