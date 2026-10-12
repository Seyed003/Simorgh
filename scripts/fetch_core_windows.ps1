# Downloads the official sing-box Windows binary into windows\core\.
# Usage (PowerShell, from the repository root):
#   powershell -ExecutionPolicy Bypass -File scripts\fetch_core_windows.ps1 [-Arch amd64|arm64]
param(
    [ValidateSet('amd64', 'arm64')]
    [string]$Arch = 'amd64'
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$version = (Get-Content (Join-Path $PSScriptRoot 'core_version.txt')).Trim()
$name = "sing-box-$version-windows-$Arch"
$url = "https://github.com/SagerNet/sing-box/releases/download/v$version/$name.zip"
$dest = Join-Path $root 'windows\core'
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) "$name-$([guid]::NewGuid())"

New-Item -ItemType Directory -Force -Path $dest, $tmp | Out-Null
try {
    Write-Host "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile "$tmp\core.zip" -UseBasicParsing
    Expand-Archive -Path "$tmp\core.zip" -DestinationPath $tmp -Force
    Copy-Item -Force "$tmp\$name\sing-box.exe" "$dest\sing-box.exe"
    & "$dest\sing-box.exe" version
    Write-Host "sing-box $version installed to $dest"
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
