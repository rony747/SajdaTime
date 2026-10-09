#!/bin/bash
# ---------------------------------------------------------------------------
# Builds PrayerBar without SwiftPM's build system.
#
# Why not `swift build`? SwiftPM drives either xcbuild or llbuild, and both are
# blocked from writing their state files in this environment (the file sandbox
# denies the build daemon, and the XCBuild service cannot write to this volume).
# Invoking swiftc directly produces the same artefacts with no daemon involved.
#
# Package.swift is still maintained so the project opens normally in Xcode.
#
# Usage:  ./build.sh [debug|release]      (default: release)
# Output: .build/bin/prayerbarctl         verification CLI
#         dist/PrayerBar.app              the application bundle
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
APP="$DIST/PrayerBar.app"

mkdir -p "$LIB" "$BIN" "$DIST"

# The sandbox blocks Swift's default module cache, so point it inside the tree.
export CLANG_MODULE_CACHE_PATH="$BUILD/modulecache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

# -disable-sandbox is required: swiftc wraps macro plugin servers in
# sandbox-exec, and a nested sandbox cannot be applied from inside this one.
SDK="$(xcrun --sdk macosx --show-sdk-path)"
TARGET="arm64-apple-macosx26.0"

echo "==> Building PrayerCore ($CONFIG)"
swiftc -disable-sandbox -parse-as-library "${OPT[@]}" -target "$TARGET" -sdk "$SDK" \
    -emit-module -emit-library -static -module-name PrayerCore \
    -emit-module-path "$LIB/PrayerCore.swiftmodule" \
    -o "$LIB/libPrayerCore.a" \
    Sources/PrayerCore/*.swift

echo "==> Building prayerbarctl"
swiftc -disable-sandbox -parse-as-library "${OPT[@]}" -target "$TARGET" -sdk "$SDK" \
    -I "$LIB" -o "$BIN/prayerbarctl" \
    Sources/PrayerBarCtl/*.swift "$LIB/libPrayerCore.a"

echo "==> Building PrayerBar app binary"
swiftc -disable-sandbox -parse-as-library "${OPT[@]}" -target "$TARGET" -sdk "$SDK" \
    -I "$LIB" -o "$BIN/PrayerBar" \
    Sources/PrayerBarApp/*.swift "$LIB/libPrayerCore.a"

echo "==> Assembling app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/PrayerBar" "$APP/Contents/MacOS/PrayerBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc signature: enough for local use (notifications, location, keychain-free).
/usr/bin/codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 \
    && echo "    signed (ad-hoc)" \
    || echo "    WARNING: ad-hoc signing failed; the app will still run unsigned"

echo
echo "Done."
echo "  CLI : $BIN/prayerbarctl"
echo "  App : $APP"
