#!/bin/bash

APP_NAME="SakuraWallpaper"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DEFAULT_APP_VERSION="1.0.1"
APP_VERSION="${APP_VERSION:-$DEFAULT_APP_VERSION}"

# 清理
rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 编译为通用二进制 (Universal Binary)
# 同时支持 Apple Silicon (arm64) 和 Intel (x86_64) Mac
# 使用 -target + -sdk 而不是 -arch，因为 -arch 需要完整 Xcode，
# 而 -target 在仅有 Command Line Tools 的环境下也能交叉编译

SOURCES=(
    Screen_Config.swift
    SettingsManager.swift
    WallpaperBehavior.swift
    MediaType.swift
    PlaylistBuilder.swift
    AsyncWorkLimiter.swift
    Localization.swift
    PerformanceMonitor.swift
    ScreenPlayer.swift
    WallpaperManager.swift
    MainWindowController.swift
    ThumbnailItem.swift
    ThumbnailProvider.swift
    AboutWindowController.swift
    AppDelegate.swift
    main.swift
)

FRAMEWORKS=(
    -framework Cocoa
    -framework AVKit
    -framework AVFoundation
    -framework ServiceManagement
    -framework ImageIO
    -framework IOKit
)

SDK_PATH=$(xcrun --show-sdk-path)
DEPLOYMENT_TARGET="12.0"
BINARY="$APP_DIR/Contents/MacOS/$APP_NAME"

echo "Compiling for arm64 (Apple Silicon)..."
swiftc -target arm64-apple-macosx"$DEPLOYMENT_TARGET" -sdk "$SDK_PATH" \
    -o "${BINARY}_arm64" \
    "${SOURCES[@]}" \
    "${FRAMEWORKS[@]}"

echo "Compiling for x86_64 (Intel)..."
swiftc -target x86_64-apple-macosx"$DEPLOYMENT_TARGET" -sdk "$SDK_PATH" \
    -o "${BINARY}_x86_64" \
    "${SOURCES[@]}" \
    "${FRAMEWORKS[@]}"

echo "Creating universal binary..."
lipo -create -output "$BINARY" \
    "${BINARY}_arm64" \
    "${BINARY}_x86_64"

rm "${BINARY}_arm64" "${BINARY}_x86_64"

echo "Verifying universal binary..."
lipo -info "$BINARY"

# 代码签名 (ad-hoc) — 让 macOS TCC 能够在多次启动之间识别应用，
# 避免每次启动都重复弹出下载文件夹访问权限提示
echo "Code signing..."
codesign --sign - --entitlements SakuraWallpaper.entitlements --force --deep "$APP_DIR"

# 复制资源
cp -R Resources "$APP_DIR/Contents/"

# 复制图标
cp AppIcon.icns "$APP_DIR/Contents/Resources/"

# 创建 Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.sakura.wallpaper</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$APP_VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Done! App: $APP_DIR"

# 打包 DMG（传入 dmg 参数）
if [ "$1" = "dmg" ]; then
    echo "Creating DMG..."
    DMG_TMP="dmg_tmp"
    rm -rf "$DMG_TMP" "$APP_NAME.dmg"

    # 压缩背景图
    python3 -c "
from PIL import Image
img = Image.open('bg.jpg')
img = img.resize((500, 320), Image.LANCZOS)
img.save('bg.png', optimize=True)
"

    # 准备内容
    mkdir -p "$DMG_TMP"
    cp -R "$APP_DIR" "$DMG_TMP/"

    # 用 create-dmg 打包（需 brew install create-dmg）
    create-dmg \
      --volname "$APP_NAME" \
      --volicon "AppIcon.icns" \
      --background "bg.png" \
      --window-pos 100 100 \
      --window-size 500 320 \
      --icon-size 80 \
      --icon "$APP_NAME.app" 130 160 \
      --hide-extension "$APP_NAME.app" \
      --app-drop-link 360 160 \
      "$APP_NAME.dmg" \
      "$DMG_TMP" 2>&1 | grep -v "hdiutil does not support"

    rm -f bg.png
    rm -rf "$DMG_TMP"
    echo "Done! DMG: $APP_NAME.dmg"
fi
