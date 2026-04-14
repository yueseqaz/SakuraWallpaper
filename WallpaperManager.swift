import Cocoa
import AVFoundation

class WallpaperManager {
    enum PlaybackStatus {
        case stopped
        case playing
        case pausedManual
        case pausedAuto
    }

    private var players: [String: ScreenPlayer] = [:]
    var currentFiles: [String: URL] = [:]
    var isActive: Bool { !players.isEmpty }
    var isPaused: Bool = false
    private var keepVisibleTimer: Timer?
    private let keepVisibleInterval: TimeInterval = 0.75
    private var pausedScreens: Set<String> = []

    var playlist: [URL] = []
    var playlistItemCount: Int { playlist.count }
    public private(set) var currentPlaylistIndex: Int = 0
    private var rotationTimer: Timer?

    static let didRotateNotification = Notification.Name("WallpaperManagerDidRotate")
    static let playbackStateDidChangeNotification = Notification.Name("WallpaperManagerPlaybackStateDidChange")

    var currentFile: URL? {
        currentFiles.values.first
    }

    var playbackStatus: PlaybackStatus {
        if !isActive {
            return .stopped
        }
        if isPaused {
            return .pausedManual
        }
        if SettingsManager.shared.pauseWhenInvisible && isPausedInternally {
            return .pausedAuto
        }
        return .playing
    }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(checkPlaybackState),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(checkPlaybackState),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(checkPlaybackState),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(checkPlaybackState),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc private func handleSleep() {
        if !isPausedInternally {
            isPausedInternally = true
            pauseAll()
            NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
        }
    }

    deinit {
        stopKeepVisibleTimer()
        stopRotationTimer()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc func checkPlaybackState() {
        guard SettingsManager.shared.pauseWhenInvisible else {
            if isPausedInternally {
                isPausedInternally = false
                if !isPaused { resumeAll() }
            }
            return
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontmostApp?.bundleIdentifier
        let isDesktopActive = bundleID == "com.apple.finder" || bundleID == "com.sakura.wallpaper"

        if isDesktopActive {
            if isPausedInternally {
                isPausedInternally = false
                if !isPaused { resumeAll() }
                NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
            }
        } else {
            if !isPausedInternally {
                isPausedInternally = true
                pauseAll()
                NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
            }
        }
    }

    public private(set) var isPausedInternally: Bool = false

    private func stopRotationTimer() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    func startRotationTimer() {
        stopRotationTimer()
        guard SettingsManager.shared.isRotationEnabled else { return }
        guard playlist.count > 1 else { return }
        
        let interval = TimeInterval(SettingsManager.shared.rotationIntervalMinutes * 60)
        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.nextWallpaper()
        }
    }

    @objc func nextWallpaper() {
        guard !playlist.isEmpty else { return }
        let token = PerformanceMonitor.shared.begin("wallpaper.switch")
        currentPlaylistIndex = PlaylistBuilder.nextIndex(
            currentIndex: currentPlaylistIndex,
            itemCount: playlist.count,
            shuffle: SettingsManager.shared.isShuffleMode
        )
        
        let nextURL = playlist[currentPlaylistIndex]
        
        // Only update screens that are currently active
        for (id, player) in players {
            currentFiles[id] = nextURL
            player.updateMedia(url: nextURL)
            if isPaused || isPausedInternally {
                player.pausePlayback()
            }
        }
        PerformanceMonitor.shared.end(token, extra: "players=\(players.count) file=\(nextURL.lastPathComponent)")
        NotificationCenter.default.post(name: WallpaperManager.didRotateNotification, object: nil)
    }

    func selectPlaylistItem(at index: Int) {
        guard index >= 0 && index < playlist.count else { return }
        currentPlaylistIndex = index
        let nextURL = playlist[currentPlaylistIndex]
        
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            currentFiles[id] = nextURL
            
            if let player = players[id] {
                player.updateMedia(url: nextURL)
                if isPaused || isPausedInternally {
                    player.pausePlayback()
                }
            } else {
                let player = ScreenPlayer(fileURL: nextURL, screen: screen)
                player.setVolume(0)
                players[id] = player
                if isPaused || isPausedInternally {
                    player.pausePlayback()
                    player.window?.orderOut(nil)
                }
            }
        }
        NotificationCenter.default.post(name: WallpaperManager.didRotateNotification, object: nil)
    }

    func setFolder(url: URL) {
        stopAll()
        SettingsManager.shared.isFolderMode = true
        SettingsManager.shared.folderPath = url.path
        let token = PerformanceMonitor.shared.begin("playlist.build")
        
        do {
            playlist = try PlaylistBuilder.collectMediaFiles(in: url, includeSubfolders: SettingsManager.shared.includeSubfolders)
            currentPlaylistIndex = 0
            PerformanceMonitor.shared.end(token, extra: "count=\(playlist.count) recursive=\(SettingsManager.shared.includeSubfolders)")
            
            if let firstURL = playlist.first {
                for screen in NSScreen.screens {
                    let id = SettingsManager.screenIdentifier(screen)
                    currentFiles[id] = firstURL
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.createAllPlayers()
                    self?.startKeepVisibleTimer()
                    self?.startRotationTimer()
                    NotificationCenter.default.post(name: WallpaperManager.didRotateNotification, object: nil)
                }
            }
        } catch {
            PerformanceMonitor.shared.end(token, extra: "failed=\(error.localizedDescription)")
            print("Failed to read directory: \(error)")
        }
    }

    @objc private func screensChanged() {
        let currentScreenIds = Set(NSScreen.screens.map { SettingsManager.screenIdentifier($0) })
        let existingIds = Set(players.keys)

        for removedId in existingIds.subtracting(currentScreenIds) {
            players[removedId]?.cleanup()
            players.removeValue(forKey: removedId)
            currentFiles.removeValue(forKey: removedId)
        }

        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            if players[id] == nil, let url = urlForScreen(screen) {
                let player = ScreenPlayer(fileURL: url, screen: screen)
                player.setVolume(0)
                players[id] = player
                currentFiles[id] = url
            }
        }

        if isPaused {
            pauseAll()
        } else {
            showAll()
        }
    }

    private func urlForScreen(_ screen: NSScreen) -> URL? {
        // Priority 1: If we have an explicitly set file in currentFiles (important for rotation)
        let id = SettingsManager.screenIdentifier(screen)
        if let currentURL = currentFiles[id], FileManager.default.fileExists(atPath: currentURL.path) {
            return currentURL
        }

        // Priority 2: Per-screen settings from disk
        if let path = SettingsManager.shared.wallpaperPath(for: screen) {
            return URL(fileURLWithPath: path)
        }

        // Priority 3: Global setting from disk
        if let url = SettingsManager.shared.wallpaperURL {
            return url
        }

        return nil
    }

    @objc private func appBecameActive() {
        if !isPaused {
            resumeAll()
        }
        showAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if self?.isPaused == false {
                self?.resumeAll()
            }
            self?.showAll()
        }
    }

    private func showAll() {
        players.forEach { id, player in
            guard !pausedScreens.contains(id) else { return }
            player.window?.orderBack(nil)
        }
    }

    private func startKeepVisibleTimer() {
        keepVisibleTimer?.invalidate()
        keepVisibleTimer = Timer.scheduledTimer(withTimeInterval: keepVisibleInterval, repeats: true) { [weak self] _ in
            self?.showAll()
        }
    }

    private func stopKeepVisibleTimer() {
        keepVisibleTimer?.invalidate()
        keepVisibleTimer = nil
    }

    private func resumeAll() {
        players.forEach { id, player in
            guard !pausedScreens.contains(id) else { return }
            player.resumePlayback()
        }
    }

    private func pauseAll() {
        players.values.forEach { $0.pausePlayback() }
    }

    func pauseScreen(_ screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        pausedScreens.insert(id)
        players[id]?.pausePlayback()
        players[id]?.window?.orderOut(nil)
    }

    func resumeScreen(_ screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        pausedScreens.remove(id)
        players[id]?.resumePlayback()
        players[id]?.window?.orderBack(nil)
        players[id]?.window?.orderFrontRegardless()
    }

    func isScreenPaused(_ screen: NSScreen) -> Bool {
        let id = SettingsManager.screenIdentifier(screen)
        return pausedScreens.contains(id)
    }

    func pause() {
        guard isActive else { return }
        isPaused = true
        pauseAll()
        stopKeepVisibleTimer()
        players.values.forEach { $0.window?.orderOut(nil) }
        NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
    }

    func resume() {
        guard isActive else { return }
        isPaused = false
        if !isPausedInternally {
            resumeAll()
            showAll()
        }
        startKeepVisibleTimer()
        NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
    }

    func setWallpaper(url: URL) {
        stopAll()
        SettingsManager.shared.isFolderMode = false
        SettingsManager.shared.wallpaperPath = url.path
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            SettingsManager.shared.setWallpaper(path: url.path, for: screen)
            currentFiles[id] = url
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.createAllPlayers()
            self?.startKeepVisibleTimer()
        }
    }

    func setWallpaper(url: URL, for screen: NSScreen) {
        stopRotationTimer()
        let id = SettingsManager.screenIdentifier(screen)
        players[id]?.cleanup()
        players.removeValue(forKey: id)

        SettingsManager.shared.isFolderMode = false
        SettingsManager.shared.setWallpaper(path: url.path, for: screen)
        currentFiles[id] = url

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let player = ScreenPlayer(fileURL: url, screen: screen)
            player.setVolume(0)
            self?.players[id] = player
            if self?.isPaused == true {
                player.pausePlayback()
                player.window?.orderOut(nil)
            }
            self?.startKeepVisibleTimer()
        }
    }

    private func createAllPlayers() {
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            guard let url = urlForScreen(screen) else { continue }
            let player = ScreenPlayer(fileURL: url, screen: screen)
            player.setVolume(0)
            players[id] = player
            currentFiles[id] = url
        }
    }

    func wallpaperPath(for screen: NSScreen) -> String? {
        let id = SettingsManager.screenIdentifier(screen)
        return currentFiles[id]?.path
    }

    func stopAll() {
        isPaused = false
        isPausedInternally = false
        stopKeepVisibleTimer()
        stopRotationTimer()
        players.values.forEach { $0.cleanup() }
        players.removeAll()
        currentFiles.removeAll()
        pausedScreens.removeAll()
        playlist.removeAll()
        currentPlaylistIndex = 0
    }

    func stopWallpaper(for screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        players[id]?.cleanup()
        players.removeValue(forKey: id)
        currentFiles.removeValue(forKey: id)
        pausedScreens.remove(id)
        SettingsManager.shared.setWallpaper(path: nil, for: screen)
        if players.isEmpty { stopKeepVisibleTimer() }
    }
}
