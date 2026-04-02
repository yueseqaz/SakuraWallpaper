#!/bin/bash

APP_NAME="SakuraWallpaper"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

# 清理
rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 编译
echo "Compiling..."
swiftc -o "$APP_DIR/Contents/MacOS/$APP_NAME" \
    SettingsManager.swift \
    MediaType.swift \
    Localization.swift \
    ScreenPlayer.swift \
    WallpaperManager.swift \
    MainWindowController.swift \
    AboutWindowController.swift \
    AppDelegate.swift \
    main.swift \
    -framework Cocoa -framework AVKit -framework AVFoundation -framework ServiceManagement

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
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
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
    mkdir -p "$DMG_TMP"
    cp -R "$APP_DIR" "$DMG_TMP/"
    cp AppIcon.icns "$DMG_TMP/.VolumeIcon.icns"

    # 卸载可能残留的同名卷
    hdiutil detach "/Volumes/$APP_NAME" 2>/dev/null
    hdiutil detach "/Volumes/$APP_NAME 1" 2>/dev/null

    # 创建可写 DMG
    hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TMP" -ov -format UDRW -fs HFS+ "${APP_NAME}_rw.dmg" > /dev/null 2>&1

    # 挂载并设置卷图标 + 创建 Applications 别名（带图标）
    MOUNT_POINT=$(hdiutil attach "${APP_NAME}_rw.dmg" -nobrowse -noverify 2>&1 | grep -o '/Volumes/.*')
    SetFile -a C "$MOUNT_POINT"
    SetFile -c icnC "$MOUNT_POINT/.VolumeIcon.icns"
    osascript -e "
        tell application \"Finder\"
            tell disk \"$APP_NAME\"
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set the bounds of container window to {100, 100, 600, 420}
                set position of item \"$APP_NAME.app\" of container window to {120, 160}
                make new alias file at container window to POSIX file \"/Applications\" with properties {name:\"Applications\"}
                set position of item \"Applications\" of container window to {360, 160}
                close
                open
                update without registering applications
                delay 1
                close
            end tell
        end tell
    " 2>/dev/null
    hdiutil detach "$MOUNT_POINT" > /dev/null 2>&1

    # 转换为压缩只读 DMG
    hdiutil convert "${APP_NAME}_rw.dmg" -format UDZO -o "$APP_NAME.dmg" > /dev/null 2>&1
    rm -f "${APP_NAME}_rw.dmg"
    rm -rf "$DMG_TMP"
    echo "Done! DMG: $APP_NAME.dmg"
fi
