# {{name}} - capture store screenshots from a REAL phone (no emulator needed).
# Needs: Android platform-tools (adb; comes with Android Studio) and a phone with USB debugging on.
# Usage: double-click capture-screenshots.bat, or  .\capture-screenshots.ps1 [-Install]

param(
    [switch]$Install,                              # install the newest release APK first
    [string]$Out = "store_assets\raw_screenshots"
)

Set-Location $PSScriptRoot

function Stop-Capture([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$screens = @(@(
{{#each screens}}    @{ File = '{{file}}'; Hint = '{{hint_ps}}' },
{{/each}}    $null
) | Where-Object { $_ })

if ($screens.Count -eq 0) { Stop-Capture "No [[screens]] in release-kit.toml. Add one entry per screenshot (name + hint), then run kit.py init --force." }

# ---- find adb ----------------------------------------------------------------
$adb = $null
if (Get-Command adb -ErrorAction SilentlyContinue) { $adb = "adb" }
else {
    foreach ($root in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA "Android\Sdk"))) {
        if ($root) {
            $candidate = Join-Path $root "platform-tools\adb.exe"
            if (Test-Path $candidate) { $adb = $candidate; break }
        }
    }
}
if (-not $adb) { Stop-Capture "adb not found. Install Android Studio (SDK Platform-Tools) or add platform-tools to PATH." }

# ---- pick the phone ------------------------------------------------------------
& $adb start-server | Out-Null
$serials = @()
foreach ($line in (& $adb devices)) {
    if ($line -match "^(\S+)\s+device$") { $serials += $Matches[1] }
}
if ($serials.Count -eq 0) {
    Stop-Capture "No phone found. On the phone: Settings > About phone > tap Build number 7 times > Developer options > USB debugging ON, plug in the cable and accept the 'Allow USB debugging' prompt."
}
$serial = $serials[0]
if ($serials.Count -gt 1) {
    Write-Host "More than one device is connected:"
    for ($i = 0; $i -lt $serials.Count; $i++) { Write-Host "  [$i] $($serials[$i])" }
    $serial = $serials[[int](Read-Host "Which one? (number)")]
}
Write-Host "Using device $serial"

function Invoke-Adb { & $adb -s $serial @args }

if ($Install) {
    $apk = Get-ChildItem -Path (Join-Path $PSScriptRoot "release") -Filter *.apk -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $apk) { Stop-Capture "No APK found under release\. Run release.bat first." }
    Write-Host "Installing $($apk.Name)..."
    Invoke-Adb install -r $apk.FullName | Out-Null
}

# ---- clean status bar (12:00, full battery, no notifications) - ignored if the phone does not support it ----
function Set-Demo([string[]]$Extra) { Invoke-Adb shell am broadcast -a com.android.systemui.demo @Extra | Out-Null }
try {
    Invoke-Adb shell settings put global sysui_demo_allowed 1 | Out-Null
    Set-Demo @("-e", "command", "enter")
    Set-Demo @("-e", "command", "clock", "-e", "hhmm", "1200")
    Set-Demo @("-e", "command", "battery", "-e", "level", "100", "-e", "plugged", "false")
    Set-Demo @("-e", "command", "network", "-e", "wifi", "show", "-e", "level", "4")
    Set-Demo @("-e", "command", "notifications", "-e", "visible", "false")
} catch { }

# ---- open the app ------------------------------------------------------------------
Invoke-Adb shell monkey -p {{package}} -c android.intent.category.LAUNCHER 1 | Out-Null
$outDir = Join-Path $PSScriptRoot $Out
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

Write-Host ""
Write-Host "For each screen: open it on the phone (set the language and any sample data you want people to see), then press Enter here."
foreach ($s in $screens) {
    Write-Host ""
    Write-Host "Screen: $($s.Hint)" -ForegroundColor Cyan
    Read-Host "  Open it on the phone, then press Enter to capture"
    Invoke-Adb shell screencap -p /sdcard/kit_shot.png | Out-Null
    Invoke-Adb pull /sdcard/kit_shot.png (Join-Path $outDir $s.File) | Out-Null
    Invoke-Adb shell rm /sdcard/kit_shot.png | Out-Null
    Write-Host "  Saved $(Join-Path $outDir $s.File)" -ForegroundColor Green
}

try { Set-Demo @("-e", "command", "exit") } catch { }

Write-Host ""
Write-Host "Done. Next: commit store_assets\raw_screenshots and ask your agent to run:  python scripts/kit.py graphics ."
Read-Host "Press Enter to exit"
