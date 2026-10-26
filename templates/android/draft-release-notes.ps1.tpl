# Prints a DRAFT of the English release notes from recent commit messages (bullets under 450 characters).
# Used by release.ps1 when you answer "y" to the draft question; safe to run by hand. Git must be on PATH.
param([string]$Since = "")

Set-Location $PSScriptRoot
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { exit 1 }

if (-not $Since) {
    $tag = & git describe --tags --abbrev=0 2>$null
    if ($LASTEXITCODE -eq 0 -and $tag) { $Since = "$tag" }
}
if (-not $Since) {
    # fall back to the last commit that changed the version code
    $c = & git log -1 --format=%H -G"versionCode" -- app/build.gradle.kts 2>$null
    if ($c) { $Since = "$c" }
}

if ($Since) { $subjects = @(& git log "$Since..HEAD" --no-merges --pretty=%s 2>$null) }
else { $subjects = @(& git log -n 30 --no-merges --pretty=%s 2>$null) }

# internal-looking commits are left out
$skip = '^(merge|chore|refactor|docs?|ci|test|build|bump|release|wip)\b|release\.ps1|readme|gradle wrapper|keystore|\.gitignore|typo|temporary|park |website|privacy policy|terms'
$limit = 450
$used = "What's new:".Length + 1
$seen = @{}
$lines = @()
foreach ($subject in $subjects) {
    $t = "$subject".Trim().TrimEnd('.')
    if (-not $t -or $t -match $skip -or $seen.ContainsKey($t.ToLower())) { continue }
    $seen[$t.ToLower()] = $true
    $line = "- " + $t.Substring(0, 1).ToUpper() + $t.Substring(1)
    if ($used + $line.Length + 1 -gt $limit) { break }
    $lines += $line
    $used += $line.Length + 1
}
$lines
