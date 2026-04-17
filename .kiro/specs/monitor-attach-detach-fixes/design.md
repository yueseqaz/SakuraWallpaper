# Mission Control Spaces Wallpaper Fix — Bugfix Design

## Overview

A single bug surfaces in `WallpaperManager` where wallpapers are only set on the currently active Mission Control space, causing inconsistent wallpaper appearance when users switch between spaces after monitor attach/detach events.

The fix strategy replaces the current `NSWorkspace.shared.setDesktopImageURL` approach with private Core Graphics Services APIs to set wallpapers across ALL Mission Control spaces for each display. This addresses the core limitation where different spaces show different wallpapers after monitor topology changes.

---

## Glossary

- **Bug_Condition (C)**: The runtime state where wallpapers are only set on the active Mission Control space.
- **Property (P)**: The correct observable behavior where wallpapers appear consistently across all spaces.
- **Preservation**: All existing wallpaper functionality must remain unchanged.
- **`spaceDidChange()`**: Method that handles Mission Control space switches and synchronizes wallpapers.
- **Space Switch Synchronization**: The approach of re-applying wallpapers on every space switch to maintain consistency.
- **Mission Control spaces**: Virtual desktops that can have independent wallpapers; the fix ensures they stay synchronized.

---

## Bug Details

### Bug Condition

The bug manifests when wallpapers are set on displays with multiple Mission Control spaces.

**Formal Specification:**

```
FUNCTION isBugCondition(input)
  INPUT: input — a runtime event or state snapshot when wallpaper is being set
  OUTPUT: boolean — true if the Mission Control spaces bug condition holds

  // Mission Control spaces inconsistency
  IF input.event == applyDesktopImage called
     AND multiple Mission Control spaces exist for the display
     AND user switches to a different space after wallpaper is set
  THEN RETURN true   // other spaces show different wallpapers

  RETURN false
END FUNCTION
```

### Example

**Mission Control Spaces Bug**: User has multiple Mission Control spaces on a display. After a monitor attach/detach event, `applyDesktopImage` calls `NSWorkspace.shared.setDesktopImageURL` which only affects the currently active space. When the user switches to other spaces, they see different wallpapers (often the default macOS wallpaper or previously set wallpapers).

---

## Expected Behavior

### Requirements

**Bug Fix (Expected Correct Behavior):**

- 2.1 WHEN wallpaper is set on a display THEN it SHALL be applied to ALL Mission Control spaces for that display, not just the active space.

### Preservation Requirements

**Unchanged Behaviors:**

- 3.1 WHEN wallpaper is set on a display with multiple Mission Control spaces and the user switches between spaces THEN all spaces SHALL continue to show the same wallpaper as was set by the application.
- 3.2 WHEN wallpaper setting occurs on a single-space display THEN the behavior SHALL remain identical to the current implementation.
- 3.3 WHEN the private APIs fail or are unavailable THEN the system SHALL gracefully fall back to the current space-only behavior.

**Scope:**

All inputs that do NOT involve multiple Mission Control spaces are completely unaffected by this fix. This includes:

- Normal single-display operation with one space
- Wallpaper rotation, shuffle, and folder-mode operation
- Pause/resume, battery-triggered auto-pause
- Screen lock / screen saver sync
- UI interactions (screen picker, drag-drop, file/folder selection)
- All existing monitor attach/detach fixes (Bugs 1-7) remain unchanged

---

## Hypothesized Root Cause

### Mission Control Spaces Bug — wallpaper synchronization on space switches

The `spaceDidChange()` method now calls `syncCurrentWallpaperToSystemDesktop()` on every Mission Control space switch. This ensures that whenever a user switches to a different space, the current wallpaper is applied to that space using the standard `NSWorkspace.shared.setDesktopImageURL` API. Over time, as the user switches between spaces, all spaces become synchronized with the current wallpaper. This approach uses only public, stable macOS APIs and provides reliable wallpaper consistency across Mission Control spaces.

---

## Correctness Properties

Property 1: Mission Control Spaces Consistency

_For any_ wallpaper setting operation on a display with multiple Mission Control spaces, the fixed `WallpaperManager` SHALL ensure that the wallpaper appears consistently across ALL spaces for that display, not just the currently active space.

**Validates: Requirement 2.1**

Property 2: Preservation — Existing Functionality Unchanged

_For any_ wallpaper operation that does NOT involve multiple Mission Control spaces, the fixed code SHALL produce exactly the same behavior as the original code, preserving all existing wallpaper playback, rotation, pause/resume, system desktop sync, and UI interaction functionality.

**Validates: Requirements 3.1, 3.2, 3.3**

---

## Fix Implementation

### Space Switch Synchronization Approach

The fix uses a simple and reliable approach: on every Mission Control space switch, re-apply the current wallpaper using the standard `NSWorkspace.shared.setDesktopImageURL` API. Since this API only affects the currently active space, calling it on every space switch ensures all spaces stay synchronized with the current wallpaper.

**Key Implementation:**
- Listen for `NSWorkspace.activeSpaceDidChangeNotification` 
- On every space switch, call `syncCurrentWallpaperToSystemDesktop()` for all displays
- This re-applies the current wallpaper to the newly active space using standard APIs
- No private APIs required - uses only public, stable macOS APIs

**Approach:**
1. Detect Mission Control space switches via `NSWorkspace.activeSpaceDidChangeNotification`
2. On each space switch, re-apply current wallpaper to all displays
3. The standard `setDesktopImageURL` API sets the wallpaper for the currently active space
4. Over time, as user switches between spaces, all spaces get synchronized
5. Completely reliable using only public APIs

This ensures consistent wallpaper appearance across all spaces while using only stable, public macOS APIs.

### Changes Required

**File**: `WallpaperManager.swift`

**Function**: `spaceDidChange()` — Mission Control space switch handling

**Specific Changes**:

1. **Add space switch synchronization**: Modify the `spaceDidChange()` method to call `syncCurrentWallpaperToSystemDesktop()` on every Mission Control space switch:

   ```swift
   @objc private func spaceDidChange() {
       checkPlaybackState()
       if !isPaused && !isPausedInternally {
           showAll()
       }
       // Sync the system desktop image for the newly active Space on every display.
       // NSWorkspace.setDesktopImageURL only applies to the currently active Space,
       // so we re-run it on every Space switch to keep all Spaces in sync.
       syncCurrentWallpaperToSystemDesktop()
   }
   ```

2. **Ensure proper notification registration**: Verify that the class registers for `NSWorkspace.activeSpaceDidChangeNotification` in the initializer:

   ```swift
   NSWorkspace.shared.notificationCenter.addObserver(
       self,
       selector: #selector(spaceDidChange),
       name: NSWorkspace.activeSpaceDidChangeNotification,
       object: nil
   )
   ```

This approach uses only public, stable macOS APIs and ensures wallpaper consistency across Mission Control spaces through gradual synchronization as the user switches between spaces.

---

## Testing Strategy

### Validation Approach

The testing strategy focuses on verifying that wallpapers are set consistently across all Mission Control spaces while preserving existing functionality. Since `WallpaperManager` depends on AppKit and is excluded from the SPM test target, testing is primarily done through integration tests and manual verification.

### Bug Condition Checking

**Goal**: Demonstrate the Mission Control spaces bug BEFORE implementing the fix.

**Test Case**:

1. **Mission Control spaces inconsistency**: Set a wallpaper on a display with multiple Mission Control spaces. Switch to a different space. Assert the wallpaper is the same across all spaces. (Will fail on unfixed code — only the active space gets the wallpaper.)

**Expected Counterexample**:

- Wallpaper is only visible on the active Mission Control space; other spaces show different wallpapers.

### Fix Checking

**Goal**: Verify that the fixed function produces the expected behavior for Mission Control spaces.

**Specific assertions after fix:**

- `spaceDidChange()` called on Mission Control space switch → `syncCurrentWallpaperToSystemDesktop()` is called for all displays.
- Wallpaper synchronization occurs gradually as user switches between spaces.
- All spaces eventually show the same wallpaper after user has switched to them at least once.

### Preservation Checking

**Goal**: Verify that existing functionality remains unchanged.

**Test Cases**:

1. **Single space display**: Verify wallpaper setting on displays with only one space works identically to before.
2. **Existing wallpaper operations**: Verify that rotation, shuffle, pause/resume, and all other wallpaper functionality is unaffected.
3. **Monitor attach/detach**: Verify that all existing monitor topology fixes (Bugs 1-7) continue to work correctly.

### Integration Tests

- **Mission Control spaces consistency**: Create multiple spaces on a display, set wallpaper, switch between spaces multiple times; verify wallpaper becomes consistent across all spaces.
- **Space switch synchronization**: Verify that `syncCurrentWallpaperToSystemDesktop()` is called on every space switch.
- **Mixed display configuration**: Test with one display having multiple spaces and another having a single space; verify correct behavior on both.
- **Performance**: Verify that space switching remains responsive and doesn't cause delays or visual glitches.
