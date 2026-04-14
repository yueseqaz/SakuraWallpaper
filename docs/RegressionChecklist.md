# SakuraWallpaper Regression Checklist

## Multi-Display Hot-Plug
1. Connect external display while app is running and wallpaper is active.
2. Verify wallpaper appears on the new display within 3 seconds.
3. Unplug external display and verify app does not crash and remaining displays keep wallpaper.
4. Reconnect and verify per-screen pause status can still be toggled.

## Sleep/Wake Recovery
1. Start video wallpaper on all screens.
2. Put Mac to sleep for at least 30 seconds.
3. Wake Mac and verify status switches from paused(auto) back to playing when desktop is active.
4. Verify manual pause remains paused after wake.

## Spaces/Desktop Switching
1. Enable Battery Saver (`pauseWhenInvisible`) and start playback.
2. Switch to a fullscreen app and verify state becomes paused(auto).
3. Return to desktop/Finder and verify playback resumes.
4. Disable Battery Saver and repeat to confirm playback stays active.

## Folder Mode + Rotation
1. Enable folder mode with at least 5 media files.
2. Toggle `Include Subfolders` on/off and verify file count updates correctly.
3. Enable shuffle and verify immediate repeats are minimized.
4. Trigger `Next Wallpaper` from menu and verify transition succeeds across all screens.

## UI/Status Messaging
1. Manually pause playback and verify status text shows manual pause wording.
2. Trigger auto pause by leaving desktop and verify status text shows battery saver pause wording.
3. Verify onboarding appears only for first-time users with no prior setup.
