import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var statusMenuItem: NSMenuItem!
    var mainWindow: MainWindowController!
    var wallpaperManager: WallpaperManager!
    var recentMenu: NSMenu!
    var aboutWindow: AboutWindowController?
    var pauseItem: NSMenuItem!
    var pauseMenu: NSMenu!
    var pauseAllItem: NSMenuItem!
    var autoPauseItem: NSMenuItem!
    var nextMenuItem: NSMenuItem!
    var nextWallpaperMenu: NSMenu!
    var languageMenu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        wallpaperManager = WallpaperManager()
        mainWindow = MainWindowController(wallpaperManager: wallpaperManager)
        setupStatusBar()

        SettingsManager.shared.runCleanSlateInitIfNeeded()
        wallpaperManager.restoreAllScreens()
        mainWindow.runOnboardingIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        wallpaperManager.stopAll()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🌸"

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "menu.open".localized, action: #selector(openMain), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        statusMenuItem = NSMenuItem(title: "menu.status".localized("ui.notSet".localized), action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        pauseMenu = NSMenu(title: "menu.pause".localized)
        pauseItem = NSMenuItem(title: "menu.pause".localized, action: nil, keyEquivalent: "")
        pauseItem.submenu = pauseMenu
        menu.addItem(pauseItem)

        nextWallpaperMenu = NSMenu(title: "menu.nextWallpaper".localized)
        nextMenuItem = NSMenuItem(title: "menu.nextWallpaper".localized, action: nil, keyEquivalent: "")
        nextMenuItem.submenu = nextWallpaperMenu
        menu.addItem(nextMenuItem)

        let stopItem = NSMenuItem(title: "menu.stopWallpaper".localized, action: #selector(stopWallpaper), keyEquivalent: "s")
        stopItem.target = self
        menu.addItem(stopItem)

        menu.addItem(.separator())

        autoPauseItem = NSMenuItem(title: "menu.autoPause".localized, action: #selector(toggleAutoPause), keyEquivalent: "")
        autoPauseItem.target = self
        menu.addItem(autoPauseItem)

        languageMenu = NSMenu(title: "menu.language".localized)
        let languageItem = NSMenuItem(title: "menu.language".localized, action: nil, keyEquivalent: "")
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        menu.addItem(.separator())

        recentMenu = NSMenu(title: "menu.recent".localized)
        let recentItem = NSMenuItem(title: "menu.recent".localized, action: nil, keyEquivalent: "")
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)

        let clearItem = NSMenuItem(title: "menu.clearHistory".localized, action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "menu.about".localized, action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "menu.quit".localized, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        menu.delegate = self
        rebuildRecentMenu()
    }

    func rebuildRecentMenu() {
        recentMenu.removeAllItems()
        let history = SettingsManager.shared.wallpaperHistory
        if history.isEmpty {
            let empty = NSMenuItem(title: "menu.empty".localized, action: nil, keyEquivalent: "")
            empty.isEnabled = false
            recentMenu.addItem(empty)
            return
        }
        for path in history {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let filename = (path as NSString).lastPathComponent
            let item = NSMenuItem(title: filename, action: #selector(switchToRecent(_:)), keyEquivalent: "")
            item.representedObject = path
            item.target = self

            // Check if this path is currently active on any screen
            let isActive = NSScreen.screens.contains { screen in
                let id = SettingsManager.screenIdentifier(screen)
                let config = SettingsManager.shared.screenConfig(for: id)
                return config.folderPath == path || config.wallpaperPath == path
            }
            item.state = isActive ? .on : .off

            let icon = iconFor(path: path)
            item.image = icon
            requestAsyncIcon(for: path, item: item)

            recentMenu.addItem(item)
        }
    }

    private func iconFor(path: String) -> NSImage? {
        return NSWorkspace.shared.icon(forFile: path)
    }

    private func requestAsyncIcon(for path: String, item: NSMenuItem) {
        let url = URL(fileURLWithPath: path)
        ThumbnailProvider.shared.requestThumbnail(for: url, size: NSSize(width: 20, height: 20)) { [weak item] image in
            guard let item else { return }
            guard let image else { return }
            item.image = image
        }
    }

    @objc func switchToRecent(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return }
        let url = URL(fileURLWithPath: path)
        
        // Track which screens we've already handled via sync group propagation
        var handledScreenIDs = Set<String>()
        
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            if handledScreenIDs.contains(id) { continue }
            
            if isDir.boolValue {
                var config = SettingsManager.shared.screenConfig(for: id)
                config.folderPath = url.path
                config.isFolderMode = true
                wallpaperManager.setFolder(url: url, for: screen, config: config)
            } else {
                wallpaperManager.setWallpaper(url: url, for: screen)
            }
            
            // Mark this screen and all its synced peers as handled
            handledScreenIDs.insert(id)
            let config = SettingsManager.shared.screenConfig(for: id)
            if config.isSynced {
                for otherScreen in NSScreen.screens {
                    let otherId = SettingsManager.screenIdentifier(otherScreen)
                    if SettingsManager.shared.screenConfig(for: otherId).isSynced {
                        handledScreenIDs.insert(otherId)
                    }
                }
            }
        }
        
        mainWindow.updateUI()
        rebuildRecentMenu()
    }

    @objc func clearHistory() {
        SettingsManager.shared.wallpaperHistory = []
        rebuildRecentMenu()
    }

    private func rebuildNextWallpaperMenu() {
        nextWallpaperMenu.removeAllItems()

        let allItem = NSMenuItem(title: "ui.allScreens".localized, action: #selector(nextWallpaperAllScreens), keyEquivalent: "n")
        allItem.target = self
        allItem.isEnabled = wallpaperManager.hasAnyNextWallpaperTarget
        nextWallpaperMenu.addItem(allItem)
        nextWallpaperMenu.addItem(.separator())

        for (index, screen) in NSScreen.screens.enumerated() {
            let displayName: String
            if #available(macOS 10.15, *) {
                displayName = screen.localizedName
            } else {
                displayName = "screen.display".localized(index + 1)
            }
            let item = NSMenuItem(title: displayName, action: #selector(nextWallpaperForScreen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = screen
            item.isEnabled = wallpaperManager.canGoNextWallpaper(for: screen)
            nextWallpaperMenu.addItem(item)
        }
    }

    private func rebuildLanguageMenu() {
        languageMenu.removeAllItems()
        let currentLanguage = SettingsManager.shared.language
        
        let languages = [
            ("system", "language.system".localized),
            ("en", "language.en".localized),
            ("zh-Hans", "language.zh-Hans".localized)
        ]
        
        for (code, name) in languages {
            let item = NSMenuItem(title: name, action: #selector(switchLanguage(_:)), keyEquivalent: "")
            item.representedObject = code
            item.target = self
            item.state = (code == currentLanguage) ? .on : .off
            languageMenu.addItem(item)
        }
    }

    @objc func switchLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        SettingsManager.shared.language = code
        rebuildLanguageMenu()
        
        let alert = NSAlert()
        alert.messageText = "menu.language".localized
        alert.informativeText = "language.restartHint".localized
        alert.alertStyle = .informational
        alert.addButton(withTitle: "alert.ok".localized)
        alert.runModal()
    }

    @objc func openMain() {
        mainWindow.updateUI()
        mainWindow.showWindow(nil)
        mainWindow.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func stopWallpaper() {
        wallpaperManager.stopAll()
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            SettingsManager.shared.setScreenConfig(Screen_Config.default, for: id)
        }
        mainWindow.updateUI()
        rebuildRecentMenu()
    }

    @objc func togglePauseAllFromMenu() {
        if wallpaperManager.isPaused {
            wallpaperManager.resume()
        } else {
            wallpaperManager.pause()
        }
        updatePauseItem()
        mainWindow.updateUI()
    }

    @objc func togglePauseForScreen(_ sender: NSMenuItem) {
        guard let screen = sender.representedObject as? NSScreen else { return }
        if wallpaperManager.isScreenPaused(screen) {
            wallpaperManager.resumeScreen(screen)
        } else {
            wallpaperManager.pauseScreen(screen)
        }
        mainWindow.updateUI()
    }

    @objc func toggleAutoPause() {
        SettingsManager.shared.pauseWhenInvisible = !SettingsManager.shared.pauseWhenInvisible
        wallpaperManager.checkPlaybackState()
        updateAutoPauseItem()
        mainWindow.updateUI()
    }

    private func rebuildPauseMenu() {
        pauseMenu.removeAllItems()

        let allSuffix = wallpaperManager.isPaused ? " - \("menu.resume".localized)" : " - \("menu.pause".localized)"
        pauseAllItem = NSMenuItem(title: "\("ui.allScreens".localized)\(allSuffix)", action: #selector(togglePauseAllFromMenu), keyEquivalent: "p")
        pauseAllItem.target = self
        pauseAllItem.state = wallpaperManager.isPaused ? .on : .off
        pauseAllItem.isEnabled = wallpaperManager.isActive
        pauseMenu.addItem(pauseAllItem)
        pauseMenu.addItem(.separator())

        for (index, screen) in NSScreen.screens.enumerated() {
            let displayName: String
            if #available(macOS 10.15, *) {
                displayName = screen.localizedName
            } else {
                displayName = "screen.display".localized(index + 1)
            }
            let isPaused = wallpaperManager.isScreenPaused(screen)
            let suffix = isPaused ? " - \("menu.resume".localized)" : " - \("menu.pause".localized)"
            let item = NSMenuItem(title: "\(displayName)\(suffix)", action: #selector(togglePauseForScreen(_:)), keyEquivalent: "")
            item.representedObject = screen
            item.target = self
            item.state = isPaused ? .on : .off
            item.isEnabled = wallpaperManager.isActive
            pauseMenu.addItem(item)
        }
    }

    private func updatePauseItem() {
        pauseItem.title = "menu.pause".localized
        pauseItem.isEnabled = wallpaperManager.isActive
    }

    private func updateAutoPauseItem() {
        autoPauseItem.state = SettingsManager.shared.pauseWhenInvisible ? .on : .off
        if !wallpaperManager.isActive {
            statusMenuItem.title = "menu.status".localized("ui.notSet".localized)
        } else {
            let stateLabel: String
            switch wallpaperManager.playbackStatus {
            case .stopped:
                stateLabel = "ui.notSet".localized
            case .playing:
                stateLabel = "ui.playing".localized
            case .pausedManual:
                stateLabel = "ui.pausedManual".localized
            case .pausedAuto:
                stateLabel = "ui.pausedAuto".localized
            }
            
            // Get config from first active screen
            let firstActiveScreen = NSScreen.screens.first
            let firstID = firstActiveScreen.map { SettingsManager.screenIdentifier($0) } ?? ""
            let config = SettingsManager.shared.screenConfig(for: firstID)
            
            let isRotating = config.isFolderMode && config.isRotationEnabled
            let shuffleIcon = (isRotating && config.isShuffleMode) ? "🔀 " : ""
            
            if isRotating, let folderPath = config.folderPath {
                let folderName = (folderPath as NSString).lastPathComponent
                statusMenuItem.title = "\(shuffleIcon)\("menu.status.rotating".localized(folderName)) (\(stateLabel))"
            } else if let url = firstActiveScreen.flatMap({ wallpaperManager.currentFile(for: SettingsManager.screenIdentifier($0)) }) {
                let fileName = url.lastPathComponent
                statusMenuItem.title = "menu.status.file".localized(fileName) + " (\(stateLabel))"
            } else {
                statusMenuItem.title = "menu.status".localized(stateLabel)
            }
        }
    }

    @objc func showAbout() {
        if aboutWindow == nil {
            aboutWindow = AboutWindowController()
        }
        aboutWindow?.showWindow(nil)
        aboutWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        wallpaperManager.stopAll()
        NSApp.terminate(nil)
    }

    @objc func nextWallpaperAllScreens() {
        wallpaperManager.nextWallpaper()
    }

    @objc func nextWallpaperForScreen(_ sender: NSMenuItem) {
        guard let screen = sender.representedObject as? NSScreen else { return }
        wallpaperManager.nextWallpaper(for: screen)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(nextWallpaperAllScreens) {
            return wallpaperManager.hasAnyNextWallpaperTarget
        }
        if menuItem.action == #selector(nextWallpaperForScreen(_:)) {
            if let screen = menuItem.representedObject as? NSScreen {
                return wallpaperManager.canGoNextWallpaper(for: screen)
            }
            return false
        }
        return true
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildRecentMenu()
        rebuildPauseMenu()
        rebuildNextWallpaperMenu()
        rebuildLanguageMenu()
        updatePauseItem()
        updateAutoPauseItem()
    }
}
