$ErrorActionPreference = 'Stop'

$Repo   = "3tio/3t-mcp-releases"
$Binary = "stt-cli"
$Target = "x86_64-pc-windows-msvc"

$Release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
$Version = $Release.tag_name

$InstallDir = "$env:LOCALAPPDATA\Programs\$Binary"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$Url     = "https://github.com/$Repo/releases/download/$Version/$Binary-$Target.zip"
$ZipPath = "$env:TEMP\$Binary-$Version.zip"

Write-Host "Downloading $Binary $Version..."
Invoke-WebRequest -Uri $Url -OutFile $ZipPath
Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
Remove-Item $ZipPath

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    Write-Host "Installed to $InstallDir\$Binary.exe"
    Write-Host "Restart your terminal for PATH changes to take effect."
} else {
    Write-Host "Installed to $InstallDir\$Binary.exe"
}
