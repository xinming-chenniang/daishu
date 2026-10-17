#requires -Version 5.1
<#
.SYNOPSIS
    在本机运行 Godot：自动解析引擎路径，并把 user:// 重定向到可写目录。

.DESCRIPTION
    本机实测（2026-10-18）：Godot 在真实的 %APPDATA%\Godot 下**建不了目录**
    （日志里先是 `Could not create directory: 'user://logs'`），随后
    `CrashHandlerException: signal 11` —— 崩在项目加载之前，`--script` 一行输出都没有。
    这不是项目代码问题：把 `APPDATA` / `LOCALAPPDATA` 指到工作区里的可写目录后，
    同一命令立刻正常（导入、6 个场景截图、4 个验证脚本全过）。

    本脚本就封装这两步：
      1) 用 tools\where-godot.ps1 解析 *_console.exe（不写死路径）
      2) 把 APPDATA/LOCALAPPDATA 指向 <工作区>\.godot-userdata\{roaming,local}
    其余参数原样透传给引擎。

    副作用：`user://`（含 `save.dat`）落在 `.godot-userdata` 下，**与正常启动时的
    %APPDATA% 不是同一份存档**。要测"读已有存档"，把真实存档拷进对应目录再跑。

.PARAMETER EngineArgs
    传给 Godot 的参数，原样透传。未给 `--path` 时自动补成仓库根。

.EXAMPLE
    pwsh -File tools\run-godot.ps1 --headless --path . --script res://tools/verify_drop.gd

.EXAMPLE
    pwsh -File tools\run-godot.ps1 --path . --script res://tools/capture_scene.gd -- --scene title --out shot.png
#>
[CmdletBinding()]
param(
    # 启动编辑器 GUI（不是跑游戏）。双击 tools\open-editor.cmd 等价于这个。
    # 同样会做 APPDATA 重定向 —— 本机直接在真实 AppData 下启动编辑器/游戏会崩。
    [switch]$Editor,
    # 单字符串通道：参数里含 `--scene` / `--out` 这类**会被 PowerShell 当成自家参数名**的写法时用它。
    # 用单引号包住整行，内部按"引号外的空白"分词（路径含空格就用双引号括起来）。
    #   例：-ArgLine '--path . --script res://tools/capture_scene.gd -- --scene letter --out "C:\shots\a.png"'
    [string]$ArgLine,
    # 便捷通道：只含 `--headless` / `--path .` / `--script res://...` 等非歧义参数时可直接跟。
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$EngineArgs
)

# 引号感知分词（-File 调用时数组会被拍平成独立参数，所以只能收字符串再自己切）
function Split-ArgLine([string]$line) {
    $parts = New-Object System.Collections.Generic.List[string]
    $cur = New-Object System.Text.StringBuilder
    $inQuote = $false
    foreach ($ch in $line.ToCharArray()) {
        if ($ch -eq [char]'"') { $inQuote = -not $inQuote; continue }
        if ([char]::IsWhiteSpace($ch) -and -not $inQuote) {
            if ($cur.Length -gt 0) { $parts.Add($cur.ToString()); [void]$cur.Clear() }
            continue
        }
        [void]$cur.Append($ch)
    }
    if ($cur.Length -gt 0) { $parts.Add($cur.ToString()) }
    return $parts.ToArray()
}

if ($ArgLine) { $EngineArgs = Split-ArgLine $ArgLine }

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot'))) {
    throw "不是项目根（缺 project.godot）: $projectRoot"
}

# --- 1. 解析引擎 ----------------------------------------------------------
$resolver = Join-Path $PSScriptRoot 'where-godot.ps1'
if (-not (Test-Path -LiteralPath $resolver)) { throw "缺少 $resolver" }

$json = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $resolver -Json
if ($LASTEXITCODE -ne 0 -or -not $json) {
    throw "找不到 Godot。先跑 tools\where-godot.ps1 看安装提示（需要 *_console.exe）。"
}
$engine = ($json | ConvertFrom-Json).godot
if (-not $engine -or -not (Test-Path -LiteralPath $engine)) {
    throw "解析到的引擎路径无效: $engine"
}

# --- 2. 重定向 user:// 到可写目录 ----------------------------------------
# 仓库在工作区\repos\<名字> 时，上两级就是工作区；否则退到 TEMP。
$workspaceRoot = $null
$parent = Split-Path -Parent $projectRoot
if ((Split-Path -Leaf $parent) -ieq 'repos') { $workspaceRoot = Split-Path -Parent $parent }
$dataRoot = if ($workspaceRoot) { Join-Path $workspaceRoot '.godot-userdata' } else { Join-Path $env:TEMP 'dsh-godot-userdata' }

$env:APPDATA = Join-Path $dataRoot 'roaming'
$env:LOCALAPPDATA = Join-Path $dataRoot 'local'
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

# --- 3. 透传参数 ----------------------------------------------------------
if (-not $EngineArgs -or $EngineArgs.Count -eq 0) {
    $EngineArgs = @('--path', $projectRoot)
} elseif (-not ($EngineArgs -contains '--path')) {
    $EngineArgs = @('--path', $projectRoot) + $EngineArgs
}

Write-Host ("[run-godot] engine = {0}" -f $engine) -ForegroundColor DarkGray
Write-Host ("[run-godot] user:// = {0}" -f (Join-Path $env:APPDATA 'Godot\app_userdata')) -ForegroundColor DarkGray

# --- 4. -Editor：启动 GUI 编辑器（非 console 版，独立进程）-----------------
if ($Editor) {
    $editorExe = $engine -replace '_console\.exe$', '.exe'
    if (-not (Test-Path -LiteralPath $editorExe)) { $editorExe = $engine }
    $editorArgs = @('--path', $projectRoot, '--editor')
    if ($EngineArgs) { $editorArgs += $EngineArgs }
    Write-Host ("[run-godot] 启动编辑器：{0}" -f $editorExe) -ForegroundColor Green
    Start-Process -FilePath $editorExe -ArgumentList $editorArgs -WorkingDirectory $projectRoot
    exit 0
}

Push-Location $projectRoot
try {
    & $engine @EngineArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
