# 一键跑全部回归脚本（tools/verify_*.gd）。
#
# 为什么需要：
#   · 现在有 11 个 verify_*.gd，逐个敲命令既慢又容易漏；
#   · GDScript 报错后**不会**走到 quit()，命令行表现为"挂住"而不是失败
#     （2026-10-18 实测踩过：queue_free 后跨帧访问已释放实例）；
#     所以每个脚本必须带超时，超时就判失败，而不是无限等。
#
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify-all.ps1
#   ... -Filter "verify_*layout*.gd"        # 只跑匹配的
#   ... -TimeoutSec 180                     # 单个脚本超时（默认 120 s）
#
# 退出码：全部 PASS → 0；有 FAIL/TIMEOUT → 1。
[CmdletBinding()]
param(
    [string]$Filter = "verify_*.gd",
    [int]$TimeoutSec = 120
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot'))) {
    throw "不是项目根（缺 project.godot）: $projectRoot"
}
$runner = Join-Path $PSScriptRoot 'run-godot.ps1'
if (-not (Test-Path -LiteralPath $runner)) { throw "缺少 $runner" }

$scripts = Get-ChildItem -LiteralPath $PSScriptRoot -Filter $Filter -File |
    Where-Object { $_.Extension -eq '.gd' } | Sort-Object Name
if (-not $scripts) {
    Write-Host "[verify-all] 没有匹配 $Filter 的脚本" -ForegroundColor Yellow
    exit 1
}

$rows = New-Object System.Collections.Generic.List[object]
$failed = 0

foreach ($s in $scripts) {
    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()
    $argList = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $runner),
        '--headless', '--script', ('res://tools/{0}' -f $s.Name)
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList `
        -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr `
        -PassThru -WindowStyle Hidden
    $exited = $proc.WaitForExit($TimeoutSec * 1000)
    $sw.Stop()

    $status = 'UNKNOWN'
    $detail = ''
    if (-not $exited) {
        # 超时：连同子进程（godot）一起清理
        & taskkill.exe /PID $proc.Id /T /F 2>$null | Out-Null
        $status = 'TIMEOUT'
        $detail = "超过 ${TimeoutSec}s 未退出（多半是 GDScript 报错后没走到 quit()）"
    } else {
        $text = ''
        if (Test-Path -LiteralPath $tmpOut) { $text += (Get-Content -LiteralPath $tmpOut -Raw -Encoding UTF8) }
        if (Test-Path -LiteralPath $tmpErr) { $text += (Get-Content -LiteralPath $tmpErr -Raw -Encoding UTF8) }
        if ($text -match '结论:\s*PASS' -or $text -match '总体:\s*PASS') {
            $status = 'PASS'
        } elseif ($text -match '结论:\s*FAIL' -or $text -match '总体:\s*FAIL' -or $text -match '\[FAIL\]') {
            $status = 'FAIL'
            $detail = (($text -split "`r?`n") | Where-Object { $_ -match '\[FAIL\]|\[!\]' } | Select-Object -First 3) -join ' / '
        } else {
            $status = if ($proc.ExitCode -eq 0) { 'PASS?' } else { 'FAIL' }
            $detail = "无 PASS/FAIL 标记，exit=$($proc.ExitCode)"
        }
    }

    Remove-Item -LiteralPath $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue
    if ($status -ne 'PASS' -and $status -ne 'PASS?') { $failed++ }
    $rows.Add([pscustomobject]@{
        Script  = $s.Name
        Status  = $status
        Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        Detail  = $detail
    })
}

Write-Host ''
Write-Host ("{0,-28} {1,-9} {2,7}  {3}" -f '脚本', '结果', '耗时(s)', '备注') -ForegroundColor DarkGray
Write-Host ('-' * 78) -ForegroundColor DarkGray
foreach ($r in $rows) {
    $color = switch ($r.Status) {
        'PASS' { 'Green' }
        'PASS?' { 'Yellow' }
        default { 'Red' }
    }
    Write-Host ("{0,-28} {1,-9} {2,7}  {3}" -f $r.Script, $r.Status, $r.Seconds, $r.Detail) -ForegroundColor $color
}
Write-Host ('-' * 78) -ForegroundColor DarkGray
$pass = ($rows | Where-Object { $_.Status -eq 'PASS' -or $_.Status -eq 'PASS?' }).Count
Write-Host ("[verify-all] {0}/{1} 通过，{2} 个失败/超时" -f $pass, $rows.Count, $failed) -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })

exit $(if ($failed -eq 0) { 0 } else { 1 })
