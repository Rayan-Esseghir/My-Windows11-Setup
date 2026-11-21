oh-my-posh init pwsh --config "C:\Users\PC\.config\oh-my-posh\catppuccin_mocha.omp.json" | Invoke-Expression

function fastfetch {
    $w = [Console]::WindowWidth
    if ($args.Count -gt 0) {
        fastfetch.exe @args
    } elseif ($w -ge 152) {
        fastfetch.exe
    } elseif ($w -ge 98) {
        fastfetch.exe --logo-position top --logo-padding-left 0 --logo-padding-top 1 --logo-padding-bottom 1
    } else {
        fastfetch.exe --logo-type none
    }
}

Start-Sleep -Milliseconds 150
fastfetch