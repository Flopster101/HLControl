#!/usr/bin/env bash
set -e

LOG_FILE="/tmp/hlcontrol-win-build.log"
exec > >(tee -i "$LOG_FILE") 2>&1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

IS_RELEASE=false
PROVISION=false
CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --release|-r)
            IS_RELEASE=true
            ;;
        --provision|-p)
            PROVISION=true
            ;;
        --clean|-c)
            CLEAN=true
            ;;
        --help|-h)
            echo "Usage: $0 [--release] [--provision] [--clean]"
            echo "  (no args)        : Build Dev Release package with git hash (default)"
            echo "  --release, -r    : Build Clean Release package without git hash"
            echo "  --provision, -p  : Force Vagrant VM provisioning"
            echo "  --clean, -c      : Destroy existing VM domain before building"
            exit 0
            ;;
    esac
done

VERSION=$(grep '^version:' pubspec.yaml | head -n1 | awk '{print $2}' | cut -d'+' -f1)
[ -z "$VERSION" ] && VERSION="0.1.0"
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

echo "========================================="
if [ "$IS_RELEASE" = true ]; then
    echo "  Building HLControl Windows [RELEASE: v${VERSION}]"
    DART_DEFINES="--dart-define=APP_VERSION=${VERSION}"
    ZIP_NAME="HLControl-v${VERSION}-windows-x64.zip"
    SETUP_BASE="HLControl-v${VERSION}-windows-x64-setup"
else
    echo "  Building HLControl Windows [DEV: v${VERSION}-${GIT_HASH}]"
    DART_DEFINES="--dart-define=APP_VERSION=${VERSION} --dart-define=GIT_HASH=${GIT_HASH} --dart-define=GIT_BRANCH=${GIT_BRANCH}"
    ZIP_NAME="HLControl-v${VERSION}-${GIT_HASH}-windows-x64.zip"
    SETUP_BASE="HLControl-v${VERSION}-${GIT_HASH}-windows-x64-setup"
fi
echo "========================================="

mkdir -p dist

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "==> Detected native Windows host. Building with Flutter..."
    flutter build windows --release $DART_DEFINES
    
    OUTPUT_DIR="build/windows/x64/runner/Release"
    if [ -d "$OUTPUT_DIR" ]; then
        cd "$OUTPUT_DIR"
        zip -r "${ROOT_DIR}/dist/${ZIP_NAME}" *
        cd "${ROOT_DIR}"

        ISCC_PATH="/c/Program Files (x86)/Inno Setup 6/ISCC.exe"
        if [ -f "$ISCC_PATH" ]; then
            "$ISCC_PATH" "/DAppVersion=${VERSION}" "/DAppArch=x64" "/DBuildDir=${ROOT_DIR}/${OUTPUT_DIR}" "/DOutputDir=${ROOT_DIR}/dist" "/DOutputBaseFilename=${SETUP_BASE}" "${ROOT_DIR}/packaging/windows/inno_setup.iss"
        fi

        echo "========================================="
        echo "  BUILD SUCCESSFUL"
        echo "  - ZIP Package: dist/${ZIP_NAME}"
        if [ -f "${ROOT_DIR}/dist/${SETUP_BASE}.exe" ]; then
            echo "  - Installer:   dist/${SETUP_BASE}.exe"
        fi
        echo "========================================="
    fi
else
    echo "==> Detected Linux host. Invoking Vagrant KVM/libvirt Windows builder..."
    
    if ! command -v vagrant &>/dev/null; then
        echo "Error: vagrant is not installed. Please install vagrant and vagrant-libvirt."
        exit 1
    fi

    export VAGRANT_DEFAULT_PROVIDER="libvirt"

    if [ "$CLEAN" = true ]; then
        echo "==> Cleaning existing VM domain..."
        vagrant destroy -f || true
    fi

    PROVISION_FLAG=""
    if [ "$PROVISION" = true ]; then
        PROVISION_FLAG="--provision"
    fi

    echo "==> Starting Vagrant VM (provider: libvirt)..."
    if command -v virsh &>/dev/null; then
        STATE=$(virsh --connect qemu:///system domstate HLControl_default 2>/dev/null || echo "not found")
        if [ "$STATE" = "shut off" ]; then
            virsh --connect qemu:///system start HLControl_default 2>/dev/null || true
        fi
    fi
    vagrant up --provider=libvirt $PROVISION_FLAG

    echo "==> Waiting for Windows VM and WinRM readiness..."
    for i in {1..30}; do
        if vagrant winrm -c "Write-Host 'Ready'" &>/dev/null; then
            break
        fi
        sleep 2
    done

    echo "==> Archiving workspace..."
    SRC_ZIP="/tmp/hlcontrol_src_$$.zip"
    rm -f "$SRC_ZIP"
    zip -rq "$SRC_ZIP" . -x "*.git*" "*build*" "*.vagrant*" "*.dart_tool*" "*dist*"

    echo "==> Uploading source archive to Windows VM..."
    vagrant upload "$SRC_ZIP" "C:\\hlcontrol_src.zip"
    rm -f "$SRC_ZIP"

    echo "==> Extracting source code inside Windows VM..."
    vagrant winrm -c "if (Test-Path 'C:\vagrant') { Remove-Item 'C:\vagrant' -Recurse -Force }; New-Item -ItemType Directory -Path 'C:\vagrant' -Force | Out-Null; Expand-Archive -Path 'C:\hlcontrol_src.zip' -DestinationPath 'C:\vagrant' -Force; Remove-Item 'C:\hlcontrol_src.zip' -Force"

    echo "==> Running 'flutter build windows --release' inside VM..."
    vagrant winrm -c "\$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \$env:DART_VM_OPTIONS = '--old_gen_heap_size=2048'; cd C:\vagrant; flutter build windows --release ${DART_DEFINES} 2>&1"

    echo "==> Packaging build output inside VM..."
    vagrant winrm -c "
        New-Item -ItemType Directory -Path C:\vagrant\dist -Force | Out-Null
        Set-Location 'C:\vagrant\build\windows\x64\runner\Release'
        & tar.exe -a -c -f 'C:\vagrant\dist\\${ZIP_NAME}' *

        \$IsccPath = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
        if (-not (Test-Path \$IsccPath)) {
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                choco install -y innosetup --no-progress
            }
        }
        if (Test-Path \$IsccPath) {
            Write-Host '==> Compiling Inno Setup installer...'
            & \$IsccPath '/DAppVersion=${VERSION}' '/DAppArch=x64' '/DBuildDir=C:\vagrant\build\windows\x64\runner\Release' '/DOutputDir=C:\vagrant\dist' '/DOutputBaseFilename=${SETUP_BASE}' 'C:\vagrant\packaging\windows\inno_setup.iss'
        }

        if (Test-Path 'C:\vagrant\artifacts.zip') { Remove-Item 'C:\vagrant\artifacts.zip' -Force }
        Compress-Archive -Path 'C:\vagrant\dist\*' -DestinationPath 'C:\vagrant\artifacts.zip' -Force
    "

    echo "==> Pulling artifacts to host dist/..."
    rm -f "/tmp/hlcontrol_artifacts.zip"

    (
        for i in {1..25}; do
            GUEST_IP=$(virsh --connect qemu:///system domifaddr HLControl_default 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "")
            if [ -n "$GUEST_IP" ]; then
                nc -w 2 "$GUEST_IP" 8080 > "/tmp/hlcontrol_artifacts.zip" 2>/dev/null || true
                if [ -s "/tmp/hlcontrol_artifacts.zip" ]; then break; fi
            fi
            nc -w 2 127.0.0.1 58080 > "/tmp/hlcontrol_artifacts.zip" 2>/dev/null || true
            if [ -s "/tmp/hlcontrol_artifacts.zip" ]; then break; fi
            sleep 1
        done
    ) &
    PULL_PID=$!

    vagrant winrm -c "
        netsh advfirewall firewall add rule name='ArtifactServer' dir=in action=allow protocol=TCP localport=8080 2>&1 | Out-Null
        \$l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, 8080)
        \$l.Start()
        \$sw = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not \$l.Pending() -and \$sw.ElapsedMilliseconds -lt 25000) {
            Start-Sleep -Milliseconds 200
        }
        if (\$l.Pending()) {
            \$c = \$l.AcceptTcpClient()
            \$s = \$c.GetStream()
            \$f = [System.IO.File]::OpenRead('C:\vagrant\artifacts.zip')
            \$f.CopyTo(\$s)
            \$f.Close()
            \$s.Flush()
            \$s.Close()
            \$c.Close()
        }
        \$l.Stop()
    " 2>/dev/null || true

    wait "$PULL_PID" 2>/dev/null || true

    if [ ! -s "/tmp/hlcontrol_artifacts.zip" ]; then
        echo "==> Falling back to WinRM transfer..."
        vagrant winrm -c "[Convert]::ToBase64String([System.IO.File]::ReadAllBytes('C:\vagrant\artifacts.zip'), [System.Base64FormattingOptions]::InsertLineBreaks)" | tr -d '\r\n ' | base64 -d > "/tmp/hlcontrol_artifacts.zip"
    fi

    echo "==> Halting Vagrant VM..."
    vagrant halt

    if [ -s "/tmp/hlcontrol_artifacts.zip" ]; then
        unzip -o -q "/tmp/hlcontrol_artifacts.zip" -d "dist"
        rm -f "/tmp/hlcontrol_artifacts.zip"
        echo "========================================="
        echo "  BUILD SUCCESSFUL"
        echo "  - ZIP Package: dist/${ZIP_NAME}"
        if [ -f "dist/${SETUP_BASE}.exe" ]; then
            echo "  - Installer:   dist/${SETUP_BASE}.exe"
        fi
        echo "========================================="
    fi
fi
