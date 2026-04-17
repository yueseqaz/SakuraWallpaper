# Mission Control Spaces Wallpaper Fix — Bugfix Requirements

## Introduction

SakuraWallpaper has a bug where wallpapers are only set on the currently active Mission Control space, causing inconsistent wallpaper appearance when users switch between spaces. This creates a poor user experience where the wallpaper appears to "not stick" when switching spaces, particularly noticeable after monitor attach/detach events.

## Bug Analysis

### Current Behavior (Defect)

**Mission Control Spaces Wallpaper Inconsistency**

1.1 WHEN wallpaper is set on a display with multiple Mission Control spaces THEN the system only applies the wallpaper to the currently active space using `NSWorkspace.shared.setDesktopImageURL`

1.2 WHEN the user switches to a different Mission Control space on the same display THEN they see a different wallpaper (often the default macOS wallpaper or a previously set wallpaper) instead of the wallpaper that was just set

### Expected Behavior (Correct)

**Mission Control Spaces Wallpaper Consistency**

2.1 WHEN wallpaper is set on a display THEN the system SHALL apply the wallpaper to ALL Mission Control spaces for that display, ensuring consistent appearance across all spaces

2.2 WHEN the user switches between Mission Control spaces on the same display THEN they SHALL see the same wallpaper on all spaces

### Unchanged Behavior (Regression Prevention)

3.1 WHEN wallpaper is set on a display with only one Mission Control space THEN the system SHALL CONTINUE TO work exactly as before with no behavioral changes

3.2 WHEN the private APIs fail or are unavailable THEN the system SHALL CONTINUE TO fall back gracefully to the current space-only behavior

3.3 WHEN wallpaper rotation, shuffle, pause/resume, or any other existing functionality is used THEN the system SHALL CONTINUE TO work exactly as before
