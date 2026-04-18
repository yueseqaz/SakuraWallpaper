#!/bin/bash
#
# SakuraWallpaper — Total Reset
# Kills the running app, deletes all persisted state, and cleans temp files.
# On the next launch the app will behave as a fresh install (onboarding, etc.).
#

set -euo pipefail

APP_NAME="SakuraWallpaper"
BUNDLE_ID="com.sakura.wallpaper"

echo "🌸 SakuraWallpaper — Total Reset"
echo "================================="

# 1. Kill the running app (if any)
if pgrep -xq "$APP_NAME"; then
    echo "⏹  Stopping $APP_NAME..."
    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

# 2. Delete UserDefaults (the plist that stores all settings & screen registry)
PLIST="$HOME/Library/Preferences/${BUNDLE_ID}.plist"
if [ -f "$PLIST" ]; then
    echo "🗑  Removing UserDefaults plist: $PLIST"
    rm -f "$PLIST"
else
    echo "ℹ️  No UserDefaults plist found (already clean)"
fi

# Also flush the defaults cache so macOS doesn't resurrect stale values
defaults delete "$BUNDLE_ID" 2>/dev/null || true

# 3. Delete transient lock-screen snapshots from /tmp
TMPDIR_SAKURA="${TMPDIR}SakuraWallpaper"
if [ -d "$TMPDIR_SAKURA" ]; then
    echo "🗑  Removing temp snapshots: $TMPDIR_SAKURA"
    rm -rf "$TMPDIR_SAKURA"
else
    echo "ℹ️  No temp snapshots found"
fi

# 4. Remove login item (in case launch-at-login was enabled)
if command -v sfltool &>/dev/null; then
    sfltool resetbtm 2>/dev/null || true
fi

# 5. Remove Saved Application State (window positions, etc.)
SAVED_STATE="$HOME/Library/Saved Application State/${BUNDLE_ID}.savedState"
if [ -d "$SAVED_STATE" ]; then
    echo "🗑  Removing saved app state: $SAVED_STATE"
    rm -rf "$SAVED_STATE"
fi

# 6. Remove any Container data (if sandboxed)
CONTAINER="$HOME/Library/Containers/${BUNDLE_ID}"
if [ -d "$CONTAINER" ]; then
    echo "🗑  Removing sandbox container: $CONTAINER"
    rm -rf "$CONTAINER"
fi

echo ""
echo "✅ Reset complete. Next launch will be a fresh start."
