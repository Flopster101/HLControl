#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

IS_RELEASE=false
for arg in "$@"; do
    case "$arg" in
        --release|-r)
            IS_RELEASE=true
            ;;
    esac
done

export IS_RELEASE="${IS_RELEASE}"

VERSION=$(grep '^version:' pubspec.yaml | head -n1 | awk '{print $2}' | cut -d'+' -f1)
[ -z "$VERSION" ] && VERSION="0.1.0"
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
GIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")

echo "========================================="
if [ "$IS_RELEASE" = true ]; then
    echo "  Building Arch Linux Package [RELEASE: v${VERSION}]"
    DART_DEFINES="--dart-define=APP_VERSION=${VERSION}"
else
    echo "  Building Arch Linux Package [DEV: v${VERSION}.r${GIT_COUNT}.${GIT_HASH}]"
    DART_DEFINES="--dart-define=APP_VERSION=${VERSION} --dart-define=GIT_HASH=${GIT_HASH} --dart-define=GIT_BRANCH=${GIT_BRANCH}"
fi
echo "========================================="

# 1. Build release bundle with dart-defines
echo "==> Building Flutter Linux bundle..."
flutter build linux --release $DART_DEFINES

DIST_DIR="${ROOT_DIR}/dist"
mkdir -p "${DIST_DIR}"

# 2. Run makepkg using local recipe with dynamic pkgver
cd "${ROOT_DIR}/packaging/linux"
makepkg -p PKGBUILD.local -f

# 3. Move resulting package to dist/
mv hlcontrol-*.pkg.tar.zst "${DIST_DIR}/"

echo "========================================="
echo "  Arch package built successfully!"
echo "  - Package: dist/$(ls -t "${DIST_DIR}"/hlcontrol-*.pkg.tar.zst | head -n1 | xargs basename)"
echo "  - Install locally with: sudo pacman -U <path-to-pkg>"
echo "========================================="
