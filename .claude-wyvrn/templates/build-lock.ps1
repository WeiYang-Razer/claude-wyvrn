# PreToolUse build lock for Bash / PowerShell tool calls, scoped to one project.
#
# Blocks a tool call (exit 2) while a process named in
# <project>/.claude-wyvrn-local/build-lock-processes is running AND that process
# belongs to this project. A cmake or ctest owned by a different repository no
# longer blocks this one. Concurrent build/test invocations inside a single
# project have hard-crashed development machines.
#
# Run with -Sweep to kill only this project's listed processes:
#     powershell -NoProfile -ExecutionPolicy Bypass -File build-lock.ps1 -Sweep
# Optionally -ProjectDir <path>. The sweep leaves other projects' runs alone.
#
# Wire the hook up with -File, never -Command. Claude Code passes the hook
# `command` string through a POSIX shell first, which strips PowerShell's `$var`,
# `$env:VAR` and `$_` before powershell.exe ever sees them; the result is a
# parse error, exit 1, and a lock that silently never blocks.
#
# Project dir is resolved in this order:
#   1. -ProjectDir (sweep mode only)
#   2. $env:CLAUDE_PROJECT_DIR
#   3. the "cwd" field of the hook's stdin JSON
#   4. the process working directory
# then the lock file is looked for in that directory and every parent up to and
# including the repository root (the first directory holding a .git entry), so a
# call made from a subdirectory of the worktree still finds it while an
# unrelated file further up the drive can never bind this project.
#
# OWNERSHIP. A running process counts as this project's when either holds:
#   (a) it descends from this Claude Code session (the nearest `node`/`claude`
#       ancestor of this hook process), which covers anything the session or its
#       subagents started; or
#   (b) the project root path appears in the command line of the process itself
#       or of any of its ancestors, which covers a second Claude session on the
#       same repo and a build launched by hand from a terminal.
# A process matching neither is foreign: logged, not blocked on, not swept.
# Ownership cannot always be decided - a toolchain invoked with only relative
# paths from a shell this session did not spawn reads as foreign. That is the
# cost of scoping; the global lock had no such blind spot.
#
# Process names are matched the way Get-Process matches them: no .exe suffix.
# `cmake` blocks; `cmake.exe` matches nothing and silently never blocks.
# Wildcards (`test_*`) are supported. Lines starting with # are comments.
#
# Once a lock file exists the hook fails CLOSED: any error reading the list,
# querying processes, or deciding ownership blocks the call rather than waving
# it through.
#
# Every invocation appends one line to ~/.claude/logs/build-lock.log.

param(
    [switch]$Sweep,
    [string]$ProjectDir
)

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

# The sweep is itself a Bash/PowerShell tool call, so it is blocked too whenever
# the live process is this project's. The way out from inside a blocked session
# is a terminal outside Claude Code.
function Get-Recovery([string]$ScriptPath, [string]$Root)
{
    return @(
        "Wait for it to finish, or sweep from a terminal OUTSIDE Claude Code (an",
        "in-session sweep is blocked by this same hook). This kills only this",
        "project's processes and leaves other repositories' runs alone:",
        "    powershell -NoProfile -ExecutionPolicy Bypass -File '$ScriptPath' -Sweep -ProjectDir '$Root'"
    )
}

# --- process table, ancestry, ownership --------------------------------------

function Get-ProcMap
{
    $Map = @{}
    foreach ($P in (Get-CimInstance Win32_Process -ErrorAction Stop))
    {
        $Map[[int]$P.ProcessId] = $P
    }
    return $Map
}

# Self first, then ancestors. CreationDate guards against a recycled parent PID
# pointing at a process that started after its supposed child.
function Get-Chain([int]$StartPid, $Map)
{
    $Chain = @()
    $Current = $Map[$StartPid]
    $Depth = 0
    while ($null -ne $Current -and $Depth -lt 32)
    {
        $Chain += $Current
        $ParentPid = 0
        if ($null -ne $Current.ParentProcessId) { $ParentPid = [int]$Current.ParentProcessId }
        if ($ParentPid -le 0) { break }
        $Parent = $Map[$ParentPid]
        if ($null -eq $Parent) { break }
        if ($null -ne $Parent.CreationDate -and $null -ne $Current.CreationDate -and
            $Parent.CreationDate -gt $Current.CreationDate) { break }
        $Current = $Parent
        $Depth++
    }
    return $Chain
}

# The Claude Code session driving this hook: nearest node/claude ancestor.
# 0 when the hook runs outside a session, in which case ownership falls back to
# the path test alone.
function Get-SessionAnchor($Map)
{
    $Chain = Get-Chain $PID $Map
    foreach ($P in $Chain)
    {
        if ([int]$P.ProcessId -eq $PID) { continue }
        $Name = [string]$P.Name
        if ($Name -match '^(node|claude)(\.exe)?$') { return [int]$P.ProcessId }
    }
    return 0
}

# Match the project root as a whole path segment, so C:\repo\main does not match
# a sibling worktree C:\repo\main-extra. Both slash spellings are checked because
# the Bash tool passes forward slashes and PowerShell passes backslashes.
function Get-RootPattern([string]$Root)
{
    $Trimmed = $Root.TrimEnd('\', '/')
    $Backslash = $Trimmed -replace '/', '\'
    $Forward = $Trimmed -replace '\\', '/'
    $Forms = @($Backslash, $Forward) | Select-Object -Unique
    $Alternatives = @()
    foreach ($F in $Forms) { $Alternatives += [regex]::Escape($F) }
    $Tail = '($|[\\/' + [char]34 + [char]39 + '\s])'
    return '(' + ($Alternatives -join '|') + ')' + $Tail
}

function Test-OwnedByProject($Proc, $Map, [int]$AnchorPid, [string]$RootPattern)
{
    $Chain = Get-Chain ([int]$Proc.ProcessId) $Map

    if ($AnchorPid -gt 0)
    {
        foreach ($P in $Chain)
        {
            if ([int]$P.ProcessId -eq $AnchorPid) { return 'session' }
        }
    }

    foreach ($P in $Chain)
    {
        $CommandLine = [string]$P.CommandLine
        if (-not $CommandLine) { continue }
        if ($CommandLine -match $RootPattern) { return 'path' }
    }

    return $null
}

# --- read the hook payload (JSON on stdin) -----------------------------------

$JsonCwd = $null
$ToolName = '?'

if (-not $Sweep)
{
    $Raw = ''
    try { $Raw = [Console]::In.ReadToEnd() } catch { }

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
}
else
{
    $ToolName = 'sweep'
}

# --- resolve the project directory -------------------------------------------

$Source = 'cwd'
$Dir = $null
if ($Sweep -and $ProjectDir) { $Dir = $ProjectDir; $Source = 'ProjectDir' }
if (-not $Dir -and $env:CLAUDE_PROJECT_DIR) { $Dir = $env:CLAUDE_PROJECT_DIR; $Source = 'CLAUDE_PROJECT_DIR' }
if (-not $Dir -and $JsonCwd) { $Dir = $JsonCwd; $Source = 'stdin.cwd' }
if (-not $Dir) { $Dir = (Get-Location).Path }

# --- find the lock file, walking up as far as the repository root ------------

$LockFile = $null
$ProjectRoot = $null
$Probe = $null
try { $Probe = Get-Item -LiteralPath $Dir -ErrorAction Stop } catch { }

while ($null -ne $Probe)
{
    $Candidate = Join-Path $Probe.FullName '.claude-wyvrn-local\build-lock-processes'
    if (Test-Path -LiteralPath $Candidate)
    {
        $LockFile = $Candidate
        $ProjectRoot = $Probe.FullName
        break
    }

    # .git is a directory in a normal clone and a file in a linked worktree.
    if (Test-Path -LiteralPath (Join-Path $Probe.FullName '.git')) { break }

    $Probe = $Probe.Parent
}

if (-not $LockFile)
{
    Write-Log "PASS  tool=$ToolName via=$Source dir=$Dir : no lock file found"
    if ($Sweep) { Write-Output "No build-lock-processes file under '$Dir'. Nothing to sweep." }
    exit 0
}

# --- check the named processes -----------------------------------------------
# The project opted in by creating the lock file, so from here on every failure
# path blocks. Waving a call through on an unreadable list is how a silently
# broken lock looks from the inside.

$Mine = @()
$Foreign = @()

try
{
    $Names = @(Get-Content -LiteralPath $LockFile -ErrorAction Stop | ForEach-Object { $_.Trim() } |
               Where-Object { $_ -and -not $_.StartsWith('#') })

    if ($Names.Count -eq 0)
    {
        Write-Log "PASS  tool=$ToolName via=$Source lock=$LockFile : lock file empty"
        if ($Sweep) { Write-Output "Lock list '$LockFile' is empty. Nothing to sweep." }
        exit 0
    }

    $Running = @(Get-Process -Name $Names -ErrorAction SilentlyContinue)

    if ($Running.Count -gt 0)
    {
        $Map = Get-ProcMap
        $AnchorPid = Get-SessionAnchor $Map
        $RootPattern = Get-RootPattern $ProjectRoot

        foreach ($P in $Running)
        {
            $Proc = $Map[[int]$P.Id]
            if ($null -eq $Proc) { continue }   # exited between the two queries
            $Why = Test-OwnedByProject $Proc $Map $AnchorPid $RootPattern
            if ($Why)
            {
                $Mine += [pscustomobject]@{ Id = [int]$P.Id; Name = [string]$P.Name; Why = $Why }
            }
            else
            {
                $Foreign += [pscustomobject]@{ Id = [int]$P.Id; Name = [string]$P.Name }
            }
        }
    }
}
catch
{
    $Reason = $_.Exception.Message
    Write-Log "BLOCK tool=$ToolName via=$Source lock=$LockFile : lock check failed: $Reason"
    if ($Sweep)
    {
        [Console]::Error.WriteLine("Sweep failed: $Reason")
        exit 1
    }
    [Console]::Error.WriteLine("BLOCKED: the build lock could not be evaluated, so the call is refused.")
    [Console]::Error.WriteLine("Reason: $Reason")
    [Console]::Error.WriteLine("Lock list: $LockFile")
    [Console]::Error.WriteLine("Repair or remove that file from a terminal outside Claude Code.")
    exit 2
}

$ForeignNote = ''
if ($Foreign.Count -gt 0)
{
    $ForeignNames = ($Foreign | Select-Object -ExpandProperty Name -Unique | Sort-Object) -join ', '
    $ForeignNote = " foreign=[$ForeignNames] ignored=$($Foreign.Count)"
}

# --- sweep mode ---------------------------------------------------------------

if ($Sweep)
{
    $ForeignList = ''
    if ($Foreign.Count -gt 0)
    {
        $ForeignList = ($Foreign | ForEach-Object { $_.Name + '(' + $_.Id + ')' }) -join ', '
    }

    if ($Mine.Count -eq 0)
    {
        Write-Log "SWEEP tool=sweep via=$Source lock=$LockFile root=$ProjectRoot killed=0$ForeignNote"
        Write-Output "Nothing of this project's to sweep."
        if ($ForeignList) { Write-Output "Left alone (other projects): $ForeignList" }
        exit 0
    }

    foreach ($M in $Mine)
    {
        try { Stop-Process -Id $M.Id -Force -ErrorAction Stop }
        catch { [Console]::Error.WriteLine("Could not kill $($M.Name) ($($M.Id)): $($_.Exception.Message)") }
    }

    $KilledList = ($Mine | ForEach-Object { $_.Name + '(' + $_.Id + ',' + $_.Why + ')' }) -join ', '
    Write-Log "SWEEP tool=sweep via=$Source lock=$LockFile root=$ProjectRoot killed=$($Mine.Count) [$KilledList]$ForeignNote"
    Write-Output "Swept $($Mine.Count) of this project's processes: $KilledList"
    if ($ForeignList) { Write-Output "Left alone (other projects): $ForeignList" }
    exit 0
}

# --- hook mode ----------------------------------------------------------------

if ($Mine.Count -eq 0)
{
    Write-Log "PASS  tool=$ToolName via=$Source lock=$LockFile patterns=$($Names.Count)$ForeignNote"
    exit 0
}

$Hits = ($Mine | Select-Object -ExpandProperty Name -Unique | Sort-Object) -join ', '
$Owned = ($Mine | Select-Object -ExpandProperty Why -Unique | Sort-Object) -join '+'
Write-Log "BLOCK tool=$ToolName via=$Source lock=$LockFile root=$ProjectRoot running=[$Hits] count=$($Mine.Count) owned=$Owned$ForeignNote"

[Console]::Error.WriteLine("BLOCKED: this project already has a build/test process running: $Hits ($($Mine.Count) processes).")
[Console]::Error.WriteLine("Only one toolchain invocation per project may be in flight at a time.")
[Console]::Error.WriteLine("Project: $ProjectRoot")
if ($Foreign.Count -gt 0)
{
    $OtherNames = ($Foreign | Select-Object -ExpandProperty Name -Unique | Sort-Object) -join ', '
    [Console]::Error.WriteLine("(Other projects are also running $OtherNames; those are not what blocked this call.)")
}
foreach ($Line in (Get-Recovery $PSCommandPath $ProjectRoot)) { [Console]::Error.WriteLine($Line) }
[Console]::Error.WriteLine("Lock list: $LockFile")
exit 2
