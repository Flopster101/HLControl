param (
    [switch]$Release,
    [switch]$Help
)

if ($Help) {
    Write-Host "Usage: .\scripts\build_windows.ps1 [-Release]"
    exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
Set-Location $RootDir

$Version = (Get-Content pubspec.yaml | Select-String "^version:\s*(\S+)").Matches.Groups[1].Value.Split('+')[0]
if (-not $Version) { $Version = "0.1.0" }

$GitHash = (git rev-parse --short HEAD 2>$null)
if (-not $GitHash) { $GitHash = "unknown" }
$GitBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
if (-not $GitBranch) { $GitBranch = "main" }

Write-Host "========================================="
if ($Release) {
    Write-Host "  Building HLControl Windows [RELEASE: v$Version]"
    $DartDefines = "--dart-define=APP_VERSION=$Version"
    $ZipName = "HLControl-v$Version-windows-x64.zip"
} else {
    Write-Host "  Building HLControl Windows [DEV: v$Version-$GitHash]"
    $DartDefines = "--dart-define=APP_VERSION=$Version --dart-define=GIT_HASH=$GitHash --dart-define=GIT_BRANCH=$GitBranch"
    $ZipName = "HLControl-v$Version-$GitHash-windows-x64.zip"
}
Write-Host "========================================="

if (-not (Test-Path "dist")) {
    New-Item -ItemType Directory -Path "dist" | Out-Null
}

Write-Host "==> Building Flutter Windows release bundle..."
flutter build windows --release ($DartDefines -split ' ')

$OutputDir = "build\windows\x64\runner\Release"
$ZipPath = "dist\$ZipName"

if (Test-Path $OutputDir) {
    Write-Host "==> Packaging into $ZipPath..."
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
        Push-Location $OutputDir
        & tar.exe -a -c -f "$RootDir\$ZipPath" *
        Pop-Location
    } else {
        Compress-Archive -Path "$OutputDir\*" -DestinationPath $ZipPath -Force
    }
    Write-Host "========================================="
    Write-Host "  BUILD SUCCESSFUL"
    Write-Host "  Output: $ZipPath"
    Write-Host "========================================="
}
