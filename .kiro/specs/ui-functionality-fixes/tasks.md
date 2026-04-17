# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - UI Functionality Bugs
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bugs exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the three UI bugs exist
  - **Scoped PBT Approach**: For deterministic bugs, scope the property to the concrete failing cases to ensure reproducibility
  - Test implementation details from Bug Condition in design:
    - Sync All Screens Bug: Manual wallpaper selection gets reset to folder default instead of being preserved
    - Screen Ordering Bug: External displays appear before built-in display in dropdown menu
    - Dark Mode Text Bug: Text elements become invisible due to missing color assignments
  - The test assertions should match the Expected Behavior Properties from design
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bugs exist)
  - Document counterexamples found to understand root cause
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 2.1, 2.2, 2.3_

- [ ] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Buggy UI Behavior
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for non-buggy inputs:
    - Normal wallpaper operations (selection, playback, rotation)
    - Single screen configurations and operations
    - Light mode usage and existing color schemes
    - Menu interactions not involving screen selection or sync operations
  - Write property-based tests capturing observed behavior patterns from Preservation Requirements
  - Property-based testing generates many test cases for stronger guarantees
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3_

- [-] 3. Fix for UI functionality bugs

  - [x] 3.1 Implement applyToAllScreens() fix for manual wallpaper selection preservation
    - Add manual selection detection logic before using folderConfig
    - Check if source screen has manually selected wallpaper by comparing wallpaperManager.currentFile with folder config default
    - If manual selection exists, use wallpaperManager.currentFile as sync source
    - If no manual selection (currentFile matches folder config), continue using folder config as before
    - _Bug_Condition: isBugCondition(input) where input.action == "syncAllScreens" AND hasManuallySelectedWallpapers()_
    - _Expected_Behavior: expectedBehavior(result) - sync preserves manual selections from design_
    - _Preservation: All existing wallpaper management functionality from design_
    - _Requirements: 2.1, 3.1_

  - [x] 3.2 Implement updateScreenMenu() fix for logical screen ordering
    - Replace NSScreen.screens.enumerated() with sorted array approach
    - Sort with built-in display first (identified by NSScreen.main or display characteristics)
    - Follow with external displays sorted by name or connection order for consistency
    - _Bug_Condition: isBugCondition(input) where input.action == "openScreenDropdown" AND multipleScreensConnected()_
    - _Expected_Behavior: expectedBehavior(result) - screens display in logical built-in-first order from design_
    - _Preservation: All existing screen detection and multi-display support from design_
    - _Requirements: 2.2, 3.2_

  - [x] 3.3 Implement text color assignments for dark mode visibility
    - Add dynamic color assignments to MainWindowController.swift text elements:
      - appIcon label: Add .textColor = .labelColor
      - fileNameLabel: Add .textColor = .labelColor  
      - intervalPrefix: Add .textColor = .secondaryLabelColor
      - inheritSourceLabel: Add .textColor = .secondaryLabelColor
    - Add color assignment to AboutWindowController.swift:
      - appName label: Add .textColor = .labelColor
    - Use .labelColor for primary text, .secondaryLabelColor for secondary/descriptive text
    - _Bug_Condition: isBugCondition(input) where input.action == "switchToDarkMode" AND hasUncoloredTextElements()_
    - _Expected_Behavior: expectedBehavior(result) - text remains visible in all appearance modes from design_
    - _Preservation: Light mode appearance and functionality remain unchanged from design_
    - _Requirements: 2.3, 3.3_

  - [ ] 3.4 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - UI Functionality Fixes
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bugs are fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [ ] 3.5 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Buggy UI Behavior
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all tests still pass after fix (no regressions)

- [ ] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.