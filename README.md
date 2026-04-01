# SakuraWallpaper

A lightweight video and image wallpaper application for macOS.

[Chinese Documentation](README_CN.md)

## Features

- Set videos (MP4, MOV, GIF) or images (PNG, JPG, HEIC, WebP) as desktop wallpaper
- Multi-display support with independent wallpaper per screen
- Video wallpaper with automatic loop playback
- Recent wallpapers history for quick switching
- Launch at login support
- Pause and resume wallpaper playback
- Bilingual interface (English / Chinese)

## Supported Formats

**Video**
- MP4, MOV, M4V
- GIF (animated)

**Image**
- PNG, JPG, JPEG
- HEIC
- WebP, BMP, TIFF

## Installation

### Download

Download the latest `SakuraWallpaper.dmg` from [Releases](../../releases) and drag SakuraWallpaper to Applications folder.

### Build from Source

```
git clone https://github.com/yueseqaz/SakuraWallpaper.git
cd SakuraWallpaper
./build.sh
open build/SakuraWallpaper.app
```

Requirements: macOS 12.0+, Xcode Command Line Tools

## Usage

1. Click **Choose Wallpaper** to select a video or image file
2. Use the screen dropdown to switch between displays
3. Click **Apply to All** to set the same wallpaper on all screens
4. Click **Stop Wallpaper** to remove wallpaper from selected screen
5. Right-click the status bar icon for more options

### Status Bar Menu

- **Open SakuraWallpaper** - Open main window
- **Pause All** - Pause/resume all wallpapers
- **Pause Screen** - Pause/resume individual screens
- **Recent Wallpapers** - Quick switch to previous wallpapers
- **Language** - Switch between English and Chinese
- **Clear History** - Clear wallpaper history

## Fix "App is Damaged" Error

If you see "SakuraWallpaper is damaged and can't be opened", run this command in Terminal:

```
xattr -cr /Applications/SakuraWallpaper.app
```

This removes the quarantine attribute that macOS applies to apps downloaded from the internet.

## System Requirements

- macOS 12.0 Monterey or later
- Supports multiple displays

## Project Structure

```
SakuraWallpaper/
├── AppDelegate.swift          # App lifecycle and status bar
├── MainWindowController.swift # Main window UI
├── WallpaperManager.swift     # Wallpaper playback engine
├── ScreenPlayer.swift         # Individual screen player
├── SettingsManager.swift      # User preferences storage
├── Localization.swift         # Localization helper
├── MediaType.swift            # File type detection
├── AboutWindowController.swift # About window
├── main.swift                 # Entry point
├── build.sh                   # Build script
├── AppIcon.icns               # App icon
├── Resources/
│   ├── en.lproj/              # English strings
│   └── zh-Hans.lproj/         # Chinese strings
├── README.md                  # English documentation
├── README_CN.md               # Chinese documentation
├── LICENSE                    # MIT License
└── .gitignore                 # Git ignore rules
```

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

Made with love by sakura
