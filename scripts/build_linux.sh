#!/usr/bin/env bash
set -e

# Resolve script directory and change to repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

BUILD_TAR=true
BUILD_ARCH=false
BUILD_APPIMAGE=false
IS_RELEASE=false

for arg in "$@"; do
    case "$arg" in
        --all)
            BUILD_TAR=true
            BUILD_ARCH=true
            BUILD_APPIMAGE=true
            ;;
        --arch)
            BUILD_ARCH=true
            ;;
        --appimage)
            BUILD_APPIMAGE=true
            ;;
        --tar)
            BUILD_TAR=true
            ;;
        --release|-r)
            IS_RELEASE=true
            ;;
        --help|-h)
            echo "Usage: $0 [--all] [--arch] [--appimage] [--tar] [--release]"
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
    echo "  Building HLControl Linux [RELEASE: v${VERSION}]"
    DART_DEFINES="--dart-define=APP_VERSION=${VERSION}"
    TAR_NAME="hlcontrol-v${VERSION}-linux-x64.tar.gz"
else
    echo "  Building HLControl Linux [DEV: v${VERSION}-${GIT_HASH}]"
    DART_DEFINES="--dart-define=APP_VERSION=${VERSION} --dart-define=GIT_HASH=${GIT_HASH} --dart-define=GIT_BRANCH=${GIT_BRANCH}"
    TAR_NAME="hlcontrol-v${VERSION}-${GIT_HASH}-linux-x64.tar.gz"
fi
echo "========================================="

# 1. Build Flutter Linux release bundle
echo "==> Building Flutter Linux release bundle..."
flutter build linux --release $DART_DEFINES

DIST_DIR="${ROOT_DIR}/dist"
mkdir -p "${DIST_DIR}"

# 2. Package generic tarball
if [ "$BUILD_TAR" = true ]; then
    echo "==> Packaging standalone archive: dist/${TAR_NAME}..."
    tar -czf "${DIST_DIR}/${TAR_NAME}" -C build/linux/x64/release/bundle .
fi

EXTRA_FLAGS=""
if [ "$IS_RELEASE" = true ]; then
    EXTRA_FLAGS="--release"
fi

# 3. Build Arch package
if [ "$BUILD_ARCH" = true ]; then
    "${SCRIPT_DIR}/build_arch.sh" $EXTRA_FLAGS
fi

# 4. Build AppImage
if [ "$BUILD_APPIMAGE" = true ]; then
    "${SCRIPT_DIR}/build_appimage.sh" $EXTRA_FLAGS
fi

echo "========================================="
echo "  BUILD SUCCESSFUL"
if [ "$BUILD_TAR" = true ]; then
    echo "  - Tarball: dist/${TAR_NAME}"
fi
echo "========================================="
