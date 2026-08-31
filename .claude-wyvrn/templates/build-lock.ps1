# PreToolUse build lock for Bash / PowerShell tool calls.
#
# Blocks a tool call (exit 2) while any process named in
# <project>/.claude-wyvrn-local/build-lock-processes is running. Concurrent
# build/test invocations have hard-crashed development machines.
#
# Wire it up with -File, never -Command. Claude Code passes the hook `command`
# string through a POSIX shell first, which strips PowerShell's `$var`,
# `$env:VAR` and `$_` before powershell.exe ever sees them; the result is a
# parse error, exit 1, and a lock that silently never blocks.
#
# Project dir is resolved in this order:
#   1. $env:CLAUDE_PROJECT_DIR
#   2. the "cwd" field of the hook's stdin JSON
#   3. the process working directory
# then the lock file is looked for in that directory and every parent up to and
# including the repository root (the first directory holding a .git entry), so a
# call made from a subdirectory of the worktree still finds it while an
# unrelated file further up the drive can never bind this project.
#
# Process names are matched the way Get-Process matches them: no .exe suffix.
# `cmake` blocks; `cmake.exe` matches nothing and silently never blocks.
# Wildcards (`test_*`) are supported. Lines starting with # are comments.
#
# Once a lock file exists the hook fails CLOSED: any error reading the list or
# querying processes blocks the call rather than waving it through.
#
# Every invocation appends one line to ~/.claude/logs/build-lock.log.

$ErrorActionPreference = 'Stop'

$LogDir = Join-Path $env:USERPROFILE '.claude\logs'
$LogFile = Join-Path $LogDir 'build-lock.log'

function Write-Log([string]$Message)
{
    try
    {
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        $Stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
        Add-Content -Path $LogFile -Value "$Stamp $Message" -Encoding utf8
    }
    catch { }
}

# The sweep itself is a Bash/PowerShell tool call, so it is blocked too. The
# only way out from inside a blocked session is a terminal outside Claude Code.
function Get-Recovery([string]$Lock)
{
    return @(
        "Wait for it to finish, or sweep from a terminal OUTSIDE Claude Code (an",
        "in-session sweep is blocked by this same hook):",
        "    Get-Content '$Lock' | Where-Object { `$_ -and -not `$_.StartsWith('#') } |",
        "        ForEach-Object { Get-Process -Name `$_ -ErrorAction SilentlyContinue } | Stop-Process -Force"
    )
}

# --- read the hook payload (JSON on stdin) -----------------------------------

$Raw = ''
try { $Raw = [Console]::In.ReadToEnd() } catch { }

$JsonCwd = $null
$ToolName = '?'
if ($Raw -and $Raw.Trim())
{
    try
    {
        $Payload = $Raw | ConvertFrom-Json
        if ($Payload.cwd) { $JsonCwd = [string]$Payload.cwd }
        if ($Payload.tool_name) { $ToolName = [string]$Payload.tool_name }
    }
    catch { }
}

# --- resolve the project directory -------------------------------------------

$Source = 'cwd'
$Dir = $env:CLAUDE_PROJECT_DIR
if ($Dir) { $Source = 'CLAUDE_PROJECT_DIR' }
if (-not $Dir -and $JsonCwd) { $Dir = $JsonCwd; $Source = 'stdin.cwd' }
if (-not $Dir) { $Dir = (Get-Location).Path }

# --- find the lock file, walking up as far as the repository root ------------

$LockFile = $null
$Probe = $null
try { $Probe = Get-Item -LiteralPath $Dir -ErrorAction Stop } catch { }

while ($null -ne $Probe)
{
    $Candidate = Join-Path $Probe.FullName '.claude-wyvrn-local\build-lock-processes'
    if (Test-Path -LiteralPath $Candidate) { $LockFile = $Candidate; break }

    # .git is a directory in a normal clone and a file in a linked worktree.
    if (Test-Path -LiteralPath (Join-Path $Probe.FullName '.git')) { break }

    $Probe = $Probe.Parent
}

if (-not $LockFile)
{
    Write-Log "PASS  tool=$ToolName via=$Source dir=$Dir : no lock file found"
    exit 0
}

# --- check the named processes -----------------------------------------------
# The project opted in by creating the lock file, so from here on every failure
# path blocks. Waving a call through on an unreadable list is how a silently
# broken lock looks from the inside.

try
{
    $Names = @(Get-Content -LiteralPath $LockFile -ErrorAction Stop | ForEach-Object { $_.Trim() } |
               Where-Object { $_ -and -not $_.StartsWith('#') })

    if ($Names.Count -eq 0)
    {
        Write-Log "PASS  tool=$ToolName via=$Source lock=$LockFile : lock file empty"
        exit 0
    }

    $Running = @(Get-Process -Name $Names -ErrorAction SilentlyContinue)
}
catch
{
    $Reason = $_.Exception.Message
    Write-Log "BLOCK tool=$ToolName via=$Source lock=$LockFile : lock check failed: $Reason"
    [Console]::Error.WriteLine("BLOCKED: the build lock could not be evaluated, so the call is refused.")
    [Console]::Error.WriteLine("Reason: $Reason")
    [Console]::Error.WriteLine("Lock list: $LockFile")
    [Console]::Error.WriteLine("Repair or remove that file from a terminal outside Claude Code.")
    exit 2
}

if ($Running.Count -eq 0)
{
    Write-Log "PASS  tool=$ToolName via=$Source lock=$LockFile patterns=$($Names.Count)"
    exit 0
}

$Hits = ($Running | Select-Object -ExpandProperty Name -Unique | Sort-Object) -join ', '
Write-Log "BLOCK tool=$ToolName via=$Source lock=$LockFile running=[$Hits] count=$($Running.Count)"

[Console]::Error.WriteLine("BLOCKED: build/test process already running: $Hits ($($Running.Count) processes).")
[Console]::Error.WriteLine("Only one toolchain invocation may be in flight at a time.")
foreach ($Line in (Get-Recovery $LockFile)) { [Console]::Error.WriteLine($Line) }
[Console]::Error.WriteLine("Lock list: $LockFile")
exit 2
