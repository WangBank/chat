param(
    [Parameter(Mandatory = $true)]
    [string]$Token,

    [string]$RepoUrl = "https://github.com/WangBank/chat",
    [string]$RunnerDir = "",
    [string]$RunnerName = "",
    [string]$Labels = "local-docker,docker",
    [switch]$Start
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$IsWindowsPlatform = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
    [System.Runtime.InteropServices.OSPlatform]::Windows)

if (-not $IsWindowsPlatform) {
    throw "This helper is intended for the Windows self-hosted runner used by this repository."
}

if ([string]::IsNullOrWhiteSpace($RunnerDir)) {
    $RunnerDir = Join-Path $env:USERPROFILE "actions-runner-chat"
}

if ([string]::IsNullOrWhiteSpace($RunnerName)) {
    $RunnerName = "$env:COMPUTERNAME-chat"
}

function Write-RunnerLog {
    param([string]$Message)
    Write-Host "[register-runner] $Message"
}

New-Item -ItemType Directory -Force -Path $RunnerDir | Out-Null
Set-Location -LiteralPath $RunnerDir

if (Test-Path -LiteralPath (Join-Path $RunnerDir ".runner")) {
    throw "Runner directory is already configured: $RunnerDir. Use a new RunnerDir or remove the existing runner from GitHub first."
}

if (-not (Test-Path -LiteralPath (Join-Path $RunnerDir "config.cmd"))) {
    Write-RunnerLog "Resolving the latest GitHub Actions runner release."
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/actions/runner/releases/latest" -Headers @{
        "Accept" = "application/vnd.github+json"
        "User-Agent" = "foreverlove-chat-runner-setup"
    }

    $asset = $release.assets |
        Where-Object { $_.name -like "actions-runner-win-x64-*.zip" } |
        Select-Object -First 1

    if ($null -eq $asset) {
        throw "Could not find a Windows x64 runner asset in the latest GitHub Actions runner release."
    }

    $zipPath = Join-Path $RunnerDir $asset.name
    if (-not (Test-Path -LiteralPath $zipPath)) {
        Write-RunnerLog "Downloading $($asset.name)."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
    }

    Write-RunnerLog "Extracting runner package."
    Expand-Archive -LiteralPath $zipPath -DestinationPath $RunnerDir -Force
}

Write-RunnerLog "Configuring runner '$RunnerName' for $RepoUrl with labels: $Labels"
& (Join-Path $RunnerDir "config.cmd") `
    --url $RepoUrl `
    --token $Token `
    --name $RunnerName `
    --labels $Labels `
    --work "_work" `
    --unattended `
    --replace

if ($LASTEXITCODE -ne 0) {
    throw "config.cmd failed with exit code $LASTEXITCODE"
}

Write-RunnerLog "Runner configured in $RunnerDir."

if ($Start) {
    Write-RunnerLog "Starting runner in the background."
    Start-Process -FilePath (Join-Path $RunnerDir "run.cmd") -WorkingDirectory $RunnerDir -WindowStyle Hidden
}
else {
    Write-RunnerLog "Start it with: $RunnerDir\\run.cmd"
}
