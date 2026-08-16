#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

IS_RELEASE=false
BUILD_BUNDLE=false
BUILD_UNIVERSAL=false

for arg in "$@"; do
    case "$arg" in
        --release|-r)
            IS_RELEASE=true
            ;;
        --bundle|-b)
            BUILD_BUNDLE=true
            ;;
        --universal|-u)
            BUILD_UNIVERSAL=true
            ;;
        --help|-h)
            echo "Usage: $0 [--release] [--bundle] [--universal]"
            echo "  (no args)        : Build Split-per-ABI Debug APKs (default)"
            echo "  --release, -r    : Build optimized, stripped, signed Release APKs (split by default)"
            echo "  --bundle, -b     : Build Release Android App Bundle (.aab)"
            echo "  --universal, -u  : Build monolithic fat APK containing all CPU architectures"
            exit 0
            ;;
    esac
done

VERSION=$(grep '^version:' pubspec.yaml | head -n1 | awk '{print $2}' | cut -d'+' -f1)
[ -z "$VERSION" ] && VERSION="0.1.0"
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

DIST_DIR="${ROOT_DIR}/dist"
mkdir -p "${DIST_DIR}"

if [ "$IS_RELEASE" = true ] || [ "$BUILD_BUNDLE" = true ]; then
    echo "========================================="
    echo "  Building Android [RELEASE: v${VERSION}]"
    echo "========================================="

    # Strip symbols and obfuscate for maximum size reduction
    OPT_FLAGS="--dart-define=APP_VERSION=${VERSION} --obfuscate --split-debug-info=build/symbols"

    if [ "$BUILD_BUNDLE" = true ]; then
        echo "==> Building Release Android App Bundle (.aab)..."
        flutter build appbundle --release $OPT_FLAGS
        OUTPUT_NAME="HLControl-v${VERSION}.aab"
        cp build/app/outputs/bundle/release/app-release.aab "${DIST_DIR}/${OUTPUT_NAME}"
        echo "========================================="
        echo "  App Bundle ready: dist/${OUTPUT_NAME}"
        echo "========================================="
    elif [ "$BUILD_UNIVERSAL" = true ]; then
        echo "==> Building Monolithic Universal Release APK..."
        flutter build apk --release $OPT_FLAGS
        OUTPUT_NAME="HLControl-v${VERSION}-universal.apk"
        cp build/app/outputs/flutter-apk/app-release.apk "${DIST_DIR}/${OUTPUT_NAME}"
        echo "========================================="
        echo "  Universal Release APK ready: dist/${OUTPUT_NAME}"
        echo "========================================="
    else
        echo "==> Building Split-per-ABI Release APKs..."
        flutter build apk --release --split-per-abi $OPT_FLAGS
        echo "========================================="
        for abi in arm64-v8a armeabi-v7a x86_64; do
            if [ -f "build/app/outputs/flutter-apk/app-${abi}-release.apk" ]; then
                OUT_APK="HLControl-v${VERSION}-${abi}.apk"
                cp "build/app/outputs/flutter-apk/app-${abi}-release.apk" "${DIST_DIR}/${OUT_APK}"
                echo "  - APK (${abi}): dist/${OUT_APK}"
            fi
        done
        echo "========================================="
    fi
else
    echo "========================================="
    echo "  Building Android [DEBUG: v${VERSION}-${GIT_HASH}]"
    echo "========================================="
    DART_DEFINES="--dart-define=APP_VERSION=${VERSION} --dart-define=GIT_HASH=${GIT_HASH} --dart-define=GIT_BRANCH=${GIT_BRANCH}"

    if [ "$BUILD_UNIVERSAL" = true ]; then
        echo "==> Building Monolithic Universal Debug APK..."
        flutter build apk --debug $DART_DEFINES
        OUTPUT_NAME="HLControl-v${VERSION}-${GIT_HASH}-universal-debug.apk"
        cp build/app/outputs/flutter-apk/app-debug.apk "${DIST_DIR}/${OUTPUT_NAME}"
        echo "========================================="
        echo "  Universal Debug APK ready: dist/${OUTPUT_NAME}"
        echo "========================================="
    else
        echo "==> Building Split-per-ABI Debug APKs..."
        flutter build apk --debug --split-per-abi $DART_DEFINES
        echo "========================================="
        for abi in arm64-v8a armeabi-v7a x86_64; do
            if [ -f "build/app/outputs/flutter-apk/app-${abi}-debug.apk" ]; then
                OUT_APK="HLControl-v${VERSION}-${GIT_HASH}-${abi}-debug.apk"
                cp "build/app/outputs/flutter-apk/app-${abi}-debug.apk" "${DIST_DIR}/${OUT_APK}"
                echo "  - APK (${abi}): dist/${OUT_APK}"
            fi
        done
        echo "========================================="
    fi
fi
