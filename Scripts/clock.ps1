param(
    [ValidateSet("lavender", "rosewater", "teal", "mauve", "sapphire", "text")]
    [string]$Color = "lavender",
    [switch]$Seconds
)

$esc = [char]27
$b = [string][char]0x2588
$f = "$b$b$b$b$b$b"
$l = "$b$b    "
$r = "    $b$b"
$s = "$b$b  $b$b"
$c = "$b$b"

$glyphs = @{
    '0' = @($f, $s, $s, $s, $f)
    '1' = @($r, $r, $r, $r, $r)
    '2' = @($f, $r, $f, $l, $f)
    '3' = @($f, $r, $f, $r, $f)
    '4' = @($s, $s, $f, $r, $r)
    '5' = @($f, $l, $f, $r, $f)
    '6' = @($f, $l, $f, $s, $f)
    '7' = @($f, $r, $r, $r, $r)
    '8' = @($f, $s, $f, $s, $f)
    '9' = @($f, $s, $f, $r, $f)
    ':' = @("  ", $c, "  ", $c, "  ")
}

$softOrder = @("lavender", "rosewater", "teal", "mauve", "sapphire", "text")
$softRgb = @{
    "lavender"  = "$esc[38;2;180;190;254m"
    "rosewater" = "$esc[38;2;245;224;220m"
    "teal"      = "$esc[38;2;148;226;213m"
    "mauve"     = "$esc[38;2;203;166;247m"
    "sapphire"  = "$esc[38;2;116;199;236m"
    "text"      = "$esc[38;2;205;214;244m"
}

$reset     = "$esc[0m"
$colorIdx  = [Array]::IndexOf($softOrder, $Color)
$fmt       = if ($Seconds) { "HH:mm:ss" } else { "HH:mm" }
$lastState = ""

[Console]::Write("$esc[?25l$esc[2J")
try {
    while ($true) {
        if ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            if ($k.Key -eq 'Q' -or $k.Key -eq 'Escape') { break }
            if ($k.Key -eq 'C') {
                $colorIdx = ($colorIdx + 1) % $softOrder.Count
                $lastState = ""
            }
        }

        $w = $Host.UI.RawUI.WindowSize.Width
        $h = $Host.UI.RawUI.WindowSize.Height
        $now = (Get-Date).ToString($fmt)
        $state = "$now|$w|$h|$colorIdx"

        if ($state -ne $lastState) {
            $lastState = $state
            $tone = $softRgb[$softOrder[$colorIdx]]

            $lines = for ($row = 0; $row -lt 5; $row++) {
                ($now.ToCharArray() | ForEach-Object { $glyphs[[string]$_][$row] }) -join "  "
            }

            $padLeft = [Math]::Max(0, [int](($w - $lines[0].Length) / 2))
            $padTop  = [Math]::Max(1, [int](($h - 5) / 2) + 1)

            $sb = New-Object System.Text.StringBuilder
            [void]$sb.Append("$esc[2J$tone")
            for ($i = 0; $i -lt 5; $i++) {
                [void]$sb.Append("$esc[$($padTop + $i);$($padLeft + 1)H$($lines[$i])")
            }
            [void]$sb.Append($reset)
            [Console]::Write($sb.ToString())
        }
        Start-Sleep -Milliseconds 200
    }
} finally {
    [Console]::Write("$esc[2J$esc[H$esc[?25h")
}
