#!/bin/bash
# ---------------------------------------------------------------------------
# Builds SajdaTime without SwiftPM's build system.
#
# Why not `swift build`? SwiftPM drives either xcbuild or llbuild, and both are
# blocked from writing their state files in this environment (the file sandbox
# denies the build daemon, and the XCBuild service cannot write to this volume).
# Invoking swiftc directly produces the same artefacts with no daemon involved.
#
# Package.swift is still maintained so the project opens normally in Xcode.
#
# Usage:  ./build.sh [debug|release]      (default: release)
# Output: .build/bin/sajdactl         verification CLI
#         dist/Sajda Time.app             the application bundle
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
case "$CONFIG" in
    debug)   OPT=(-Onone -g) ;;
    release) OPT=(-O) ;;
    *) echo "usage: $0 [debug|release]" >&2; exit 2 ;;
esac

BUILD="$ROOT/.build"
LIB="$BUILD/lib"
BIN="$BUILD/bin"
DIST="$ROOT/dist"
APP="$DIST/Sajda Time.app"

mkdir -p "$LIB" "$BIN" "$DIST"

# The sandbox blocks Swift's default module cache, so point it inside the tree.
export CLANG_MODULE_CACHE_PATH="$BUILD/modulecache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

# -disable-sandbox is required: swiftc wraps macro plugin servers in
# sandbox-exec, and a nested sandbox cannot be applied from inside this one.
SDK="$(xcrun --sdk macosx --show-sdk-path)"
TARGET="arm64-apple-macosx26.0"

echo "==> Building SajdaCore ($CONFIG)"
swiftc -disable-sandbox -parse-as-library "${OPT[@]}" -target "$TARGET" -sdk "$SDK" \
    -emit-module -emit-library -static -module-name SajdaCore \
    -emit-module-path "$LIB/SajdaCore.swiftmodule" \
    -o "$LIB/libSajdaCore.a" \
    Sources/SajdaCore/*.swift

echo "==> Building sajdactl"
swiftc -disable-sandbox -parse-as-library "${OPT[@]}" -target "$TARGET" -sdk "$SDK" \
    -I "$LIB" -o "$BIN/sajdactl" \
    Sources/SajdaTimeCtl/*.swift "$LIB/libSajdaCore.a"

echo "==> Building SajdaTime app binary"
swiftc -disable-sandbox -parse-as-library "${OPT[@]}" -target "$TARGET" -sdk "$SDK" \
    -I "$LIB" -o "$BIN/SajdaTime" \
    Sources/SajdaTimeApp/*.swift "$LIB/libSajdaCore.a"

echo "==> Assembling app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/SajdaTime" "$APP/Contents/MacOS/SajdaTime"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# The version lives in ./VERSION and is stamped in here, so the bundle cannot
# drift from the release the way it did: About was reporting 1.0.0 through
# several tagged releases because the plist was never bumped by hand.
VERSION="$(cat VERSION 2>/dev/null || echo 0.0.0)"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist" >/dev/null
echo "    version: $VERSION (build $BUILD_NUMBER)"

# A tag that disagrees with VERSION is the exact drift this is meant to stop.
HEAD_TAG="$(git describe --tags --exact-match HEAD 2>/dev/null || true)"
if [ -n "$HEAD_TAG" ] && [ "${HEAD_TAG#v}" != "$VERSION" ]; then
    echo "    WARNING: HEAD is tagged $HEAD_TAG but VERSION says $VERSION"
fi
# In-app artwork, loaded by name from Contents/Resources.
for asset in appicon banner logo logo-dark; do
    if [ -f "Resources/Assets/$asset.png" ]; then
        cp "Resources/Assets/$asset.png" "$APP/Contents/Resources/$asset.png"
    fi
done

# Full-screen reminder backdrops, one per prayer.
for prayer in fajr dhuhr asr maghrib isha; do
    if [ -f "Resources/Assets/alert-$prayer.jpg" ]; then
        cp "Resources/Assets/alert-$prayer.jpg" "$APP/Contents/Resources/alert-$prayer.jpg"
    fi
done

# The .icns is generated from the 1024px master rather than committed as a
# binary, so the icon has exactly one source of truth.
if [ -f Resources/Assets/appicon.png ]; then
    ICONSET="$BUILD/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        /usr/bin/sips -z "$size" "$size" Resources/Assets/appicon.png \
            --out "$ICONSET/icon_${size}x${size}.png" >/dev/null 2>&1
        double=$((size * 2))
        /usr/bin/sips -z "$double" "$double" Resources/Assets/appicon.png \
            --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null 2>&1
    done
    if /usr/bin/iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null; then
        echo "    icon: AppIcon.icns generated"
    else
        echo "    WARNING: iconutil failed; the app will use the default icon"
    fi
    rm -rf "$ICONSET"
fi

# Ad-hoc signature: enough for local use (notifications, location, keychain-free).
/usr/bin/codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 \
    && echo "    signed (ad-hoc)" \
    || echo "    WARNING: ad-hoc signing failed; the app will still run unsigned"

echo
echo "Done."
echo "  CLI : $BIN/sajdactl"
echo "  App : $APP"
