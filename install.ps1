$ErrorActionPreference = 'Stop'

$Repo   = "3tio/3t-mcp-releases"
$Binary = "stt-cli"
$Target = "x86_64-pc-windows-msvc"

$Release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
$Version = $Release.tag_name

$InstallDir = "$env:LOCALAPPDATA\Programs\$Binary"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$ArchiveName  = "$Binary-$Target.zip"
$Url          = "https://github.com/$Repo/releases/download/$Version/$ArchiveName"
$ChecksumsUrl = "https://github.com/$Repo/releases/download/$Version/checksums.txt"
$ZipPath      = "$env:TEMP\$ArchiveName"
$ChecksumsPath = "$env:TEMP\$Binary-checksums.txt"

Write-Host "Downloading $Binary $Version..."
Invoke-WebRequest -Uri $Url -OutFile $ZipPath
Invoke-WebRequest -Uri $ChecksumsUrl -OutFile $ChecksumsPath

Write-Host "Verifying checksum..."
$ExpectedLine = Get-Content $ChecksumsPath | Where-Object { $_ -match [regex]::Escape($ArchiveName) }
if (-not $ExpectedLine) {
    Remove-Item $ZipPath, $ChecksumsPath -ErrorAction SilentlyContinue
    Write-Error "error: $ArchiveName not found in checksums.txt"
    exit 1
}
$Expected = ($ExpectedLine -split '\s+')[0].ToLower()
$Actual   = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLower()

if ($Actual -ne $Expected) {
    Remove-Item $ZipPath, $ChecksumsPath -ErrorAction SilentlyContinue
    Write-Error "checksum mismatch for ${ArchiveName}`n  expected: $Expected`n  actual:   $Actual"
    exit 1
}

Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
Remove-Item $ZipPath, $ChecksumsPath

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    Write-Host "Installed to $InstallDir\$Binary.exe"
    Write-Host "Restart your terminal for PATH changes to take effect."
} else {
    Write-Host "Installed to $InstallDir\$Binary.exe"
}
