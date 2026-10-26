# {{name}} - release builder (Windows PowerShell 5.1+).
# Prompts for the new version, bumps app\build.gradle.kts, signs with the upload keystore,
# builds the AAB (Play Store) + APK, and collects everything in release\v<name>-<code>\.

param(
    [string]$VersionName = "",
    [string]$VersionCode = "",
    [switch]$Clean            # also run "gradle clean" first (can fail on Windows if a file is locked)
)

Set-Location $PSScriptRoot

function Stop-Release([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "============================================"
Write-Host " {{name}} - Release Builder"
Write-Host "============================================"
Write-Host ""

# ---- 1. Tools --------------------------------------------------------------
if (-not (Get-Command java -ErrorAction SilentlyContinue)) { Stop-Release "Java not found. Install JDK 17+ (or Android Studio) and add it to PATH." }
if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) { Stop-Release "keytool not found. Install a full JDK 17+." }

$gradle = $null
if (Test-Path ".\gradlew.bat") { $gradle = ".\gradlew.bat" }
elseif (Get-Command gradle -ErrorAction SilentlyContinue) { $gradle = "gradle" }
else {
    # No wrapper script: reuse a Gradle already downloaded by Android Studio, preferring the
    # version in gradle-wrapper.properties. Layout: dists\<name>\<hash>\<gradle-x.y>\bin\gradle.bat
    $gradleHome = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { Join-Path $env:USERPROFILE ".gradle" }
    $cached = @(Get-ChildItem (Join-Path $gradleHome "wrapper\dists\*\*\*\bin\gradle.bat") -ErrorAction SilentlyContinue)
    $wanted = [regex]::Match((Get-Content "gradle\wrapper\gradle-wrapper.properties" -Raw -ErrorAction SilentlyContinue), 'gradle-([\d.]+)-').Groups[1].Value
    $pick = $cached | Where-Object { $wanted -and $_.FullName -like "*gradle-$wanted\bin*" } | Select-Object -First 1
    if (-not $pick) { $pick = $cached | Sort-Object FullName -Descending | Select-Object -First 1 }
    if ($pick) { $gradle = $pick.FullName }
}
if (-not $gradle) { Stop-Release "No gradlew.bat or gradle found. Open the project in Android Studio once (it generates the wrapper) or install Gradle 9.x." }

# ---- 2. Version ------------------------------------------------------------
$gradlePath = (Resolve-Path "app\build.gradle.kts").Path
$gradleText = [System.IO.File]::ReadAllText($gradlePath)
$curName = [regex]::Match($gradleText, 'versionName\s*=\s*"([^"]+)"').Groups[1].Value
$curCode = [regex]::Match($gradleText, 'versionCode\s*=\s*(\d+)').Groups[1].Value
Write-Host "Current version: $curName (code $curCode)"

# Press Enter to accept the suggestion: same version name, version code + 1
$suggestedCode = [int]$curCode + 1
if (-not $VersionName) {
    $VersionName = Read-Host "Enter new version name [Enter = $curName]"
    if (-not $VersionName) { $VersionName = $curName }
}
if (-not $VersionCode) {
    $VersionCode = Read-Host "Enter new version code [Enter = $suggestedCode]"
    if (-not $VersionCode) { $VersionCode = "$suggestedCode" }
}
if (-not $VersionName) { Stop-Release "Version name cannot be empty." }
if ($VersionCode -notmatch '^\d+$') { Stop-Release "Version code must be a number." }
$codeInt = [int]$VersionCode
if ($codeInt -le [int]$curCode) {
    $ok = Read-Host "Code $codeInt is not higher than current $curCode. Play will reject a reused code. Continue? [y/N]"
    if ($ok -ne "y") { exit 1 }
}

Write-Host ""
Write-Host "[1/4] Updating app\build.gradle.kts..."
$gradleText = [regex]::Replace($gradleText, 'versionCode\s*=\s*\d+', "versionCode = $codeInt")
$gradleText = [regex]::Replace($gradleText, 'versionName\s*=\s*"[^"]+"', "versionName = `"$VersionName`"")
[System.IO.File]::WriteAllText($gradlePath, $gradleText, (New-Object System.Text.UTF8Encoding $false))
Write-Host "   Done."

# ---- 2b. Release notes (one file, one tag per language) ----------------------
# release-notes.txt holds every language in the format Play Console accepts when pasted:
#   <en-US>
#   ...
#   </en-US>
#   <bn-BD>
#   ...
#   </bn-BD>
# Play Console allows 500 characters per language.
$notesPath = Join-Path $PSScriptRoot "release-notes.txt"
if (-not (Test-Path $notesPath)) {
    $template = "<en-US>`r`nWhat's new:`r`n- `r`n</en-US>`r`n<bn-BD>`r`n- `r`n</bn-BD>`r`n"
    [System.IO.File]::WriteAllText($notesPath, $template, (New-Object System.Text.UTF8Encoding $false))
}

function Read-ReleaseNotes([string]$Path) {
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $notes = [ordered]@{}
    foreach ($m in [regex]::Matches($raw, '(?s)<([A-Za-z]{2,3}(?:-[A-Za-z0-9]+)?)>\s*(.*?)\s*</\1>')) {
        $notes[$m.Groups[1].Value] = $m.Groups[2].Value.Trim()
    }
    return $notes
}

function Show-ReleaseNotes($notes) {
    foreach ($code in $notes.Keys) {
        Write-Host ""
        Write-Host ("--- {0} ({1} / 500 characters) ---" -f $code, $notes[$code].Length)
        Write-Host $notes[$code]
    }
}

Write-Host ""
Write-Host "Release notes for $VersionName (release-notes.txt):"
$releaseNotes = Read-ReleaseNotes $notesPath
Show-ReleaseNotes $releaseNotes
if ((Read-Host "Edit the release notes now? [y/N]") -eq "y") {
    Start-Process notepad.exe $notesPath -Wait
    $releaseNotes = Read-ReleaseNotes $notesPath
}
if ($releaseNotes.Count -eq 0) { Stop-Release "No <lang-code>...</lang-code> blocks found in release-notes.txt (for example <en-US>...</en-US>)." }
foreach ($code in $releaseNotes.Keys) {
    $len = $releaseNotes[$code].Length
    if ($len -eq 0 -or $releaseNotes[$code] -match "^(What's new:)?\s*-?\s*$") { Write-Host "WARNING: the $code release notes look empty." -ForegroundColor Yellow }
    if ($len -gt 500) { Stop-Release "The $code release notes are $len characters; Google Play allows 500. Shorten release-notes.txt." }
}

# ---- 3. Upload keystore ----------------------------------------------------
# Same idea as the other apps: credentials live in a git-ignored keystore.properties
# (storeFile, storePassword, keyPassword), so you are only asked ONCE.
# app\build.gradle.kts reads KEYSTORE_PATH / STORE_PASSWORD / KEY_PASSWORD (alias "upload"),
# so this script loads the file and exports them as environment variables for Gradle.
Write-Host "[2/4] Upload keystore..."
$propsPath = Join-Path $PSScriptRoot "keystore.properties"

function Read-Secret([string]$Prompt) {
    $s = Read-Host $Prompt -AsSecureString
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}

function Read-Props([string]$Path) {
    $h = @{}
    foreach ($line in Get-Content $Path) {
        if ($line -match '^\s*([^#=\s][^=]*?)\s*=\s*(.*)$') { $h[$Matches[1]] = $Matches[2] }
    }
    return $h
}

if (-not (Test-Path $propsPath)) {
    Write-Host "   First run: no keystore.properties yet."
    $existing = @(Get-ChildItem -Path $PSScriptRoot -Filter *.jks -File)
    if ($existing.Count -ge 1) {
        $keystoreName = $existing[0].Name
        Write-Host "   Using existing keystore: $keystoreName"
        $pw = Read-Secret "   Password of $keystoreName"
    } else {
        Write-Host "   No .jks file found in this folder."
        if ((Read-Host "   Generate one now? (or answer n and create it yourself, see README) [y/N]") -ne "y") { exit 1 }
        # Named after the application ID (for example {{package}}.jks) so every app's key is unique
        $appId = [regex]::Match($gradleText, 'applicationId\s*=\s*"([^"]+)"').Groups[1].Value
        if (-not $appId) { $appId = "upload-key" }
        $keystoreName = "$appId.jks"
        Write-Host "   Keystore file: $keystoreName"
        $pw = Read-Secret "   Choose keystore password (min 6 chars)"
        if ($pw.Length -lt 6) { Stop-Release "Password too short." }
        if ($pw -ne (Read-Secret "   Repeat password")) { Stop-Release "Passwords do not match." }
        keytool -genkeypair -v -keystore (Join-Path $PSScriptRoot $keystoreName) -alias upload -keyalg RSA -keysize 2048 -validity 10000 -storepass $pw -keypass $pw -dname "CN={{developer_name}}"
        if ($LASTEXITCODE -ne 0) { Stop-Release "Keystore creation failed." }
    }
    $content = "storeFile=$keystoreName`r`nstorePassword=$pw`r`nkeyAlias=upload`r`nkeyPassword=$pw`r`n"
    [System.IO.File]::WriteAllText($propsPath, $content, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "   Saved keystore.properties (git-ignored). You will not be asked again." -ForegroundColor Green
    Write-Host "   IMPORTANT: back up $keystoreName and keystore.properties in 2 safe places." -ForegroundColor Yellow
}

$props = Read-Props $propsPath
$env:KEYSTORE_PATH = Join-Path $PSScriptRoot $props["storeFile"]
$env:STORE_PASSWORD = $props["storePassword"]
$env:KEY_PASSWORD = if ($props["keyPassword"]) { $props["keyPassword"] } else { $props["storePassword"] }
if (-not (Test-Path $env:KEYSTORE_PATH)) { Stop-Release "Keystore not found: $env:KEYSTORE_PATH" }

# ---- 4. Build --------------------------------------------------------------
Write-Host ""
# Stop background Gradle daemons first: on Windows they (and Android Studio / antivirus) can keep files in
# app\build open, which makes "clean" fail with "Unable to delete directory".
& $gradle --stop | Out-Null

$tasks = @("bundleRelease", "assembleRelease")
if ($Clean) {
    Write-Host "[3/4] Building (clean, bundleRelease, assembleRelease)..."
    & $gradle clean
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   'clean' failed (a file in app\build is locked). Continuing without it; Gradle rebuilds what changed." -ForegroundColor Yellow
    }
} else {
    Write-Host "[3/4] Building (bundleRelease, assembleRelease)..."
}
& $gradle @tasks
if ($LASTEXITCODE -ne 0) { Stop-Release "Gradle build failed. Close Android Studio and any open Explorer windows in app\build, then run again." }

# ---- 5. Collect ------------------------------------------------------------
Write-Host ""
Write-Host "[4/4] Collecting files..."
$out = Join-Path $PSScriptRoot "release\v$VersionName-$codeInt"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Path $out | Out-Null

$aab = Join-Path $out "{{slug}}-$VersionName-$codeInt.aab"
Copy-Item "app\build\outputs\bundle\release\app-release.aab" $aab
if (Test-Path "app\build\outputs\apk\release\app-release.apk") {
    Copy-Item "app\build\outputs\apk\release\app-release.apk" (Join-Path $out "{{slug}}-$VersionName-$codeInt.apk")
}
if (Test-Path "app\build\outputs\mapping\release\mapping.txt") {
    Copy-Item "app\build\outputs\mapping\release\mapping.txt" $out
}
# Store listing, screenshots and icons are NOT copied per release: they live once in store_assets\ (see README).
# The release notes go along as one file, already in Play's <en-US> / <bn-BD> format, ready to paste.
Copy-Item $notesPath (Join-Path $out "release-notes.txt")

Write-Host ""
Write-Host "Bundle signature (must be your upload key, not the debug key):"
keytool -printcert -jarfile $aab | Select-String "Owner|SHA256"

Write-Host ""
Write-Host "============================================"
Write-Host " Build complete!"
Write-Host "============================================"
Write-Host " Version : $VersionName (code $codeInt)"
Write-Host " Folder  : $out"
Write-Host " Upload  : {{slug}}-$VersionName-$codeInt.aab  -> Play Console > Create release"
Write-Host " Notes   : release-notes.txt (paste the whole file into the release notes box)"
Write-Host "============================================"
Start-Process explorer.exe $out
Write-Host ""
Read-Host "Press Enter to exit"
