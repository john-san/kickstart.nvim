@echo off
setlocal
set "args=%*"
set "args=%args:-pc-windows-msvc=-windows-gnu%"
zig cc %args%
exit /b %errorlevel%
