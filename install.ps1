<#
.SYNOPSIS
    Installs the apps and copies the configs of My-Win11-Setup.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Extras
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -SkipApps
#>
param(
    [switch]$Extras,        # also install TranslucentTB
    [switch]$HideTaskbar,   # also install THide and start it with Windows (asks for admin)
    [switch]$SkipApps,      # only copy the configs
    [switch]$SkipConfigs    # only install the apps
)

$ErrorActionPreference = "Continue"
$Repo       = $PSScriptRoot
$SourceUser = "PC"                                  # username used inside the repo files
$Stamp      = Get-Date -Format "yyyyMMdd-HHmmss"
$Utf8NoBom  = New-Object System.Text.UTF8Encoding $false
$UserHome   = $env:USERPROFILE
$Docs       = [Environment]::GetFolderPath('MyDocuments')

function Write-Step($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

# Copies a text config and swaps "C:\Users\PC" for the current user's folder.
# Use -Bom for .ps1 files: Windows PowerShell 5.1 needs a BOM to read Unicode characters in scripts.
function Copy-Config {
    param([string]$Source, [string]$Dest, [switch]$Bom)

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Warning "Not found in repo: $Source"
        return
    }
    $dir = Split-Path $Dest -Parent
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $Dest) {
        Copy-Item -LiteralPath $Dest -Destination "$Dest.bak-$Stamp" -Force
    }

    $text = [IO.File]::ReadAllText($Source)
    $text = $text.Replace("C:/Users/$SourceUser", ($UserHome -replace '\\', '/'))
    $text = $text.Replace("C:\\Users\\$SourceUser", ($UserHome -replace '\\', '\\'))
    $text = $text.Replace("C:\Users\$SourceUser", $UserHome)
    $enc = if ($Bom) { New-Object System.Text.UTF8Encoding $true } else { $Utf8NoBom }
    [IO.File]::WriteAllText($Dest, $text, $enc)

    Write-Host "  copied -> $Dest" -ForegroundColor Green
}

# ---------------------------------------------------------------- apps
if (-not $SkipApps) {

    Write-Step "Scoop"
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        Update-SessionPath
    }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install git 7zip
        scoop bucket add extras
        scoop install extras/komorebi extras/whkd extras/yasb
    } else {
        Write-Warning "Scoop is not available. Open a new PowerShell window and run this script again."
    }

    Write-Step "winget apps"
    $wingetApps = @(
        "LGUG2Z.masir",
        "Flow-Launcher.Flow-Launcher",
        "Microsoft.WindowsTerminal",
        "JanDeDobbeleer.OhMyPosh",
        "Fastfetch-cli.Fastfetch",
        "karlstav.cava",
        "sxyazi.yazi",
        "junegunn.fzf",
        "sharkdp.fd",
        "ajeetdsouza.zoxide",
        "BurntSushi.ripgrep.MSVC",
        "jqlang.jq",
        "Gyan.FFmpeg",
        "ImageMagick.ImageMagick",
        "Microsoft.VisualStudioCode"
    )
    if ($Extras) {
        $wingetApps += @(
            "CharlesMilette.TranslucentTB"
        )
    }
    foreach ($id in $wingetApps) {
        Write-Host "  installing $id"
        winget install --id $id -e --source winget --silent `
            --accept-package-agreements --accept-source-agreements
    }
    Update-SessionPath

    if ($HideTaskbar) {
        Write-Step "THide (hides the Windows taskbar)"
        try {
            $rel   = Invoke-RestMethod -Uri "https://api.github.com/repos/amnweb/thide/releases/latest" -Headers @{ "User-Agent" = "install.ps1" }
            $asset = $rel.assets | Where-Object { $_.name -like "*x64.msi" } | Select-Object -First 1
            if ($asset) {
                $msi = Join-Path $env:TEMP $asset.name
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msi
                Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /passive" -Verb RunAs -Wait
                Update-SessionPath
                if (Get-Command thide -ErrorAction SilentlyContinue) {
                    Start-Process thide -ArgumentList "start" -WindowStyle Hidden
                    thide enable-autostart
                } else {
                    Write-Warning "THide installed, but not found yet. Open a new window and run: thide start ; thide enable-autostart"
                }
            } else {
                Write-Warning "No x64 installer found. Download THide from https://github.com/amnweb/thide/releases"
            }
        } catch {
            Write-Warning "Could not install THide: $_  (download it from https://github.com/amnweb/thide/releases)"
        }
    }

    Write-Step "Nerd Font (JetBrainsMono)"
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        oh-my-posh font install JetBrainsMono
    } else {
        Write-Warning "oh-my-posh not found yet. Open a new window and run: oh-my-posh font install JetBrainsMono"
    }
}

# ------------------------------------------------------------- configs
if (-not $SkipConfigs) {

    Write-Step "Copying configs"

    # YASB
    Copy-Config "$Repo\YASB\config.yaml" "$UserHome\.config\yasb\config.yaml"
    Copy-Config "$Repo\YASB\styles.css"  "$UserHome\.config\yasb\styles.css"

    # Komorebi + whkd
    Copy-Config "$Repo\Komorebi\komorebi.json" "$UserHome\komorebi.json"
    Copy-Config "$Repo\Komorebi\whkdrc"        "$UserHome\.config\whkdrc"

    # Windows Terminal
    $wtDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
    if (Test-Path $wtDir) {
        Copy-Config "$Repo\Terminal\settings.json" "$wtDir\settings.json"
    } else {
        Write-Warning "Windows Terminal folder not found. Open Windows Terminal once, then run this script again."
    }

    # PowerShell profile (Windows PowerShell 5.1)
    Copy-Config "$Repo\PowerShell\Microsoft.PowerShell_profile.ps1" "$Docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Bom

    # Oh My Posh + Fastfetch
    Copy-Config "$Repo\OhMyPosh\catppuccin_mocha.omp.json" "$UserHome\.config\oh-my-posh\catppuccin_mocha.omp.json"
    Copy-Config "$Repo\Fastfetch\config.jsonc"             "$UserHome\.config\fastfetch\config.jsonc"
    Copy-Config "$Repo\Fastfetch\planet-small.txt"         "$UserHome\.config\fastfetch\planet-small.txt"

    # Cava
    Copy-Config "$Repo\Cava\config" "$UserHome\.config\cava\config"

    # Terminal visuals: run them with ~\clock.ps1 and ~\rain.ps1
    Copy-Config "$Repo\Scripts\clock.ps1" "$UserHome\clock.ps1" -Bom
    Copy-Config "$Repo\Scripts\rain.ps1"  "$UserHome\rain.ps1"  -Bom

    # Flow Launcher theme (select it in Flow Launcher > Settings > Theme)
    $flowThemes = "$env:APPDATA\FlowLauncher\Themes"
    New-Item -ItemType Directory -Path $flowThemes -Force | Out-Null
    Copy-Item "$Repo\Flow Launcher\Themes\*.xaml" $flowThemes -Force
    Write-Host "  copied -> $flowThemes" -ForegroundColor Green

    # Komorebi application rules
    if (Get-Command komorebic -ErrorAction SilentlyContinue) {
        Write-Step "Komorebi application rules"
        komorebic fetch-asc
    } else {
        Write-Warning "komorebic not found yet. Open a new window and run: komorebic fetch-asc"
    }
}

# --------------------------------------------------------------- done
Write-Host "`nDone!" -ForegroundColor Green
Write-Host "Manual steps left:" -ForegroundColor Yellow
Write-Host "  1. Edit $UserHome\.config\yasb\config.yaml  (weather api_key + wallpapers image_path)"
Write-Host "  2. Install btop4win (see the README)"
Write-Host "  3. Flow Launcher > Settings > Theme > Catppuccin_Mocha"
Write-Host "  4. Open a new terminal, then run .\start-wm.ps1"
Write-Host "  5. Try the terminal visuals:  ~\clock.ps1   and   ~\rain.ps1"
