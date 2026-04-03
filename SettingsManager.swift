import Foundation
import ServiceManagement
import Cocoa

class SettingsManager {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    private let wallpaperKey = "sakurawallpaper_wallpaper_path"
    private let launchKey    = "sakurawallpaper_launch_at_login"
    private let pauseWhenInvisibleKey = "sakurawallpaper_pause_when_invisible"
    private let historyKey   = "sakurawallpaper_history"
    private let screenWallpapersKey = "sakurawallpaper_screen_wallpapers"
    private let languageKey = "sakurawallpaper_language"
    private let isFolderModeKey = "sakurawallpaper_is_folder_mode"
    private let folderPathKey = "sakurawallpaper_folder_path"
    private let rotationIntervalSecondsKey = "sakurawallpaper_rotation_interval_seconds"

    var wallpaperPath: String? {
        get { defaults.string(forKey: wallpaperKey) }
        set {
            defaults.set(newValue, forKey: wallpaperKey)
            if let p = newValue { addToHistory(p) }
        }
    }

    var isFolderMode: Bool {
        get { defaults.bool(forKey: isFolderModeKey) }
        set { defaults.set(newValue, forKey: isFolderModeKey) }
    }

    var folderPath: String? {
        get { defaults.string(forKey: folderPathKey) }
        set { defaults.set(newValue, forKey: folderPathKey) }
    }

    var rotationIntervalSeconds: Int {
        get { 
            let value = defaults.integer(forKey: rotationIntervalSecondsKey)
            return value > 0 ? value : 60 // Default to 60 seconds
        }
        set { defaults.set(newValue, forKey: rotationIntervalSecondsKey) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: launchKey) }
        set {
            defaults.set(newValue, forKey: launchKey)
            updateLoginItem(enabled: newValue)
        }
    }

    var pauseWhenInvisible: Bool {
        get { defaults.bool(forKey: pauseWhenInvisibleKey) }
        set { defaults.set(newValue, forKey: pauseWhenInvisibleKey) }
    }

    var wallpaperHistory: [String] {
        get { defaults.stringArray(forKey: historyKey) ?? [] }
        set { defaults.set(newValue, forKey: historyKey) }
    }

    var wallpaperURL: URL? {
        guard let path = wallpaperPath else { return nil }
        return URL(fileURLWithPath: path)
    }

    var screenWallpapers: [String: String] {
        get { defaults.dictionary(forKey: screenWallpapersKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: screenWallpapersKey) }
    }

    static func screenIdentifier(_ screen: NSScreen) -> String {
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "screen_\(number.uint32Value)"
        }
        return UUID().uuidString
    }

    func wallpaperPath(for screen: NSScreen) -> String? {
        let id = SettingsManager.screenIdentifier(screen)
        return screenWallpapers[id]
    }

    func setWallpaper(path: String?, for screen: NSScreen) {
        var wallpapers = screenWallpapers
        let id = SettingsManager.screenIdentifier(screen)
        wallpapers[id] = path
        screenWallpapers = wallpapers
        if let p = path { addToHistory(p) }
    }

    func wallpaperURL(for screen: NSScreen) -> URL? {
        guard let path = wallpaperPath(for: screen) else { return nil }
        return URL(fileURLWithPath: path)
    }

    func clearScreenWallpapers() {
        screenWallpapers = [:]
    }

    var hasScreenWallpapers: Bool {
        !screenWallpapers.isEmpty
    }

    var language: String {
        get { defaults.string(forKey: languageKey) ?? "system" }
        set { defaults.set(newValue, forKey: languageKey) }
    }

    private func addToHistory(_ path: String) {
        var history = wallpaperHistory.filter { $0 != path }
        history.insert(path, at: 0)
        if history.count > 10 { history = Array(history.prefix(10)) }
        wallpaperHistory = history
    }

    private func updateLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled { try service.register() } else { try service.unregister() }
            } catch {
                print("Failed to update login item: \(error)")
            }
        }
    }
}
