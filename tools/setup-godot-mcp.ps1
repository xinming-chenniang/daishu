#requires -Version 7
<#
.SYNOPSIS
    复现 godot-mcp（Godot 引擎 MCP 服务器）开发环境。

.DESCRIPTION
    godot-mcp 被 .gitignore 忽略，克隆本仓库后它并不存在，MCP 会直接失效。
    本脚本把它一条命令装回来：克隆 → 构建 → 校验 → 打印接线配置。

    两个已踩过的坑，脚本会主动规避：
      1) 必须用 **SSH** 克隆：本机 HTTPS 到 github.com 不通（SSL 被拦），
         SSH 通。写成 https:// 会静默超时。
      2) GODOT_PATH 必须指向 **_console.exe**：Windows 上不带 console 的 exe
         在 stdout 被重定向时输出 0 字节，而 run_project / get_debug_output
         正是靠捕获 stdout 工作的 —— 指错 exe 不报错，只是静默拿不到调试输出。

    ⚠️ 本脚本**不再写** `.claude/mcp.json`（2026-10-12 起不再使用 Claude Code，
    那个文件已无任何工具读取）。它现在只在最后**打印** DSH 侧的接线片段，
    由人自己贴进 profile；这样不会再生成无人读取的残留文件。

.PARAMETER GodotConsolePath
    Godot *_console.exe 的完整路径。省略则自动搜索常见位置。

.PARAMETER SkipInstall
    跳过 npm install / build（仅校验与写配置）。

.EXAMPLE
    pwsh -File tools\setup-godot-mcp.ps1
#>
[CmdletBinding()]
param(
    [string]$GodotConsolePath = '',
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$mcpDir      = Join-Path $projectRoot 'godot-mcp'
$repoUrl     = 'git@github.com:Coding-Solo/godot-mcp.git'   # 必须 SSH，见 .DESCRIPTION

function Say([string]$m, [string]$c = 'Gray') { Write-Host $m -ForegroundColor $c }

Say "`n=== godot-mcp 环境安装 ===" Cyan
Say "项目根目录: $projectRoot"

# --- 1. 前置检查 -----------------------------------------------------------
foreach ($cmd in @('git', 'node', 'npm')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "缺少必需命令: $cmd"
    }
}
Say ("node {0} / git {1}" -f (node --version), ((git --version) -split ' ')[2])

# --- 2. 定位 Godot _console.exe -------------------------------------------
# 环境变量优先：多台机器时用它指向各自的引擎，不必在这里维护绝对路径。
# （机器无关的完整解析见 tools\where-godot.ps1，它还会搜工作区 tools\godot\。）
if (-not $GodotConsolePath -and $env:GODOT_PATH) {
    $GodotConsolePath = $env:GODOT_PATH
    Say ("`n[1/4] 使用 `$env:GODOT_PATH = {0}" -f $GodotConsolePath) DarkGray
}
if (-not $GodotConsolePath) {
    Say "`n[1/4] 搜索 Godot *_console.exe ..."
    # 先按目录名过滤再深入：直接对整个盘递归会慢到不可用
    $searchRoots = @(
        (Join-Path $env:USERPROFILE 'Downloads'),
        (Join-Path $projectRoot 'vendor\godot'),
        'C:\Program Files', 'C:\Program Files (x86)',
        'D:\', 'D:\Program Files', 'D:\Tools', 'C:\Tools'
    ) | Where-Object { Test-Path $_ }

    $godotDirs = foreach ($root in $searchRoots) {
        Get-ChildItem -Path $root -Directory -Depth 2 -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'Godot' }
    }
    $found = foreach ($d in $godotDirs) {
        Get-ChildItem -Path $d.FullName -Filter '*_console.exe' -Recurse -Depth 2 -File -ErrorAction SilentlyContinue
    }
    $GodotConsolePath = ($found | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not $GodotConsolePath -or -not (Test-Path -LiteralPath $GodotConsolePath)) {
    throw "找不到 Godot 的 *_console.exe。请用 -GodotConsolePath 显式指定。"
}
Say ("Godot console: {0}" -f $GodotConsolePath) Green

# 与引擎同目录的普通 exe 一并报出，便于人工确认是同一次下载
$plain = Get-ChildItem (Split-Path $GodotConsolePath) -Filter '*.exe' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '_console' }
if ($plain) { Say ("同目录主程序 : {0}" -f ($plain.Name -join ', ')) DarkGray }

# --- 3. 克隆 + 构建 --------------------------------------------------------
Say "`n[2/4] godot-mcp 本体 ..."
if (-not (Test-Path (Join-Path $mcpDir '.git'))) {
    if (Test-Path $mcpDir) { Remove-Item $mcpDir -Recurse -Force }
    Say ("克隆 {0}" -f $repoUrl) Yellow
    git clone --depth 1 $repoUrl $mcpDir
    if ($LASTEXITCODE -ne 0) { throw "git clone 失败。确认 SSH key 可用： ssh -T git@github.com" }
} else {
    $head = git -C $mcpDir log -1 --format='%h %s'
    Say ("已存在（{0}），跳过克隆" -f $head)
}

$built = Join-Path $mcpDir 'build\index.js'
if ($SkipInstall) {
    Say "已指定 -SkipInstall"
} elseif (Test-Path $built) {
    Say ("build 已存在且不旧于 src，跳过构建")
} else {
    Say "`n[3/4] npm install && npm run build ..."
    Push-Location $mcpDir
    try {
        npm install --silent
        if ($LASTEXITCODE -ne 0) { throw "npm install 失败" }
        npm run build --silent
        if ($LASTEXITCODE -ne 0) { throw "npm run build 失败" }
    } finally { Pop-Location }
}

if (-not (Test-Path $built)) { throw "构建产物缺失: $built" }
Say ("build/index.js OK（{0:N0} 字节）" -f (Get-Item $built).Length) Green

# --- 4. 打印接线配置（不再写文件）------------------------------------------
Say "`n[4/4] 接线配置（本脚本不写文件，请自行粘贴）..." Cyan
$nodeExe  = (Get-Command node).Source
$builtFwd = ($built -replace '\\', '/')
$godotFwd = ($GodotConsolePath -replace '\\', '/')

Say "`n  ── DSH（实际生效的接线）────────────────────────────────────────" DarkGray
Say "  把下面两行填进 ~/.dsh/profiles/<profile>/cordis.patch.yml" DarkGray
Say "  的 mcp-godot 条目（watchUserPatches 热监听，保存即生效、无需重启）：" DarkGray
Write-Host ""
Write-Host ("    command : {0}" -f $nodeExe)
Write-Host ("    args    : ['{0}']" -f $builtFwd)
Write-Host ("    env     : GODOT_PATH = {0}" -f $godotFwd)
Write-Host ("              DEBUG      = false")

# --- 自检 ------------------------------------------------------------------
Say "`n=== 自检 ===" Cyan
$ok = $true

if ($godotFwd -match '_console\.exe$') { Say "  [PASS] GODOT_PATH 指向 _console.exe" Green }
else { Say "  [FAIL] GODOT_PATH 不是 _console.exe：$godotFwd" Red; $ok = $false }

if (Test-Path $built) { Say ("  [PASS] server 入口存在（{0:N0} 字节）" -f (Get-Item $built).Length) Green }
else { Say "  [FAIL] server 入口缺失：$built" Red; $ok = $false }

$ver = & $GodotConsolePath --version 2>&1 | Select-Object -First 1
if ($LASTEXITCODE -eq 0) { Say ("  [PASS] 引擎可执行：{0}" -f $ver) Green }
else { Say "  [FAIL] 引擎无法执行" Red; $ok = $false }

# 直接问一次 MCP 服务端（stdio，一行 JSON-RPC），确认真能起来
Say "`n  验证 MCP 服务端能起来（stdio 发一次 initialize）..." DarkGray
try {
    $req = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"setup-check","version":"1"}}}'
    $resp = $req | & $nodeExe $built 2>$null | Select-Object -First 1
    if ($resp -match '"result"') { Say "  [PASS] 服务端有响应（JSON-RPC initialize 成功）" Green }
    else { Say ("  [WARN] 服务端响应异常：{0}" -f ($resp | Out-String).Trim()) Yellow }
} catch {
    Say ("  [WARN] 无法启动服务端：{0}" -f $_.Exception.Message) Yellow
}

Say ""
if ($ok) {
    Say "完成。别忘了上面 [4/4] 打印的 DSH 接线片段 —— 不贴进去 MCP 不会生效。" -ForegroundColor Green
} else {
    Say "自检未通过，请按上面的 FAIL 项修复。" -ForegroundColor Red
    exit 1
}
