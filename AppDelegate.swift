import Cocoa
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var mainWindow: MainWindowController!
    var wallpaperManager: WallpaperManager!
    var recentMenu: NSMenu!
    var aboutWindow: AboutWindowController?
    var pauseItem: NSMenuItem!
    var screenPauseMenu: NSMenu!
    var languageMenu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        wallpaperManager = WallpaperManager()
        mainWindow = MainWindowController(wallpaperManager: wallpaperManager)
        setupStatusBar()

        if SettingsManager.shared.hasScreenWallpapers {
            for screen in NSScreen.screens {
                if let url = SettingsManager.shared.wallpaperURL(for: screen),
                   FileManager.default.fileExists(atPath: url.path) {
                    wallpaperManager.setWallpaper(url: url, for: screen)
                }
            }
        } else if let url = SettingsManager.shared.wallpaperURL,
                  FileManager.default.fileExists(atPath: url.path) {
            wallpaperManager.setWallpaper(url: url)
        }
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

        pauseItem = NSMenuItem(title: "menu.pauseAll".localized, action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)

        screenPauseMenu = NSMenu(title: "menu.pauseScreen".localized)
        let screenPauseItem = NSMenuItem(title: "menu.pauseScreen".localized, action: nil, keyEquivalent: "")
        screenPauseItem.submenu = screenPauseMenu
        menu.addItem(screenPauseItem)

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

            if path == SettingsManager.shared.wallpaperPath {
                item.state = .on
            }

            let icon = iconFor(path: path)
            item.image = icon

            recentMenu.addItem(item)
        }
    }

    private func iconFor(path: String) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        switch MediaType.detect(url) {
        case .image:
            if let img = NSImage(contentsOf: url) {
                let thumb = NSImage(size: NSSize(width: 20, height: 20))
                thumb.lockFocus()
                img.draw(in: NSRect(x: 0, y: 0, width: 20, height: 20),
                         from: .zero, operation: .copy, fraction: 1)
                thumb.unlockFocus()
                return thumb
            }
        case .video:
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 40, height: 40)
            if let cgImg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                return NSImage(cgImage: cgImg, size: NSSize(width: 20, height: 20))
            }
        case .unsupported:
            break
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    @objc func switchToRecent(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String,
              FileManager.default.fileExists(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        wallpaperManager.setWallpaper(url: url)
        SettingsManager.shared.wallpaperPath = path
        mainWindow.updateUI()
        rebuildRecentMenu()
    }

    @objc func clearHistory() {
        SettingsManager.shared.wallpaperHistory = []
        rebuildRecentMenu()
    }

    private func rebuildScreenPauseMenu() {
        screenPauseMenu.removeAllItems()
        for (index, screen) in NSScreen.screens.enumerated() {
            let displayName: String
            if #available(macOS 10.15, *) {
                displayName = screen.localizedName
            } else {
                displayName = "screen.display".localized(index + 1)
            }
            let isPaused = wallpaperManager.isScreenPaused(screen)
            let suffix = isPaused ? " - \("menu.resume".localized)" : " - \("menu.pause".localized)"
            let item = NSMenuItem(title: "\(displayName)\(suffix)", action: #selector(toggleScreenPause(_:)), keyEquivalent: "")
            item.representedObject = screen
            item.target = self
            item.state = isPaused ? .on : .off
            screenPauseMenu.addItem(item)
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

    @objc func toggleScreenPause(_ sender: NSMenuItem) {
        guard let screen = sender.representedObject as? NSScreen else { return }
        if wallpaperManager.isScreenPaused(screen) {
            wallpaperManager.resumeScreen(screen)
        } else {
            wallpaperManager.pauseScreen(screen)
        }
        rebuildScreenPauseMenu()
        mainWindow.updateUI()
    }

    @objc func openMain() {
        mainWindow.updateUI()
        mainWindow.showWindow(nil)
        mainWindow.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func stopWallpaper() {
        wallpaperManager.stopAll()
        SettingsManager.shared.wallpaperPath = nil
        mainWindow.updateUI()
        rebuildRecentMenu()
    }

    @objc func togglePause() {
        if wallpaperManager.isPaused {
            wallpaperManager.resume()
        } else {
            wallpaperManager.pause()
        }
        updatePauseItem()
        mainWindow.updateUI()
    }

    private func updatePauseItem() {
        pauseItem.title = wallpaperManager.isPaused ? "menu.resume".localized : "menu.pause".localized
        pauseItem.isEnabled = wallpaperManager.isActive
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
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildRecentMenu()
        rebuildScreenPauseMenu()
        rebuildLanguageMenu()
        updatePauseItem()
    }
}
