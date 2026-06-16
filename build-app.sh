#!/usr/bin/env bash
#
# Builds NiCoLpy and packages it into a runnable .app bundle.
#
# Usage:
#   ./build-app.sh            # debug build
#   ./build-app.sh release    # optimized build
#
set -euo pipefail

CONFIG="${1:-debug}"
APP_NAME="NiCoLpy"
BUNDLE_ID="com.paymentiq.nicolpy"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "==> Building ($CONFIG)..."
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
    echo "Error: built binary not found at $BIN_PATH" >&2
    exit 1
fi

APP_DIR="$ROOT/build/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

echo "==> Assembling bundle at $APP_DIR ..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"

# App icon, if present.
if [[ -f "$ROOT/AppIcon.icns" ]]; then
    cp "$ROOT/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi

# Ad-hoc code signature so macOS lets it run and the Accessibility / Login Item
# permissions stick to a stable identity.
echo "==> Code signing (ad-hoc)..."
codesign --force --deep --sign - \
    --identifier "$BUNDLE_ID" \
    "$APP_DIR" >/dev/null 2>&1 || {
        echo "Warning: ad-hoc codesign failed; app may still run." >&2
    }

echo ""
echo "Done. Launch with:"
echo "  open \"$APP_DIR\""
echo ""
echo "First run: grant Accessibility permission when prompted"
echo "(System Settings -> Privacy & Security -> Accessibility)"
echo "so Cmd+Shift+V auto-paste works."
