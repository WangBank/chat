param(
    [string]$Repo = "WangBank/chat",
    [string]$ReleaseTag = "",
    [string]$DownloadsDir = "",
    [string]$PublicBaseUrl = "https://chat.wangbank.top",
    [string]$AssetMirrorPrefix = "",
    [switch]$SkipApkDownload,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-SyncLog {
    param([string]$Message)
    Write-Host "[sync-android-release] $Message"
}

function Resolve-DownloadsDir {
    param([string]$Explicit)

    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        return $Explicit
    }
    if (-not [string]::IsNullOrWhiteSpace($env:WEB_DOWNLOADS_DIR)) {
        return $env:WEB_DOWNLOADS_DIR
    }
    return (Join-Path $env:USERPROFILE ".foreverlove-chat\storage\downloads")
}

function Get-GitHubHeaders {
    $headers = @{
        "Accept"     = "application/vnd.github+json"
        "User-Agent" = "foreverlove-chat-apk-sync"
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $headers["Authorization"] = "Bearer $($env:GITHUB_TOKEN)"
    }
    return $headers
}

function Get-ReleaseAssets {
    param(
        [string]$Repository,
        [string]$Tag,
        [hashtable]$Headers
    )

    $releaseUrl = if ([string]::IsNullOrWhiteSpace($Tag)) {
        "https://api.github.com/repos/$Repository/releases/latest"
    }
    else {
        "https://api.github.com/repos/$Repository/releases/tags/$Tag"
    }

    Write-SyncLog "Querying $releaseUrl"
    return Invoke-RestMethod -Uri $releaseUrl -Headers $Headers -MaximumRedirection 5
}

function Get-AssetByName {
    param($Release, [string]$Name)

    $asset = $Release.assets | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if ($null -eq $asset) {
        throw "Release $($Release.tag_name) does not contain asset $Name"
    }
    return $asset
}

function Get-AssetDownloadUrl {
    param([string]$Url, [string]$MirrorPrefix)

    if ([string]::IsNullOrWhiteSpace($MirrorPrefix)) {
        return $Url
    }

    return "$($MirrorPrefix.TrimEnd('/'))/$Url"
}

function Save-AssetFile {
    param(
        [string]$Url,
        [string]$Destination,
        [hashtable]$Headers
    )

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    Write-SyncLog "Downloading $Url"
    $progressPreference = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    try {
        # -UseBasicParsing keeps this working on Windows PowerShell 5.1 hosts
        # where the IE engine was never initialized; it is a no-op on PowerShell 7.
        Invoke-WebRequest -Uri $Url -Headers $Headers -OutFile $Destination -MaximumRedirection 10 -UseBasicParsing
    }
    finally {
        $ProgressPreference = $progressPreference
    }
}

function Get-FileSha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$downloadsDir = Resolve-DownloadsDir -Explicit $DownloadsDir
New-Item -ItemType Directory -Force -Path $downloadsDir | Out-Null
Write-SyncLog "Downloads directory: $downloadsDir"

if ([string]::IsNullOrWhiteSpace($AssetMirrorPrefix) -and -not [string]::IsNullOrWhiteSpace($env:APK_ASSET_MIRROR_PREFIX)) {
    $AssetMirrorPrefix = $env:APK_ASSET_MIRROR_PREFIX
}

$headers = Get-GitHubHeaders
$release = Get-ReleaseAssets -Repository $Repo -Tag $ReleaseTag -Headers $headers
$manifestAsset = Get-AssetByName -Release $release -Name "android-version.json"
$apkAsset = Get-AssetByName -Release $release -Name "LoveChat-Android.apk"

$manifestPath = Join-Path $downloadsDir "android-version.json"
$apkPath = Join-Path $downloadsDir "LoveChat-Android.apk"
$manifestTempPath = "$manifestPath.tmp"
$apkTempPath = "$apkPath.tmp"

Save-AssetFile -Url $manifestAsset.browser_download_url -Destination $manifestTempPath -Headers $headers
$manifest = Get-Content -LiteralPath $manifestTempPath -Raw | ConvertFrom-Json

$expectedSha = [string]$manifest.sha256
$expectedSize = [int64]$manifest.size
if ([string]::IsNullOrWhiteSpace($expectedSha) -or $expectedSize -le 0) {
    throw "Remote manifest for $($release.tag_name) is missing sha256/size"
}

$alreadySynced = (-not $Force) -and (Test-Path -LiteralPath $apkPath) -and (Test-Path -LiteralPath $manifestPath)
if ($alreadySynced) {
    $existingManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $existingSize = (Get-Item -LiteralPath $apkPath).Length
    if ([string]$existingManifest.sha256 -eq $expectedSha -and $existingSize -eq $expectedSize) {
        Write-SyncLog "Already up to date: version $($manifest.versionName) ($($manifest.versionCode)), sha256 $expectedSha"
        Remove-Item -LiteralPath $manifestTempPath -Force
        exit 0
    }
}

if ($SkipApkDownload) {
    Write-SyncLog "SkipApkDownload set: keeping the existing APK file untouched."
}
else {
    $apkUrl = Get-AssetDownloadUrl -Url $apkAsset.browser_download_url -MirrorPrefix $AssetMirrorPrefix
    Save-AssetFile -Url $apkUrl -Destination $apkTempPath -Headers $headers

    $downloadedSize = (Get-Item -LiteralPath $apkTempPath).Length
    if ($downloadedSize -ne $expectedSize) {
        Remove-Item -LiteralPath $apkTempPath -Force
        throw "APK size mismatch: downloaded $downloadedSize bytes, manifest expects $expectedSize"
    }

    $downloadedSha = Get-FileSha256 -Path $apkTempPath
    if ($downloadedSha -ne $expectedSha) {
        Remove-Item -LiteralPath $apkTempPath -Force
        throw "APK SHA256 mismatch: downloaded $downloadedSha, manifest expects $expectedSha"
    }

    Move-Item -LiteralPath $apkTempPath -Destination $apkPath -Force
    Write-SyncLog "APK verified: $downloadedSize bytes, sha256 $downloadedSha"
}

$publicBase = if ([string]::IsNullOrWhiteSpace($PublicBaseUrl)) { "" } else { $PublicBaseUrl.TrimEnd("/") }
$manifest.apkUrl = "$publicBase/download/android"
$fallbackUrl = $apkAsset.browser_download_url

$manifest | Add-Member -NotePropertyName "apkFallbackUrl" -NotePropertyValue $fallbackUrl -Force
$manifest | Add-Member -NotePropertyName "mirrors" -NotePropertyValue @($fallbackUrl) -Force
$manifest | Add-Member -NotePropertyName "syncedAt" -NotePropertyValue ((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")) -Force

# Write UTF-8 without a BOM: Windows PowerShell 5.1 adds one for -Encoding utf8,
# and a leading BOM breaks JSON.parse / jsonDecode on the clients.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestTempPath, ($manifest | ConvertTo-Json -Depth 6), $utf8NoBom)
Move-Item -LiteralPath $manifestTempPath -Destination $manifestPath -Force

Write-SyncLog "Published manifest for version $($manifest.versionName) ($($manifest.versionCode))"
Write-SyncLog "Download URL: $($manifest.apkUrl)"
Write-SyncLog "Fallback URL: $fallbackUrl"
if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    @(
        "### Android APK sync",
        "",
        "- Release: " + $release.tag_name,
        "- Version: " + $manifest.versionName + " (" + $manifest.versionCode + ")",
        "- APK: " + $apkPath,
        "- Download URL: " + $manifest.apkUrl,
        "- Fallback: " + $fallbackUrl
    ) | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY
}
