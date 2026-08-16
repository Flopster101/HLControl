Set-ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "==> Configuring WinRM memory limits & pagefile..."
Set-Item -Path WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 4096 -Force -ErrorAction SilentlyContinue
Set-Item -Path WSMan:\localhost\Plugin\Microsoft.PowerShell\Quotas\MaxMemoryPerShellMB -Value 4096 -Force -ErrorAction SilentlyContinue

try {
    $System = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
    $System.AutomaticManagedPagefile = $false
    $System.Put() | Out-Null
    Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name="C:\pagefile.sys"; InitialSize=4096; MaximumSize=8192} -ErrorAction SilentlyContinue | Out-Null
} catch {}

Write-Host "==> Ensuring Windows Server features are active..."
Install-WindowsFeature Net-Framework-Core -ErrorAction SilentlyContinue | Out-Null
Install-WindowsFeature Net-Framework-45-Core -ErrorAction SilentlyContinue | Out-Null

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing Chocolatey..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host "==> Installing Git, Flutter SDK & Inno Setup..."
choco install -y git --no-progress
choco install -y flutter --no-progress
choco install -y innosetup --no-progress

Write-Host "==> Installing Visual Studio 2022 C++ Build Tools & Windows SDK..."
$vsInstallerUrl = "https://aka.ms/vs/17/release/vs_BuildTools.exe"
$vsInstallerPath = "$env:TEMP\vs_BuildTools.exe"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
(New-Object System.Net.WebClient).DownloadFile($vsInstallerUrl, $vsInstallerPath)
Start-Process -FilePath $vsInstallerPath -ArgumentList "--quiet", "--wait", "--norestart", "--nocache", "--add", "Microsoft.VisualStudio.Workload.VCTools", "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "--add", "Microsoft.VisualStudio.Component.Windows10SDK.19041", "--add", "Microsoft.VisualStudio.Component.VC.CMake.Project" -Wait
Remove-Item $vsInstallerPath -Force -ErrorAction SilentlyContinue

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "==> Configuring Flutter for Windows Desktop..."
$env:DART_VM_OPTIONS = "--old_gen_heap_size=2048"
try {
    flutter config --enable-windows-desktop
    flutter precache --windows
} catch {}

netsh advfirewall firewall add rule name="ArtifactServer" dir=in action=allow protocol=TCP localport=8080 2>&1 | Out-Null
