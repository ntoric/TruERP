#Requires -Version 5.1
<#
.SYNOPSIS
  Prepare TruERP desktop assets and build a Windows NSIS installer with Wails.
#>
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RootDir

$env:Path = "$(go env GOPATH)\bin;$env:Path"

if (-not (Get-Command wails -ErrorAction SilentlyContinue)) {
  Write-Error "wails CLI not found. Install with: go install github.com/wailsapp/wails/v2/cmd/wails@latest"
}

Write-Host "==> Preparing Next.js standalone UI"
bash ./scripts/prepare-frontend.sh
if ($LASTEXITCODE -ne 0) { throw "prepare-frontend.sh failed" }

Write-Host "==> Preparing Windows runtime bundle"
bash ./scripts/prepare-bundle.sh windows-x64
if ($LASTEXITCODE -ne 0) { throw "prepare-bundle.sh failed" }

Write-Host "==> go mod tidy"
go mod tidy

$Platform = if ($args.Count -gt 0) { $args[0] } else { "windows/amd64" }
Write-Host "==> Building Wails app for $Platform"
wails build -platform $Platform -nsis -clean

$BinDir = Join-Path $RootDir "build\bin"
if (Test-Path $BinDir) {
  Write-Host "==> Copying runtime bundle beside executable(s)"
  Copy-Item -Path (Join-Path $RootDir "bundle\*") -Destination $BinDir -Recurse -Force
}

Write-Host "Build complete. Output: $BinDir"
