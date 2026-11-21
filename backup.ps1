<#
.SYNOPSIS
    Copies your live configs into this repo, ready to commit.
    The weather API key in YASB's config.yaml is replaced with a placeholder.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\backup.ps1
#>
$Repo     = $PSScriptRoot
$UserHome = $env:USERPROFILE
$Docs     = [Environment]::GetFolderPath('MyDocuments')
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

$items = @(
    @{ From = "$UserHome\.config\yasb\config.yaml";  To = "YASB\config.yaml"; MaskApiKey = $true },
    @{ From = "$UserHome\.config\yasb\styles.css";   To = "YASB\styles.css" },
    @{ From = "$UserHome\komorebi.json";             To = "Komorebi\komorebi.json" },
    @{ From = "$UserHome\.config\whkdrc";            To = "Komorebi\whkdrc" },
    @{ From = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"; To = "Terminal\settings.json" },
    @{ From = "$Docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"; To = "PowerShell\Microsoft.PowerShell_profile.ps1"; Raw = $true },
    @{ From = "$UserHome\.config\oh-my-posh\catppuccin_mocha.omp.json";   To = "OhMyPosh\catppuccin_mocha.omp.json" },
    @{ From = "$UserHome\.config\fastfetch\config.jsonc";                 To = "Fastfetch\config.jsonc" },
    @{ From = "$UserHome\.config\fastfetch\planet-small.txt";             To = "Fastfetch\planet-small.txt" },
    @{ From = "$UserHome\.config\cava\config";                           To = "Cava\config" },
    @{ From = "$UserHome\clock.ps1";                                       To = "Scripts\clock.ps1"; Raw = $true },
    @{ From = "$UserHome\rain.ps1";                                        To = "Scripts\rain.ps1";  Raw = $true },
    @{ From = "$env:APPDATA\FlowLauncher\Settings\Settings.json";         To = "Flow Launcher\Settings.json" }
)

foreach ($item in $items) {
    if (-not (Test-Path -LiteralPath $item.From)) {
        Write-Warning "Skipped (not found): $($item.From)"
        continue
    }

    $dest = Join-Path $Repo $item.To
    $dir  = Split-Path $dest -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if ($item.Raw) {
        # .ps1 files are copied byte-for-byte so a BOM (needed by Windows PowerShell 5.1) is kept
        Copy-Item -LiteralPath $item.From -Destination $dest -Force
    } else {
        $text = [IO.File]::ReadAllText($item.From)

        if ($item.MaskApiKey) {
            $text = [regex]::Replace($text, '(api_key:\s*")[^"]*(")', '${1}YOUR_API_KEY_HERE${2}')
        }

        [IO.File]::WriteAllText($dest, $text, $Utf8NoBom)
    }
    Write-Host "backed up -> $($item.To)" -ForegroundColor Green
}

# Flow Launcher themes you added yourself (all .xaml files)
$themeSrc = "$env:APPDATA\FlowLauncher\Themes"
if (Test-Path $themeSrc) {
    $themeDest = Join-Path $Repo "Flow Launcher\Themes"
    New-Item -ItemType Directory -Path $themeDest -Force | Out-Null
    Get-ChildItem $themeSrc -Filter *.xaml | ForEach-Object {
        Copy-Item $_.FullName $themeDest -Force
        Write-Host "backed up -> Flow Launcher\Themes\$($_.Name)" -ForegroundColor Green
    }
} else {
    Write-Warning "Skipped (not found): $themeSrc"
}

# start-wm.ps1 is already in the repo root, nothing to do for it.
Write-Host "`nDone. Review the changes with 'git diff' before you push." -ForegroundColor Yellow
