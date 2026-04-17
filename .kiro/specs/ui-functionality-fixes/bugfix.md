# Bugfix Requirements Document

## Introduction

This document addresses three critical UI and functionality issues in SakuraWallpaper that affect user experience and accessibility. These bugs impact the core wallpaper synchronization functionality, screen selection usability, and dark mode compatibility. The fixes will ensure proper wallpaper selection behavior, intuitive screen ordering, and full dark mode support.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN user manually selects a wallpaper after selecting a folder AND clicks "Sync All Screens" THEN the system defaults to the first wallpaper in the folder instead of the currently selected wallpaper

1.2 WHEN user views the screen dropdown menu THEN the system displays screens in an inconsistent or confusing order based on `NSScreen.screens.enumerated()` system ordering

1.3 WHEN user switches to dark mode THEN the system displays invisible black text on dark backgrounds in AboutWindow (`appIcon`, `appName`) and MainWindow (`fileNameLabel`, `intervalPrefix`, `inheritSourceLabel`) elements

### Expected Behavior (Correct)

2.1 WHEN user manually selects a wallpaper after selecting a folder AND clicks "Sync All Screens" THEN the system SHALL sync the currently selected/displayed wallpaper across all screens

2.2 WHEN user views the screen dropdown menu THEN the system SHALL display screens in an intuitive order with built-in display first followed by external displays in a consistent arrangement

2.3 WHEN user switches to dark mode THEN the system SHALL display all text elements with appropriate system colors that are visible in both light and dark modes

### Unchanged Behavior (Regression Prevention)

3.1 WHEN user selects a folder without manually selecting a specific wallpaper AND clicks "Sync All Screens" THEN the system SHALL CONTINUE TO use the folder configuration for all screens

3.2 WHEN user operates in single-screen mode THEN the system SHALL CONTINUE TO function normally without screen dropdown ordering affecting functionality

3.3 WHEN user operates in light mode THEN the system SHALL CONTINUE TO display all text elements with proper visibility and contrast

3.4 WHEN user uses "Sync All Screens" with image wallpapers THEN the system SHALL CONTINUE TO apply the wallpaper as system desktop picture correctly

3.5 WHEN user uses "Sync All Screens" with video wallpapers THEN the system SHALL CONTINUE TO snapshot the current frame and apply it as system desktop picture

3.6 WHEN user has different wallpaper settings per screen THEN the system SHALL CONTINUE TO maintain per-screen independence for all other operations except "Sync All Screens"