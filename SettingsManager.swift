import Foundation
import ServiceManagement
import Cocoa

struct ScreenFolderConfig: Codable {
    let folderPath: String
    var rotationIntervalMinutes: Int
    var isShuffleMode: Bool
    var isRotationEnabled: Bool
    var includeSubfolders: Bool
}

class SettingsManager {
    static let shared = SettingsManager()
    
    enum NewScreenInheritanceMode: String {
        case primaryScreen
        case specificScreen
    }

    private let defaults: UserDefaults
    private let wallpaperKey = "sakurawallpaper_wallpaper_path"
    private let launchKey    = "sakurawallpaper_launch_at_login"
    private let pauseWhenInvisibleKey = "sakurawallpaper_pause_when_invisible"
    private let historyKey   = "sakurawallpaper_history"
    private let screenWallpapersKey = "sakurawallpaper_screen_wallpapers"
    private let languageKey = "sakurawallpaper_language"
    private let isFolderModeKey = "sakurawallpaper_is_folder_mode"
    private let folderPathKey = "sakurawallpaper_folder_path"
    private let rotationIntervalMinutesKey = "sakurawallpaper_rotation_interval_minutes"
    private let isShuffleModeKey = "sakurawallpaper_is_shuffle_mode"
    private let isRotationEnabledKey = "sakurawallpaper_is_rotation_enabled"
    private let includeSubfoldersKey = "sakurawallpaper_include_subfolders"
    private let onboardingCompletedKey = "sakurawallpaper_onboarding_completed"
    private let screenFolderConfigsKey = "sakurawallpaper_screen_folder_configs"
    private let newScreenInheritanceModeKey = "sakurawallpaper_new_screen_inheritance_mode"
    private let newScreenInheritanceScreenIdKey = "sakurawallpaper_new_screen_inheritance_screen_id"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

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
        set {
            defaults.set(newValue, forKey: folderPathKey)
            if let p = newValue { addToHistory(p) }
        }
    }

    var rotationIntervalMinutes: Int {
        get { 
            let value = defaults.integer(forKey: rotationIntervalMinutesKey)
            return value > 0 ? value : 15 // Default to 15 mins
        }
        set { defaults.set(newValue, forKey: rotationIntervalMinutesKey) }
    }

    var isShuffleMode: Bool {
        get { defaults.bool(forKey: isShuffleModeKey) }
        set { defaults.set(newValue, forKey: isShuffleModeKey) }
    }

    var isRotationEnabled: Bool {
        get { 
            if defaults.object(forKey: isRotationEnabledKey) == nil { return true }
            return defaults.bool(forKey: isRotationEnabledKey)
        }
        set { defaults.set(newValue, forKey: isRotationEnabledKey) }
    }

    var includeSubfolders: Bool {
        get { defaults.bool(forKey: includeSubfoldersKey) }
        set { defaults.set(newValue, forKey: includeSubfoldersKey) }
    }
    
    var newScreenInheritanceMode: NewScreenInheritanceMode {
        get {
            guard let raw = defaults.string(forKey: newScreenInheritanceModeKey),
                  let mode = NewScreenInheritanceMode(rawValue: raw) else {
                return .primaryScreen
            }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: newScreenInheritanceModeKey) }
    }
    
    var newScreenInheritanceScreenId: String? {
        get { defaults.string(forKey: newScreenInheritanceScreenIdKey) }
        set { defaults.set(newValue, forKey: newScreenInheritanceScreenIdKey) }
    }

    var onboardingCompleted: Bool {
        get { defaults.bool(forKey: onboardingCompletedKey) }
        set { defaults.set(newValue, forKey: onboardingCompletedKey) }
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
        return screenIdentifier(deviceDescription: screen.deviceDescription, name: screen.localizedName)
    }

    /// Testable core of screenIdentifier. Accepts raw device description and name
    /// so tests can exercise the logic without instantiating NSScreen.
    static func screenIdentifier(deviceDescription: [NSDeviceDescriptionKey: Any], name: String) -> String {
        if let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "screen_\(number.uint32Value)"
        }
        // Unfixed fallback — returns a new UUID on every call (Bug 3).
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

    var screenFolderConfigs: [String: ScreenFolderConfig] {
        get {
            guard let data = defaults.data(forKey: screenFolderConfigsKey),
                  let decoded = try? JSONDecoder().decode([String: ScreenFolderConfig].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: screenFolderConfigsKey)
            }
        }
    }

    func folderConfig(for screen: NSScreen) -> ScreenFolderConfig? {
        screenFolderConfigs[SettingsManager.screenIdentifier(screen)]
    }

    func setFolderConfig(_ config: ScreenFolderConfig?, for screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        var all = screenFolderConfigs
        all[id] = config
        screenFolderConfigs = all
        if let config {
            folderPath = config.folderPath
            isFolderMode = true
            rotationIntervalMinutes = config.rotationIntervalMinutes
            isShuffleMode = config.isShuffleMode
            isRotationEnabled = config.isRotationEnabled
            includeSubfolders = config.includeSubfolders
            addToHistory(config.folderPath)
        }
    }

    func clearFolderConfig(for screen: NSScreen) {
        setFolderConfig(nil, for: screen)
    }

    func clearAllFolderConfigs() {
        screenFolderConfigs = [:]
    }

    var hasExistingSetup: Bool {
        if wallpaperPath != nil { return true }
        if folderPath != nil { return true }
        if hasScreenWallpapers { return true }
        if !screenFolderConfigs.isEmpty { return true }
        return !wallpaperHistory.isEmpty
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
