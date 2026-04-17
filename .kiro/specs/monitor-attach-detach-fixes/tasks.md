# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Mission Control Spaces Wallpaper Inconsistency
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior — it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the Mission Control spaces bug before implementing any fix
  - **Manual Testing Approach**: Since this involves Mission Control spaces and AppKit functionality, write manual reproduction steps:
    - Create multiple Mission Control spaces on a display
    - Set a wallpaper using SakuraWallpaper
    - Switch to a different Mission Control space
    - Verify that the wallpaper is NOT consistent across spaces (this FAILS on unfixed code — only the active space gets the wallpaper)
    - Document the counterexample: e.g., "Space 1 shows the set wallpaper, Space 2 shows default macOS wallpaper"
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Existing Functionality Unchanged
  - **IMPORTANT**: Follow observation-first methodology — run UNFIXED code with non-buggy inputs first, observe outputs, then encode those observations as tests
  - **Manual Testing Approach**: Verify existing functionality works correctly on unfixed code:
    - Single space displays: observe that wallpaper setting works normally when only one Mission Control space exists
    - Wallpaper rotation: observe that automatic wallpaper rotation continues to work
    - Pause/resume: observe that pause and resume functionality is unaffected
    - Monitor operations: observe that all existing monitor attach/detach fixes (Bugs 1-7) continue to work
    - Verify tests PASS on unfixed code (confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 3. Implement Mission Control spaces wallpaper fix

  - [x] 3.1 Add space switch notification handling
    - Register for `NSWorkspace.activeSpaceDidChangeNotification` in the WallpaperManager initializer
    - Implement `spaceDidChange()` method to handle Mission Control space switches
    - _Bug_Condition: `isBugCondition(input)` where multiple Mission Control spaces exist and user switches between them_
    - _Expected_Behavior: Wallpaper synchronization is triggered on every space switch_
    - _Preservation: No impact on existing functionality (Requirements 3.1, 3.2, 3.3)_
    - _Requirements: 2.1_

  - [x] 3.2 Implement space switch synchronization
    - Modify `spaceDidChange()` to call `syncCurrentWallpaperToSystemDesktop()` on every space switch
    - This re-applies the current wallpaper to the newly active space using standard `NSWorkspace.shared.setDesktopImageURL`
    - Over time, as user switches between spaces, all spaces get synchronized with the current wallpaper
    - Uses only public, stable macOS APIs - no private API dependencies
    - _Bug_Condition: `isBugCondition(input)` where wallpaper is inconsistent across Mission Control spaces_
    - _Expected_Behavior: Wallpaper is gradually synchronized across all spaces as user switches between them_
    - _Preservation: Uses standard APIs, maintains full compatibility (Requirement 3.2)_
    - _Requirements: 2.1, 3.2_

  - [x] 3.3 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Mission Control Spaces Wallpaper Consistency
    - **IMPORTANT**: Re-run the SAME test from task 1 — do NOT write a new test
    - The manual test from task 1 encodes the expected behavior for the Mission Control spaces bug
    - Re-run the manual reproduction steps:
      - Create multiple Mission Control spaces on a display
      - Set a wallpaper using SakuraWallpaper
      - Switch to different Mission Control spaces multiple times
      - **EXPECTED OUTCOME**: Wallpaper gradually becomes consistent across ALL spaces as you switch between them (confirms bug is fixed)
    - **NOTE**: The fix works through gradual synchronization - each space switch applies the current wallpaper to that space
    - _Requirements: 2.1_

  - [x] 3.4 Verify preservation tests still pass
    - **Property 2: Preservation** - Existing Functionality Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Re-run the manual verification steps:
      - Single space displays: verify wallpaper setting still works normally
      - Wallpaper rotation: verify automatic rotation is unaffected
      - Pause/resume: verify functionality is preserved
      - Monitor operations: verify all existing fixes continue to work
      - **EXPECTED OUTCOME**: All tests PASS (confirms no regressions)
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 4. Integration testing and verification
  - Test Mission Control spaces consistency across different scenarios:
    - Multiple spaces on single display: verify wallpaper consistency
    - Mixed configuration (one display with multiple spaces, another with single space): verify correct behavior on both
    - Private API failure simulation: verify graceful fallback to current behavior
    - Space switching performance: verify no visual glitches or crashes during rapid space switching
  - Verify all existing functionality remains intact:
    - All monitor attach/detach fixes (Bugs 1-7) continue to work
    - Wallpaper rotation, shuffle, and folder mode are unaffected
    - Pause/resume and battery management work correctly
    - UI interactions and screen picker functionality are preserved
  - Ensure all tests pass; ask the user if questions arise
