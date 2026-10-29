# start-wm.ps1 - start komorebi (+ whkd) first, then YASB.
# Run it at logon via Task Scheduler (see instructions), or by hand.

$ErrorActionPreference = "SilentlyContinue"

# 1. Window manager + hotkeys
komorebic start --whkd

# 2. Give komorebi a moment to create its pipe so YASB connects on the first try
Start-Sleep -Seconds 3

# 3. Bar (skip if YASB is already running)
if (-not (Get-Process yasb -ErrorAction SilentlyContinue)) {
    yasbc start
}
