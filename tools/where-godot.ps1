#requires -Version 5.1
<#
.SYNOPSIS
    解析本机的 Godot 可执行文件与项目根目录，打印可直接粘贴的 $godot / $proj。

.DESCRIPTION
    这个仓库在不同机器上的位置不同（家机在 D:\个人项目\daishu，另一台在工作区的
    repos\ 下），引擎位置也不同（家机 D:\Program Files\...，有的机器根本还没装）。
    因此**不要把路径抄进文档或脚本** —— 让本脚本去发现：

      1. -GodotPath 参数
      2. 环境变量 $env:GODOT_PATH
      3. PATH 里的 godot / godot4
      4. 工作区 `tools\godot\`（本机把便携版解压在这里，见 -DownloadHint）
      5. 仓库内 vendor\godot\ / godot\
      6. 常见安装位置（%USERPROFILE%\Downloads、C:\Program Files*、C:\Tools、
         D:\、D:\Program Files、%LOCALAPPDATA%\Programs）

    **只接受 `*_console.exe`**：Windows 上不带 console 的 exe 在 stdout 被重定向时
    输出 0 字节，会静默破坏截图/验证脚本与 godot-mcp 的 run_project（见 docs\AI_PLAYBOOK.md）。

    项目根 = 本脚本所在目录的**上一级**（tools\ 在仓库里），并校验同级有 project.godot。

.PARAMETER GodotPath
    Godot 可执行文件的完整路径。省略则自动搜索。

.PARAMETER ProjectRoot
    项目根目录。省略则用本脚本的上一级目录。

.PARAMETER Json
    输出 JSON（给其他脚本消费），而不是可粘贴的 PowerShell 片段。

.PARAMETER Quiet
    只输出变量行，不打印搜索过程与建议。

.EXAMPLE
    pwsh -File tools\where-godot.ps1

.EXAMPLE
    $g = (pwsh -File tools\where-godot.ps1 -Json | ConvertFrom-Json).godot
#>
[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [string]$ProjectRoot = '',
    [switch]$Json,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$explicit = $GodotPath
$envGodot = $env:GODOT_PATH

function Say([string]$m, [string]$c = 'Gray') {
    if (-not $Quiet) { Write-Host $m -ForegroundColor $c }
}

# --- 项目根 ---------------------------------------------------------------
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    throw "项目根不存在: $ProjectRoot"
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$projectFile = Join-Path $ProjectRoot 'project.godot'
if (-not (Test-Path -LiteralPath $projectFile)) {
    throw "这不是 Godot 项目根（缺 project.godot）: $ProjectRoot"
}

# 工作区根：仓库通常在工作区\repos\<名字>，于是上两级就是工作区
$workspaceRoot = ''
$parent = Split-Path -Parent $ProjectRoot
if ((Split-Path -Leaf $parent) -ieq 'repos') { $workspaceRoot = Split-Path -Parent $parent }

# --- 候选收集 -------------------------------------------------------------
$candidates = New-Object System.Collections.ArrayList
function Add-Candidate([string]$path, [string]$source) {
    if (-not $path) { return }
    if (-not (Test-Path -LiteralPath $path)) { return }
    $item = Get-Item -LiteralPath $path
    if ($item.PSIsContainer) { return }
    if ($item.Extension -ine '.exe') { return }
    foreach ($c in $candidates) { if ($c.Path -ieq $item.FullName) { return } }
    [void]$candidates.Add([pscustomobject]@{ Path = $item.FullName; Source = $source })
}

if ($explicit) { Add-Candidate $explicit '-GodotPath' }
if ($envGodot) { Add-Candidate $envGodot '$env:GODOT_PATH' }
foreach ($cmd in @('godot', 'godot4')) {
    $g = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($g -and $g.Source) { Add-Candidate $g.Source "PATH:$cmd" }
}

# 已知目录：直接找 *_console.exe（含一层子目录）
$knownDirs = @(
    (Join-Path $ProjectRoot 'vendor\godot'),
    (Join-Path $ProjectRoot 'godot'),
    $(if ($workspaceRoot) { Join-Path $workspaceRoot 'tools\godot' })
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

foreach ($d in $knownDirs) {
    Get-ChildItem -LiteralPath $d -Filter '*_console.exe' -Recurse -Depth 3 -File -ErrorAction SilentlyContinue |
        ForEach-Object { Add-Candidate $_.FullName "known:$d" }
    Get-ChildItem -LiteralPath $d -Filter 'Godot*.exe' -Recurse -Depth 1 -File -ErrorAction SilentlyContinue |
        ForEach-Object { Add-Candidate $_.FullName "known:$d" }
}

# 常见安装位置：先按目录名过滤再深入（对整盘递归会慢到不可用）
$searchRoots = @(
    (Join-Path $env:USERPROFILE 'Downloads'),
    (Join-Path $env:LOCALAPPDATA 'Programs'),
    'C:\Program Files',
    'C:\Program Files (x86)',
    'C:\Tools',
    'D:\',
    'D:\Program Files',
    'D:\Tools'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

foreach ($root in $searchRoots) {
    $dirs = Get-ChildItem -LiteralPath $root -Directory -Recurse -Depth 1 -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'Godot' }
    foreach ($d in $dirs) {
        Get-ChildItem -LiteralPath $d.FullName -Filter '*_console.exe' -Recurse -Depth 2 -File -ErrorAction SilentlyContinue |
            ForEach-Object { Add-Candidate $_.FullName "scan:$($d.FullName)" }
    }
    # 有些机器直接解压到根目录
    Get-ChildItem -LiteralPath $root -Filter 'Godot*_console.exe' -File -ErrorAction SilentlyContinue |
        ForEach-Object { Add-Candidate $_.FullName "scan:$root" }
}

# --- 选择：console 优先，其次最新 -----------------------------------------
$list = @($candidates)
$console = @($list | Where-Object { $_.Path -match '_console\.exe$' })
if ($console.Count -gt 0) {
    $chosen = $console | Sort-Object { (Get-Item -LiteralPath $_.Path).LastWriteTime } -Descending | Select-Object -First 1
} elseif ($list.Count -gt 0) {
    $chosen = $list | Sort-Object { (Get-Item -LiteralPath $_.Path).LastWriteTime } -Descending | Select-Object -First 1
} else {
    $chosen = $null
}

if ($chosen -eq $null) {
    $msg = @(
        '找不到 Godot 可执行文件。'
        '  装法（便携版，不必进 PATH，也不必放进仓库）：'
        '    1) 下载 https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable/Godot_v4.6.1-stable_mono_win64.zip'
        '    2) 解压到 <工作区>\tools\godot\ 或任意目录'
        '    3) 重新运行本脚本；或显式指定：-GodotPath "<...>\_console.exe"'
        '  注意必须用 *_console.exe。'
    ) -join [Environment]::NewLine
    Say $msg 'Red'
    if ($Json) { '{"godot":null,"project_root":"' + ($ProjectRoot -replace '\\', '\\') + '"}' }
    exit 1
}

# --- 版本探测 -------------------------------------------------------------
$version = ''
try {
    $version = (& $chosen.Path --version 2>&1 | Select-Object -First 1)
    if ($version) { $version = ([string]$version).Trim() }
} catch {
    Say "警告：无法执行 $($chosen.Path) --version：$($_.Exception.Message)" 'Yellow'
}

$isConsole = $chosen.Path -match '_console\.exe$'
if (-not $isConsole) {
    Say '警告：选中的不是 *_console.exe —— stdout 重定向时可能拿不到输出（截图/验证/MCP 会静默失效）。' 'Yellow'
}

# --- 输出 -----------------------------------------------------------------
if ($Json) {
    [pscustomobject]@{
        godot        = $chosen.Path
        project_root = $ProjectRoot
        version      = $version
        source       = $chosen.Source
        is_console   = $isConsole
    } | ConvertTo-Json -Compress
    exit 0
}

if (-not $Quiet) {
    Say ''
    Say ("Godot   : {0}" -f $chosen.Path) 'Green'
    Say ("版本    : {0}" -f $(if ($version) { $version } else { '(未知)' }))
    Say ("来源    : {0}" -f $chosen.Source) 'DarkGray'
    Say ("项目根  : {0}" -f $ProjectRoot) 'Green'
    Say ''
    Say '可粘贴：' 'DarkGray'
}
Write-Output ("`$godot = '{0}'" -f $chosen.Path)
Write-Output ("`$proj  = '{0}'" -f $ProjectRoot)
if (-not $Quiet) {
    Say ''
    Say '然后（在仓库根执行）：' 'DarkGray'
    Say '  & $godot --path .                             # 跑游戏' 'DarkGray'
    Say '  & $godot --headless --path . --import         # 改动资源后导入' 'DarkGray'
    Say '  & $godot --headless --path . --script res://tools/verify_drop.gd' 'DarkGray'
}
exit 0
