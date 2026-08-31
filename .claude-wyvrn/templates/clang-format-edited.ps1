# PostToolUse formatter for Edit / Write tool calls.
#
# Runs clang-format -i over the C++ sources among $env:CLAUDE_FILE_PATHS and
# leaves every other file alone.
#
# Wire it up with -File, never -Command: Claude Code passes the hook `command`
# string through a POSIX shell first, which strips `$env:CLAUDE_FILE_PATHS` and
# `$_` before powershell.exe sees them, so the inline form silently formats
# nothing.
#
# Requires clang-format on PATH. If it is absent this exits 0 after one warning
# rather than failing every C++ edit.

$ErrorActionPreference = 'Stop'

$Paths = @($env:CLAUDE_FILE_PATHS -split ' ' | Where-Object { $_ -match '\.(cpp|cc|cxx|h|hpp|hxx)$' })
if ($Paths.Count -eq 0) { exit 0 }

if (-not (Get-Command clang-format -ErrorAction SilentlyContinue))
{
    [Console]::Error.WriteLine("clang-format not on PATH; skipped formatting $($Paths.Count) file(s).")
    exit 0
}

try { clang-format -i $Paths }
catch
{
    [Console]::Error.WriteLine("clang-format failed: $($_.Exception.Message)")
    exit 0
}
