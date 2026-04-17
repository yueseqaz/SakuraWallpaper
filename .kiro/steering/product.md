# SakuraWallpaper — Product Overview

SakuraWallpaper is a lightweight macOS menu-bar app (v1.0.1) that lets users set videos or images as animated desktop wallpapers. It runs as an accessory-policy app (no Dock icon) and is controlled entirely through a status bar icon (🌸).

## Core Capabilities

- **Media support**: MP4, MOV, M4V, GIF (video); PNG, JPG, JPEG, HEIC, WebP, BMP, TIFF (image)
- **Rotation mode**: Automatically cycles through a folder of wallpapers at a configurable interval
- **Per-screen independence**: Each display has its own folder path, playlist, interval, and shuffle state
- **System desktop sync**: Images are applied directly as the system desktop picture; videos snapshot the current frame on wallpaper change, screen lock, or screen saver start
- **Shuffle mode**: Randomized rotation order that avoids immediate repeats
- **Low-battery auto-pause**: Pauses playback when battery ≤ 20% and not charging
- **Multi-display support**: Independent wallpaper per screen with "Sync All Screens" option
- **Recent history**: Quick-switch to previous wallpapers/folders (capped at 10 entries)
- **Launch at login**: Registers via `SMAppService`
- **Bilingual UI**: English and Simplified Chinese, switchable at runtime

## Target Platform

macOS 12.0 (Monterey) or later. Distributed as a `.dmg` or via Homebrew cask.
