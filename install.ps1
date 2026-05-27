$ErrorActionPreference = 'Stop'

$Repo   = "3tio/3t-mcp-releases"
$Binary = "stt-cli"
$Target = "x86_64-pc-windows-msvc"

$Release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
$Version = $Release.tag_name

$InstallDir = "$env:LOCALAPPDATA\Programs\$Binary"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$ArchiveName   = "$Binary-$Target.zip"
$Url           = "https://github.com/$Repo/releases/download/$Version/$ArchiveName"
$ChecksumsUrl  = "https://github.com/$Repo/releases/download/$Version/checksums.txt"
$TmpDir        = New-Item -ItemType Directory -Path "$env:TEMP\$Binary-install-$([System.Guid]::NewGuid())" -Force
$ZipPath       = "$TmpDir\$ArchiveName"
$ChecksumsPath = "$TmpDir\checksums.txt"

try {
    Write-Host "Downloading $Binary $Version..."
    Invoke-WebRequest -Uri $Url -OutFile $ZipPath
    Invoke-WebRequest -Uri $ChecksumsUrl -OutFile $ChecksumsPath

    Write-Host "Verifying checksum..."
    $ExpectedLine = Get-Content $ChecksumsPath | Where-Object {
        $cols = $_ -split '\s+'
        $cols.Count -ge 2 -and $cols[1] -eq $ArchiveName
    }
    if (-not $ExpectedLine) {
        throw "$ArchiveName not found in checksums.txt"
    }
    if (@($ExpectedLine).Count -gt 1) {
        throw "multiple entries for $ArchiveName in checksums.txt"
    }
    $Expected = ($ExpectedLine -split '\s+')[0].ToLower()
    $Actual   = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLower()
    if ($Actual -ne $Expected) {
        throw "checksum mismatch for ${ArchiveName}`n  expected: $Expected`n  actual:   $Actual"
    }

    Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
} finally {
    Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    Write-Host "Installed to $InstallDir\$Binary.exe"
    Write-Host "Restart your terminal for PATH changes to take effect."
} else {
    Write-Host "Installed to $InstallDir\$Binary.exe"
}
