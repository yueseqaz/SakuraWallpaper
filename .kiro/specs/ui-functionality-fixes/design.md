# UI Functionality Fixes Bugfix Design

## Overview

This design addresses three distinct UI functionality bugs in SakuraWallpaper that affect user experience across different interaction patterns. The bugs involve: (1) the "Sync All Screens" feature incorrectly resetting manually selected wallpapers to folder defaults, (2) screen dropdown menu displaying screens in inconsistent system order rather than logical user-friendly order, and (3) text elements becoming invisible in dark mode due to missing color assignments. The fix strategy involves targeted corrections to preserve existing functionality while resolving the specific defective behaviors.

## Glossary

- **Bug_Condition (C)**: The condition that triggers any of the three UI bugs - sync all screens resetting manual selections, inconsistent screen ordering, or invisible text in dark mode
- **Property (P)**: The desired behavior for each bug condition - sync preserves manual selections, screens display in logical order, text remains visible in all appearance modes
- **Preservation**: All existing wallpaper management, screen detection, and UI functionality that must remain unchanged by the fixes
- **applyToAllScreens()**: The method in `MainWindowController.swift` that synchronizes wallpaper settings across all displays
- **updateScreenMenu()**: The method in `MainWindowController.swift` that populates the screen selection dropdown
- **folderConfig**: The settings property that stores the default wallpaper selection for folder mode
- **currentFile**: The wallpaper manager property that tracks the currently displayed wallpaper for a specific screen
- **NSScreen.screens**: The system array of connected displays that follows internal macOS ordering
- **labelColor/secondaryLabelColor**: The system-provided text colors that automatically adapt to light/dark appearance

## Bug Details

### Bug Condition

The bugs manifest in three distinct scenarios: (1) when using "Sync All Screens" with manually selected wallpapers in folder mode, the function resets all screens to the folder's first item instead of preserving manual selections, (2) when multiple displays are connected, the screen dropdown shows screens in unpredictable system order rather than built-in display first followed by external displays, and (3) when switching to dark mode, several text elements become invisible due to missing dynamic color assignments.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type UIInteractionEvent
  OUTPUT: boolean
  
  RETURN (input.action == "syncAllScreens" AND hasManuallySelectedWallpapers())
         OR (input.action == "openScreenDropdown" AND multipleScreensConnected())
         OR (input.action == "switchToDarkMode" AND hasUncoloredTextElements())
END FUNCTION
```

### Examples

- **Sync All Screens Bug**: User manually selects "sunset.mp4" on Screen 1 in folder mode, then clicks "Sync All Screens" → all screens reset to "beach.mp4" (first item) instead of "sunset.mp4"
- **Screen Ordering Bug**: MacBook Pro with external monitor connected → dropdown shows "External Display" first, then "Built-in Display" instead of logical built-in first order
- **Dark Mode Text Bug**: User switches to dark mode → app name in About window, file name label in main window, and interval prefix text become invisible (black text on dark background)
- **Edge Case**: Sync all screens with no manual selection should continue using folder config as expected

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- All existing wallpaper playback and rotation functionality must continue to work exactly as before
- Screen detection and multi-display support must remain unchanged
- Folder mode default behavior (when no manual selection exists) must continue working
- All other UI elements and interactions must remain unaffected
- Light mode appearance and functionality must remain unchanged

**Scope:**
All inputs that do NOT involve the three specific bug conditions should be completely unaffected by these fixes. This includes:
- Normal wallpaper selection and playback operations
- Single screen configurations and operations
- Light mode usage and all existing color schemes
- Menu interactions not involving screen selection or sync operations

## Hypothesized Root Cause

Based on the bug description and code analysis, the root causes are:

1. **Incorrect Source Selection in Sync**: The `applyToAllScreens()` method always uses `SettingsManager.shared.folderConfig(for: sourceScreen)` which returns the folder's default first item, ignoring that the user may have manually navigated to a different wallpaper via `wallpaperManager.currentFile`

2. **System-Dependent Screen Ordering**: The `updateScreenMenu()` method uses `NSScreen.screens.enumerated()` which follows macOS internal ordering that can vary based on connection sequence and system configuration, rather than a predictable user-friendly order

3. **Missing Dynamic Color Assignments**: Several NSTextField elements in both `MainWindowController.swift` and `AboutWindowController.swift` lack `.textColor` assignments, causing them to use default black text that becomes invisible against dark backgrounds

4. **Incomplete Dark Mode Support**: The UI was designed primarily for light mode, and dark mode support was added without comprehensive text color auditing across all interface elements

## Correctness Properties

Property 1: Bug Condition - UI Functionality Fixes

_For any_ UI interaction where one of the three bug conditions holds (sync with manual selections, screen dropdown with multiple displays, or dark mode text visibility), the fixed functions SHALL preserve manual wallpaper selections during sync, display screens in logical built-in-first order, and maintain text visibility in all appearance modes.

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Preservation - Non-Buggy UI Behavior

_For any_ UI interaction that does NOT involve the three specific bug conditions (normal wallpaper operations, single screen usage, light mode usage), the fixed code SHALL produce exactly the same behavior as the original code, preserving all existing wallpaper management, screen detection, and interface functionality.

**Validates: Requirements 3.1, 3.2, 3.3**

## Fix Implementation

### Changes Required

Based on the root cause analysis and provided technical details:

**File**: `MainWindowController.swift`

**Function**: `applyToAllScreens()` (lines ~258-270)

**Specific Changes**:
1. **Manual Selection Detection**: Before using `folderConfig(for: sourceScreen)`, check if the source screen has a manually selected wallpaper by comparing `wallpaperManager.currentFile` with the folder config default
   - If manual selection exists, use `wallpaperManager.currentFile` as the sync source
   - If no manual selection (currentFile matches folder config), continue using folder config as before

2. **Screen Ordering Logic**: In `updateScreenMenu()` method (lines ~226-250)
   - Replace `NSScreen.screens.enumerated()` with a sorted array
   - Sort with built-in display first (identified by `NSScreen.main` or display characteristics)
   - Follow with external displays sorted by name or connection order for consistency

3. **Text Color Assignments**: Add dynamic color assignments to affected NSTextField elements
   - `appIcon` label (line ~163): Add `.textColor = .labelColor`
   - `fileNameLabel` (line ~406): Add `.textColor = .labelColor`
   - `intervalPrefix` (line ~491): Add `.textColor = .secondaryLabelColor`
   - `inheritSourceLabel` (line ~530): Add `.textColor = .secondaryLabelColor`

**File**: `AboutWindowController.swift`

**Function**: Window setup/viewDidLoad equivalent

**Specific Changes**:
4. **About Window Text Color**: Add color assignment to `appName` label (line ~35)
   - Add `.textColor = .labelColor` for proper dark mode visibility

5. **Color Selection Strategy**: Use `.labelColor` for primary text elements and `.secondaryLabelColor` for secondary/descriptive text to follow macOS design guidelines

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bugs on unfixed code, then verify the fixes work correctly and preserve existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bugs BEFORE implementing the fixes. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write tests that simulate the three bug scenarios and assert the expected correct behavior. Run these tests on the UNFIXED code to observe failures and understand the root causes.

**Test Cases**:
1. **Sync All Screens Test**: Set up folder mode with manual wallpaper selection, trigger sync all screens, verify it preserves manual selection (will fail on unfixed code)
2. **Screen Ordering Test**: Connect multiple displays, open screen dropdown, verify built-in display appears first (will fail on unfixed code)
3. **Dark Mode Text Test**: Switch to dark mode, verify all text elements remain visible with proper contrast (will fail on unfixed code)
4. **Edge Case Test**: Sync all screens with no manual selection, verify it uses folder config correctly (should pass on unfixed code)

**Expected Counterexamples**:
- Sync all screens resets manually selected wallpapers to folder defaults
- Screen dropdown shows external displays before built-in display
- Text elements become invisible or have poor contrast in dark mode
- Possible causes: incorrect source selection logic, system-dependent ordering, missing color assignments

### Fix Checking

**Goal**: Verify that for all inputs where the bug conditions hold, the fixed functions produce the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := fixedUIFunctions(input)
  ASSERT expectedBehavior(result)
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug conditions do NOT hold, the fixed functions produce the same result as the original functions.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT originalUIFunctions(input) = fixedUIFunctions(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the UI interaction domain
- It catches edge cases that manual unit tests might miss
- It provides strong guarantees that behavior is unchanged for all non-buggy interactions

**Test Plan**: Observe behavior on UNFIXED code first for normal wallpaper operations, single screen usage, and light mode interactions, then write property-based tests capturing that behavior.

**Test Cases**:
1. **Normal Wallpaper Operations**: Observe that regular wallpaper selection, playback, and rotation work correctly on unfixed code, then write tests to verify this continues after fixes
2. **Single Screen Usage**: Observe that single display configurations work correctly on unfixed code, then write tests to verify this continues after fixes
3. **Light Mode Functionality**: Observe that all light mode interactions work correctly on unfixed code, then write tests to verify this continues after fixes

### Unit Tests

- Test sync all screens logic with various manual selection states
- Test screen ordering with different display configurations
- Test text color assignments in both light and dark modes
- Test edge cases (no screens, single screen, no manual selections)

### Property-Based Tests

- Generate random display configurations and verify screen ordering consistency
- Generate random wallpaper selection states and verify sync behavior preservation
- Test appearance mode switching across many UI states to verify text visibility

### Integration Tests

- Test full sync all screens workflow with multiple displays and manual selections
- Test screen dropdown behavior with various display connection/disconnection scenarios
- Test appearance mode switching with full UI interaction flows to verify visual consistency