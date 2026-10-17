Add-Type -AssemblyName System.Drawing
$d = 'D:\个人项目\daishu'
$out = 'D:\dsh\tmp\hero\hero_composite.png'
$W = 1920; $H = 1080

$bmp = New-Object System.Drawing.Bitmap -ArgumentList @([int]$W, [int]$H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# 底：宣纸（避开 12 栏竖线最密处，取一块偏右上的区域）
$paper = [System.Drawing.Image]::FromFile("$d\assets\images\backgrounds\letter.png")
$g.DrawImage($paper, (New-Object System.Drawing.Rectangle 0,0,$W,$H),
             (New-Object System.Drawing.Rectangle 60,60,1500,844), [System.Drawing.GraphicsUnit]::Pixel)
$paper.Dispose()
$ov = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(58, 252, 228, 180))
$g.FillRectangle($ov, 0, 0, $W, $H); $ov.Dispose()

# 字体（项目题字同一支）
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile("$d\assets\fonts\hanchanlongcang.otf")
$fam = $pfc.Families[0].Name

# 标题：竖排「代书」
$fTitle = New-Object System.Drawing.Font($fam, 300, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$ink    = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(240, 26, 22, 18))
$g.DrawString('代', $fTitle, $ink, 150, 90)
$g.DrawString('书', $fTitle, $ink, 150, 390)

# 副标题（竖排在标题左侧）
$fSub = New-Object System.Drawing.Font($fam, 46, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$inkSoft = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215, 46, 38, 30))
$sy = 130
foreach ($ch in '明中期 · 代笔先生模拟器'.ToCharArray()) {
  if ($ch -eq ' ') { continue }
  $g.DrawString([string]$ch, $fSub, $inkSoft, 72, $sy); $sy += 52
}

# 定位语：用项目自己的原话（不是我自己编的文案）
$fTag = New-Object System.Drawing.Font($fam, 40, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$inkFaint = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(175, 70, 60, 48))
$g.DrawString('他们不识字，你说，他们写。', $fTag, $inkFaint, 152, 740)
$fTag2 = New-Object System.Drawing.Font($fam, 34, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$inkFaint2 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150, 80, 70, 56))
$g.DrawString('10 天攒够 500 文，进京赶考', $fTag2, $inkFaint2, 152, 800)

# 红印（中国风落款位；这里是设计元素，不是 AI 乱加的）
$seal = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(225, 168, 46, 38))
$g.FillRectangle($seal, 152, 880, 74, 74); $seal.Dispose()
$fSeal = New-Object System.Drawing.Font($fam, 52, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString('书', $fSeal, [System.Drawing.Brushes]::White, 159, 888)

# 主体：核心玩法截图 —— **用无水印版**
$shotPath = "$d\docs\screenshots\letter_nowm.png"
$shot = [System.Drawing.Image]::FromFile($shotPath)
$sw = 1040; $sh = [int]($sw * $shot.Height / $shot.Width)
$sx = $W - $sw - 90; $sy2 = $H - $sh - 90
$shadow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 60, 44, 28))
$g.FillRectangle($shadow, ($sx + 10), ($sy2 + 12), $sw, $sh); $shadow.Dispose()
$g.DrawImage($shot, $sx, $sy2, $sw, $sh)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(130, 40, 34, 26)), 3
$g.DrawRectangle($pen, $sx, $sy2, $sw, $sh); $pen.Dispose()
$shot.Dispose()

$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose(); $pfc.Dispose()
Write-Host ("已输出 {0}  {1}x{2}  {3:N0} KB" -f $out, $W, $H, ((Get-Item $out).Length / 1KB))
Write-Host ("截图来源: {0}" -f $shotPath)
