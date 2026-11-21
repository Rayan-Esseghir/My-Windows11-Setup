param(
    [ValidateSet("lavender", "teal", "sapphire", "mauve", "rosewater", "text")]
    [string]$Color = "lavender",
    [ValidateRange(1, 10)]
    [int]$Density = 4,
    [ValidateRange(20, 150)]
    [int]$Speed = 55,
    [switch]$NoSnow,
    [switch]$NoFlash
)

$esc      = [char]27
$cHead    = [char]0x2502
$cBright  = [char]0x2503
$cMid     = [char]0x2506
$cTail    = [char]'.'
$cSplash  = [char]'~'
$snowChars = @([char]'*', [char]0x2022, [char]0x00B7, [char]0x00B7)

$softOrder = @("lavender", "teal", "sapphire", "mauve", "rosewater", "text")
$headRgb = @{
    "lavender"  = "$esc[38;2;180;190;254m"
    "teal"      = "$esc[38;2;148;226;213m"
    "sapphire"  = "$esc[38;2;116;199;236m"
    "mauve"     = "$esc[38;2;203;166;247m"
    "rosewater" = "$esc[38;2;245;224;220m"
    "text"      = "$esc[38;2;205;214;244m"
}
$midTone    = "$esc[38;2;147;153;178m"
$tailTone   = "$esc[38;2;88;91;112m"
$splashRgb  = "$esc[38;2;127;132;156m"
$brightRgb  = "$esc[38;2;205;214;244m"
$snowHiRgb  = "$esc[38;2;245;224;220m"
$snowLoRgb  = "$esc[38;2;166;173;200m"
$reset      = "$esc[0m"

$colorIdx     = [Array]::IndexOf($softOrder, $Color)
$showSnow     = -not $NoSnow
$allowFlash   = -not $NoFlash
$flashFrames  = 0
$rng          = New-Object System.Random
$drops        = New-Object System.Collections.Generic.List[object]
$flakes       = New-Object System.Collections.Generic.List[object]
$splashes     = New-Object System.Collections.Generic.List[object]

function New-Drop([int]$maxW, [int]$maxH, [bool]$randomY) {
    $startY = if ($randomY) { [double]$rng.Next(-$maxH, $maxH) } else { [double](-$rng.Next(1, [Math]::Max(4, [int]($maxH / 2)))) }
    [PSCustomObject]@{
        X      = $rng.Next(0, [Math]::Max(1, $maxW))
        Y      = $startY
        Vel    = 0.55 + ($rng.NextDouble() * 0.75)
        Len    = $rng.Next(3, 7)
        Glint  = 0
    }
}

function New-Flake([int]$maxW, [int]$maxH, [bool]$randomY) {
    $startY = if ($randomY) { [double]$rng.Next(0, [Math]::Max(1, $maxH)) } else { -1.0 }
    $gIdx   = $rng.Next(0, $snowChars.Count)
    [PSCustomObject]@{
        X      = [double]$rng.Next(0, [Math]::Max(1, $maxW))
        Y      = $startY
        Vel    = 0.16 + ($rng.NextDouble() * 0.20)
        Phase  = $rng.NextDouble() * 6.28
        Drift  = 0.06 + ($rng.NextDouble() * 0.08)
        Glyph  = $snowChars[$gIdx]
        Bright = ($gIdx -le 1)
    }
}

$lastW   = -1
$lastH   = -1
$charBuf = $null
$toneBuf = $null

[Console]::Write("$esc[?25l$esc[2J")
try {
    while ($true) {
        if ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            if ($k.Key -eq 'Q' -or $k.Key -eq 'Escape') { break }
            if ($k.Key -eq 'C') { $colorIdx = ($colorIdx + 1) % $softOrder.Count }
            if ($k.Key -eq 'S') { $showSnow = -not $showSnow }
            if ($k.Key -eq 'L') { $allowFlash = -not $allowFlash; $flashFrames = 0 }
            if ($k.Key -eq 'UpArrow' -or $k.KeyChar -eq '+') { $Density = [Math]::Min(10, $Density + 1) }
            if ($k.Key -eq 'DownArrow' -or $k.KeyChar -eq '-') { $Density = [Math]::Max(1, $Density - 1) }
        }

        $w = [Math]::Max(10, $Host.UI.RawUI.WindowSize.Width)
        $h = [Math]::Max(5, $Host.UI.RawUI.WindowSize.Height)

        if ($w -ne $lastW -or $h -ne $lastH) {
            $lastW = $w
            $lastH = $h
            $charBuf = New-Object char[] ($w * $h)
            $toneBuf = New-Object byte[] ($w * $h)
            $drops.Clear()
            $flakes.Clear()
            $splashes.Clear()
            [Console]::Write("$esc[2J")
        }

        $targetDrops = [Math]::Max(8, [int]($w * $Density / 18))
        while ($drops.Count -lt $targetDrops) {
            $drops.Add((New-Drop $w $h ($drops.Count -lt ($targetDrops / 2))))
        }
        while ($drops.Count -gt $targetDrops) {
            $drops.RemoveAt($drops.Count - 1)
        }

        $targetFlakes = if ($showSnow) { [Math]::Max(4, [int]($w * $Density / 36)) } else { 0 }
        while ($flakes.Count -lt $targetFlakes) {
            $flakes.Add((New-Flake $w $h $true))
        }
        while ($flakes.Count -gt $targetFlakes) {
            $flakes.RemoveAt($flakes.Count - 1)
        }

        if ($flashFrames -gt 0) {
            $flashFrames--
        } elseif ($allowFlash -and ($rng.NextDouble() -lt 0.0045)) {
            $flashFrames = 4
        }
        $isFlashPeak = ($flashFrames -eq 4 -or $flashFrames -eq 2)

        [Array]::Clear($charBuf, 0, $charBuf.Length)
        [Array]::Clear($toneBuf, 0, $toneBuf.Length)

        for ($i = $splashes.Count - 1; $i -ge 0; $i--) {
            $sp = $splashes[$i]
            $sp.Life--
            if ($sp.Life -le 0) {
                $splashes.RemoveAt($i)
            } elseif ($sp.X -ge 0 -and $sp.X -lt $w) {
                $idx = (($h - 1) * $w) + $sp.X
                $charBuf[$idx] = $cSplash
                $toneBuf[$idx] = 4
            }
        }

        for ($i = 0; $i -lt $flakes.Count; $i++) {
            $f = $flakes[$i]
            $f.Y += $f.Vel
            $f.Phase += $f.Drift
            if ($f.Y -ge $h) {
                $flakes[$i] = New-Flake $w $h $false
                continue
            }
            $py = [int][Math]::Floor($f.Y)
            $rawX = [int][Math]::Round($f.X + ([Math]::Sin($f.Phase) * 1.5))
            $px = (($rawX % $w) + $w) % $w
            if ($py -ge 0 -and $py -lt $h) {
                $idx = ($py * $w) + $px
                $charBuf[$idx] = $f.Glyph
                $toneBuf[$idx] = if ($f.Bright) { 6 } else { 7 }
            }
        }

        for ($i = 0; $i -lt $drops.Count; $i++) {
            $d = $drops[$i]
            $d.Y += $d.Vel
            if ($d.Glint -gt 0) {
                $d.Glint--
            } elseif ($rng.NextDouble() -lt 0.007) {
                $d.Glint = $rng.Next(2, 5)
            }

            $headY = [int][Math]::Floor($d.Y)
            if (($headY - $d.Len) -ge $h) {
                if ($rng.NextDouble() -lt 0.45) {
                    $splashes.Add([PSCustomObject]@{ X = $d.X; Life = 2 })
                }
                $drops[$i] = New-Drop $w $h $false
                continue
            }

            $isShining = ($d.Glint -gt 0) -or $isFlashPeak

            for ($seg = 0; $seg -lt $d.Len; $seg++) {
                $py = $headY - $seg
                if ($py -lt 0 -or $py -ge $h -or $d.X -ge $w) { continue }
                $idx = ($py * $w) + $d.X

                if ($seg -eq 0) {
                    $charBuf[$idx] = if ($isShining) { $cBright } else { $cHead }
                    $toneBuf[$idx] = if ($isShining) { 5 } else { 3 }
                } elseif ($seg -lt ($d.Len - 1)) {
                    if ($toneBuf[$idx] -lt 2 -or $toneBuf[$idx] -ge 6) {
                        $charBuf[$idx] = $cMid
                        $toneBuf[$idx] = if ($isFlashPeak) { 3 } else { 2 }
                    }
                } else {
                    if ($toneBuf[$idx] -lt 1 -or $toneBuf[$idx] -ge 6) {
                        $charBuf[$idx] = $cTail
                        $toneBuf[$idx] = if ($isFlashPeak) { 2 } else { 1 }
                    }
                }
            }
        }

        $activeHead = $headRgb[$softOrder[$colorIdx]]
        $sb = New-Object System.Text.StringBuilder ($w * $h + ($h * 16))
        $curTone = 255

        for ($r = 0; $r -lt $h; $r++) {
            [void]$sb.Append("$esc[$($r + 1);1H")
            $rowOffset = $r * $w
            for ($c = 0; $c -lt $w; $c++) {
                $t = $toneBuf[$rowOffset + $c]
                if ($t -ne $curTone) {
                    $curTone = $t
                    switch ($t) {
                        0 { [void]$sb.Append($reset) }
                        1 { [void]$sb.Append($tailTone) }
                        2 { [void]$sb.Append($midTone) }
                        3 { [void]$sb.Append($activeHead) }
                        4 { [void]$sb.Append($splashRgb) }
                        5 { [void]$sb.Append($brightRgb) }
                        6 { [void]$sb.Append($snowHiRgb) }
                        7 { [void]$sb.Append($snowLoRgb) }
                    }
                }
                $ch = $charBuf[$rowOffset + $c]
                if ([int]$ch -eq 0) {
                    [void]$sb.Append(' ')
                } else {
                    [void]$sb.Append($ch)
                }
            }
        }
        [void]$sb.Append($reset)
        [Console]::Write($sb.ToString())
        Start-Sleep -Milliseconds $Speed
    }
} finally {
    [Console]::Write("$esc[2J$esc[H$esc[?25h")
}
