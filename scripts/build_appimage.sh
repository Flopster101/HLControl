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

VERSION=$(grep '^version:' pubspec.yaml | head -n1 | awk '{print $2}' | cut -d'+' -f1)
[ -z "$VERSION" ] && VERSION="0.1.0"
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

echo "========================================="
if [ "$IS_RELEASE" = true ]; then
    echo "  Building HLControl AppImage [RELEASE: v${VERSION}]"
    DART_DEFINES="--dart-define=APP_VERSION=${VERSION}"
    OUTPUT_NAME="HLControl-v${VERSION}-x86_64.AppImage"
else
    echo "  Building HLControl AppImage [DEV: v${VERSION}-${GIT_HASH}]"
    DART_DEFINES="--dart-define=APP_VERSION=${VERSION} --dart-define=GIT_HASH=${GIT_HASH} --dart-define=GIT_BRANCH=${GIT_BRANCH}"
    OUTPUT_NAME="HLControl-v${VERSION}-${GIT_HASH}-x86_64.AppImage"
fi
echo "========================================="

# 1. Build Flutter Linux release bundle with dart-defines
echo "==> Building Flutter Linux bundle..."
flutter build linux --release $DART_DEFINES

DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${ROOT_DIR}/build/AppDir"

mkdir -p "${DIST_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/usr/bin"

# 2. Copy Flutter bundle into AppDir
echo "==> Constructing AppDir structure..."
cp -r build/linux/x64/release/bundle/. "${APP_DIR}/usr/bin/"

# 3. Copy desktop file and icons
cp packaging/linux/com.flopster101.hlcontrol.desktop "${APP_DIR}/"
cp packaging/linux/com.flopster101.hlcontrol.png "${APP_DIR}/"
cp packaging/linux/com.flopster101.hlcontrol.png "${APP_DIR}/.DirIcon"

# 4. Create AppRun entrypoint
cat << 'EOF' > "${APP_DIR}/AppRun"
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/usr/bin/hlcontrol" "$@"
EOF
chmod +x "${APP_DIR}/AppRun"

# 5. Acquire appimagetool if not in PATH
APPIMAGETOOL="$(which appimagetool 2>/dev/null || true)"
if [ -z "$APPIMAGETOOL" ]; then
    CACHE_TOOL="/tmp/appimagetool-x86_64.AppImage"
    if [ ! -f "$CACHE_TOOL" ]; then
        echo "==> Downloading appimagetool..."
        curl -fsSL -o "$CACHE_TOOL" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x "$CACHE_TOOL"
    fi
    APPIMAGETOOL="$CACHE_TOOL"
fi

# 6. Generate AppImage
echo "==> Generating AppImage with ${APPIMAGETOOL}..."
ARCH=x86_64 "$APPIMAGETOOL" "${APP_DIR}" "${DIST_DIR}/${OUTPUT_NAME}"

echo "========================================="
echo "  AppImage generated successfully!"
echo "  - File: dist/${OUTPUT_NAME}"
echo "========================================="
