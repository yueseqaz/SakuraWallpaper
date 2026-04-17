import Cocoa
import AVFoundation
import IOKit.ps

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
    private var batteryCheckTimer: Timer?
    private let keepVisibleInterval: TimeInterval = 0.75
    private let lowBatteryPauseThreshold = 20
    private var pausedScreens: Set<String> = []

    private var playlistsByScreen: [String: [URL]] = [:]
    private var playlistIndexesByScreen: [String: Int] = [:]
    private var independentTimersByScreen: [String: Timer] = [:]
    private var syncGroupTimer: Timer?
    private var syncGroupPlaylistIndex: Int = 0
    private let fileManager = FileManager.default
    private let lockScreenCaptureQueue = DispatchQueue(label: "com.sakura.wallpaper.lockscreen", qos: .userInitiated)
    private var transientDesktopSnapshotsByScreen: [String: URL] = [:]
    private var screensChangedWorkItem: DispatchWorkItem?
    /// Original system desktop URLs captured before SakuraWallpaper first overwrites them.
    /// Used to restore the wallpaper when the user clears SakuraWallpaper.
    private var originalDesktopURLsByScreen: [String: URL] = [:]

    static let didRotateNotification = Notification.Name("WallpaperManagerDidRotate")
    static let playbackStateDidChangeNotification = Notification.Name("WallpaperManagerPlaybackStateDidChange")
    static let screenListDidChangeNotification = Notification.Name("WallpaperManagerScreenListDidChange")

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
            selector: #selector(screensChangedDebounced),
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
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLocked(_:)),
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLocked(_:)),
            name: Notification.Name("com.apple.screensaver.didstart"),
            object: nil
        )
        startBatteryCheckTimer()
    }

    deinit {
        stopKeepVisibleTimer()
        stopBatteryCheckTimer()
        stopSyncGroupTimer()
        for (_, timer) in independentTimersByScreen { timer.invalidate() }
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }


    @objc private func handleSleep() {
        if !isPausedInternally {
            isPausedInternally = true
            pauseAll()
            NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
        }
    }

    @objc func checkPlaybackState() {
        guard SettingsManager.shared.pauseWhenInvisible else {
            if isPausedInternally {
                isPausedInternally = false
                if !isPaused { resumeAll() }
                NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
            }
            return
        }

        if shouldPauseForLowBattery() {
            if !isPausedInternally {
                isPausedInternally = true
                pauseAll()
                NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
            }
            return
        }

        if isPausedInternally {
            isPausedInternally = false
            if !isPaused { resumeAll() }
            NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
        }
    }

    public private(set) var isPausedInternally: Bool = false

    func startRotationTimer() {
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            let config = SettingsManager.shared.screenConfig(for: id)
            if config.isSynced {
                startSyncGroupTimerIfNeeded()
            } else {
                startIndependentTimer(forScreenID: id)
            }
        }
    }

    @objc func nextWallpaper() {
        for id in playlistsByScreen.keys {
            nextWallpaper(forScreenID: id)
        }
    }

    func nextWallpaper(for screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        nextWallpaper(forScreenID: id)
    }

    func canGoNextWallpaper(for screen: NSScreen) -> Bool {
        let id = SettingsManager.screenIdentifier(screen)
        guard let list = playlistsByScreen[id] else { return false }
        return !list.isEmpty
    }

    var hasAnyNextWallpaperTarget: Bool {
        playlistsByScreen.values.contains { !$0.isEmpty }
    }

    // MARK: - Screen-parameterized query methods (Task 6.2)

    func playlist(for screenID: String) -> [URL] {
        return playlistsByScreen[screenID] ?? []
    }

    func currentPlaylistIndex(for screenID: String) -> Int {
        return playlistIndexesByScreen[screenID] ?? 0
    }

    func currentFile(for screenID: String) -> URL? {
        return currentFiles[screenID]
    }

    func selectPlaylistItem(at index: Int, for screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        selectPlaylistItem(at: index, forScreenID: id)
    }

    func setFolder(url: URL, for screen: NSScreen, config: Screen_Config) {
        let id = SettingsManager.screenIdentifier(screen)
        let token = PerformanceMonitor.shared.begin("playlist.build")

        do {
            let files = try PlaylistBuilder.collectMediaFiles(in: url, includeSubfolders: config.includeSubfolders)
            playlistsByScreen[id] = files
            playlistIndexesByScreen[id] = 0
            PerformanceMonitor.shared.end(token, extra: "screen=\(id) count=\(files.count) recursive=\(config.includeSubfolders)")

            var updatedConfig = config
            updatedConfig.folderPath = url.path
            updatedConfig.isFolderMode = true
            SettingsManager.shared.setScreenConfig(updatedConfig, for: id)
            SettingsManager.shared.addToHistory(url.path)

            // Propagate to all other synced screens if this screen is synced
            if updatedConfig.isSynced {
                let syncedScreens = NSScreen.screens.filter {
                    let sid = SettingsManager.screenIdentifier($0)
                    return sid != id && SettingsManager.shared.screenConfig(for: sid).isSynced
                }
                for syncedScreen in syncedScreens {
                    let sid = SettingsManager.screenIdentifier(syncedScreen)
                    var syncedConfig = SettingsManager.shared.screenConfig(for: sid)
                    syncedConfig.folderPath = updatedConfig.folderPath
                    syncedConfig.rotationIntervalMinutes = updatedConfig.rotationIntervalMinutes
                    syncedConfig.isShuffleMode = updatedConfig.isShuffleMode
                    syncedConfig.isRotationEnabled = updatedConfig.isRotationEnabled
                    SettingsManager.shared.setScreenConfig(syncedConfig, for: sid)
                    // Rebuild playlist for synced screen
                    if let syncedFiles = try? PlaylistBuilder.collectMediaFiles(in: url, includeSubfolders: syncedConfig.includeSubfolders) {
                        playlistsByScreen[sid] = syncedFiles
                        playlistIndexesByScreen[sid] = 0
                        if let firstURL = syncedFiles.first {
                            currentFiles[sid] = firstURL
                            createOrUpdatePlayer(for: syncedScreen, url: firstURL)
                        }
                    }
                }
            }

            if let firstURL = files.first {
                currentFiles[id] = firstURL
                createOrUpdatePlayer(for: screen, url: firstURL)
                syncCurrentWallpaperToSystemDesktop(for: screen)
                if isPaused || isPausedInternally {
                    players[id]?.pausePlayback()
                    players[id]?.window?.orderOut(nil)
                }
            } else {
                stopWallpaper(for: screen)
            }

            startKeepVisibleTimer()
            // Start appropriate timer
            if updatedConfig.isSynced {
                startSyncGroupTimerIfNeeded()
            } else {
                startIndependentTimer(forScreenID: id)
            }
            NotificationCenter.default.post(name: WallpaperManager.didRotateNotification, object: nil)
        } catch {
            PerformanceMonitor.shared.end(token, extra: "screen=\(id) failed=\(error.localizedDescription)")
            print("Failed to read directory: \(error)")
        }
    }

    @objc private func handleScreenLocked(_ notification: Notification) {
        syncCurrentWallpaperToSystemDesktop()
    }

    private func syncCurrentWallpaperToSystemDesktop() {
        guard SettingsManager.shared.syncDesktopWallpaper else { return }
        for screen in NSScreen.screens {
            syncCurrentWallpaperToSystemDesktop(for: screen)
        }
    }

    private func syncCurrentWallpaperToSystemDesktop(for screen: NSScreen) {
        guard SettingsManager.shared.syncDesktopWallpaper else { return }
        let id = SettingsManager.screenIdentifier(screen)
        if let player = players[id] {
            syncCurrentPlayerToSystemDesktop(player, for: screen, screenID: id)
            return
        }

        guard let mediaURL = currentFiles[id] ?? urlForScreen(screen) else { return }
        applySystemDesktopWallpaper(for: screen, screenID: id, mediaURL: mediaURL, playbackTime: nil)
    }

    private func syncCurrentPlayerToSystemDesktop(_ player: ScreenPlayer, for screen: NSScreen, screenID: String) {
        let mediaURL = player.mediaURL
        let playbackTime = player.currentPlaybackTime()
        applySystemDesktopWallpaper(for: screen, screenID: screenID, mediaURL: mediaURL, playbackTime: playbackTime)
    }

    private func applySystemDesktopWallpaper(for screen: NSScreen, screenID: String, mediaURL: URL, playbackTime: CMTime?) {
        switch MediaType.detect(mediaURL) {
        case .image:
            clearTransientDesktopSnapshot(for: screenID)
            applyDesktopImage(at: mediaURL, for: screen, screenID: screenID)
        case .video:
            let outputURL = makeTransientSnapshotURL(for: screenID)

            lockScreenCaptureQueue.async { [weak self] in
                guard let self else { return }
                // Re-read live screen geometry at execution time rather than using the
                // value captured at dispatch time — prevents stale-geometry snapshots
                // when the display configuration changes between dispatch and execution (Bug 4 fix).
                let liveScreen = NSScreen.screens.first(where: { SettingsManager.screenIdentifier($0) == screenID }) ?? screen
                let targetSize = CGSize(
                    width: max(liveScreen.frame.width * liveScreen.backingScaleFactor, 1920),
                    height: max(liveScreen.frame.height * liveScreen.backingScaleFactor, 1080)
                )
                guard let snapshotURL = self.createDesktopSnapshot(from: mediaURL, at: playbackTime, outputURL: outputURL, maxSize: targetSize) else {
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.currentMediaURL(forScreenID: screenID) == mediaURL else {
                        try? self.fileManager.removeItem(at: snapshotURL)
                        return
                    }
                    self.replaceTransientDesktopSnapshot(for: screenID, with: snapshotURL)
                    let applyScreen = NSScreen.screens.first(where: { SettingsManager.screenIdentifier($0) == screenID }) ?? screen
                    self.applyDesktopImage(at: snapshotURL, for: applyScreen, screenID: screenID)
                }
            }
        case .unsupported:
            break
        }
    }

    private func applyDesktopImage(at imageURL: URL, for screen: NSScreen, screenID: String) {
        do {
            // Capture the original system desktop URL the first time we overwrite it,
            // so we can restore it when the user clears SakuraWallpaper.
            if originalDesktopURLsByScreen[screenID] == nil {
                originalDesktopURLsByScreen[screenID] = NSWorkspace.shared.desktopImageURL(for: screen)
            }
            let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
            try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: options)
        } catch {
            print("Failed to set system desktop image for \(screenID): \(error)")
        }
    }

    private func createDesktopSnapshot(from mediaURL: URL, at playbackTime: CMTime?, outputURL: URL, maxSize: CGSize) -> URL? {
        let asset = AVURLAsset(url: mediaURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let targetTime = normalizedSnapshotTime(playbackTime)
        if let cgImage = copyImage(using: generator, at: targetTime) ?? copyImage(using: generator, at: .zero) {
            return writeDesktopSnapshot(cgImage, to: outputURL)
        }

        print("Failed to create current-frame snapshot from \(mediaURL.lastPathComponent)")
        return nil
    }

    private func normalizedSnapshotTime(_ playbackTime: CMTime?) -> CMTime {
        guard let playbackTime else {
            return .zero
        }
        let seconds = playbackTime.seconds
        guard playbackTime.isValid, seconds.isFinite, seconds >= 0 else {
            return .zero
        }
        return playbackTime
    }

    private func makeTransientSnapshotURL(for screenID: String) -> URL {
        let directory = fileManager.temporaryDirectory.appendingPathComponent("SakuraWallpaper", isDirectory: true)
        return directory.appendingPathComponent("lockscreen-current-\(screenID)-\(UUID().uuidString).jpg")
    }

    private func replaceTransientDesktopSnapshot(for screenID: String, with newURL: URL) {
        let previousURL = transientDesktopSnapshotsByScreen.updateValue(newURL, forKey: screenID)
        if let previousURL, previousURL != newURL {
            try? fileManager.removeItem(at: previousURL)
        }
    }

    private func clearTransientDesktopSnapshot(for screenID: String) {
        guard let previousURL = transientDesktopSnapshotsByScreen.removeValue(forKey: screenID) else { return }
        try? fileManager.removeItem(at: previousURL)
    }

    private func clearAllTransientDesktopSnapshots() {
        let snapshotURLs = Array(transientDesktopSnapshotsByScreen.values)
        transientDesktopSnapshotsByScreen.removeAll()
        snapshotURLs.forEach { try? fileManager.removeItem(at: $0) }
    }

    private func copyImage(using generator: AVAssetImageGenerator, at time: CMTime) -> CGImage? {
        try? generator.copyCGImage(at: time, actualTime: nil)
    }

    private func writeDesktopSnapshot(_ image: CGImage, to outputURL: URL) -> URL? {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
            return nil
        }

        do {
            try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: outputURL, options: .atomic)
            return outputURL
        } catch {
            print("Failed to write current-frame snapshot: \(error)")
            return nil
        }
    }

    @objc private func screensChangedDebounced() {
        screensChangedWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.screensChanged() }
        screensChangedWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
    }

    @objc private func screensChanged() {
        let currentScreenIds = Set(NSScreen.screens.map { SettingsManager.screenIdentifier($0) })
        let existingIds = Set(players.keys)
        let removedIds = existingIds.subtracting(currentScreenIds)

        // Step 1 & 2: Tear down removed screens
        for removedId in removedIds {
            players[removedId]?.cleanup()
            players.removeValue(forKey: removedId)
            currentFiles.removeValue(forKey: removedId)
            playlistsByScreen.removeValue(forKey: removedId)
            playlistIndexesByScreen.removeValue(forKey: removedId)
            stopIndependentTimer(forScreenID: removedId)
            pausedScreens.remove(removedId)
            clearTransientDesktopSnapshot(for: removedId)
            // If this was the last synced screen, stop sync group timer
            let remainingSynced = NSScreen.screens
                .map { SettingsManager.screenIdentifier($0) }
                .filter { SettingsManager.shared.screenConfig(for: $0).isSynced }
            if remainingSynced.isEmpty {
                stopSyncGroupTimer()
            }
        }

        // Step 3: Post notification if any screen was removed
        if !removedIds.isEmpty {
            NotificationCenter.default.post(name: WallpaperManager.screenListDidChangeNotification, object: nil)
        }

        // Step 4: Provision new screens
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            if players[id] != nil { continue }

            // Check if this screen has a prior registry entry
            let hasRegistryEntry = hasScreenRegistryEntry(for: id)
            let config: Screen_Config

            if hasRegistryEntry {
                // Restore exactly from registry
                config = SettingsManager.shared.screenConfig(for: id)
            } else {
                // Apply New_Screen_Policy
                config = provisionNewScreen(id: id, screen: screen)
            }

            // Build playlist or set wallpaper based on config
            if let folderPath = config.folderPath,
               FileManager.default.fileExists(atPath: folderPath) {
                let folderURL = URL(fileURLWithPath: folderPath)
                setFolder(url: folderURL, for: screen, config: config)
            } else if let wallpaperPath = config.wallpaperPath,
                      FileManager.default.fileExists(atPath: wallpaperPath) {
                let wallpaperURL = URL(fileURLWithPath: wallpaperPath)
                setWallpaper(url: wallpaperURL, for: screen)
            }
            // else: leave stopped
        }

        if isPaused {
            pauseAll()
        } else {
            showAll()
        }

        // Step 5: Resize existing players whose frame changed
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            guard let player = players[id] else { continue }
            if player.window?.frame != screen.frame {
                player.resize(to: screen)
            }
        }
    }

    private func hasScreenRegistryEntry(for screenID: String) -> Bool {
        // A screen has a registry entry if its config differs from the default
        // OR if the registry key exists with an entry for this screen.
        // We check by reading the raw registry data.
        guard let data = UserDefaults.standard.data(forKey: "sakurawallpaper_screen_registry"),
              let registry = try? JSONDecoder().decode(Screen_Registry.self, from: data) else {
            return false
        }
        return registry[screenID] != nil
    }

    private func provisionNewScreen(id: String, screen: NSScreen) -> Screen_Config {
        let policy = SettingsManager.shared.newScreenPolicy
        var config: Screen_Config

        switch policy {
        case .inheritSyncGroup:
            let syncedIDs = NSScreen.screens
                .map { SettingsManager.screenIdentifier($0) }
                .filter { $0 != id && SettingsManager.shared.screenConfig(for: $0).isSynced }
            if let sourceID = syncedIDs.first {
                config = SettingsManager.shared.screenConfig(for: sourceID)
                config.isSynced = true
            } else {
                config = Screen_Config.default
                config.isSynced = false
            }

        case .blank:
            config = Screen_Config.default
            config.isSynced = false
        }

        SettingsManager.shared.setScreenConfig(config, for: id)
        return config
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

    // MARK: - Sync group management (Task 6.3)

    func setSynced(_ synced: Bool, for screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        var config = SettingsManager.shared.screenConfig(for: id)

        if synced {
            config.isSynced = true
            // Copy config from an existing synced screen if one exists
            let syncedScreenIDs = NSScreen.screens
                .map { SettingsManager.screenIdentifier($0) }
                .filter { SettingsManager.shared.screenConfig(for: $0).isSynced && $0 != id }
            if let sourceID = syncedScreenIDs.first {
                let sourceConfig = SettingsManager.shared.screenConfig(for: sourceID)
                config.folderPath = sourceConfig.folderPath
                config.rotationIntervalMinutes = sourceConfig.rotationIntervalMinutes
                config.isShuffleMode = sourceConfig.isShuffleMode
                config.isRotationEnabled = sourceConfig.isRotationEnabled
            }
            // Align playlist index to sync group
            if let folderPath = config.folderPath,
               FileManager.default.fileExists(atPath: folderPath) {
                let folderURL = URL(fileURLWithPath: folderPath)
                if let files = try? PlaylistBuilder.collectMediaFiles(in: folderURL, includeSubfolders: config.includeSubfolders) {
                    playlistsByScreen[id] = files
                    let alignedIndex = min(syncGroupPlaylistIndex, max(0, files.count - 1))
                    playlistIndexesByScreen[id] = alignedIndex
                    if let file = files.isEmpty ? nil : files[alignedIndex] {
                        currentFiles[id] = file
                        createOrUpdatePlayer(for: screen, url: file)
                    }
                }
            }
            SettingsManager.shared.setScreenConfig(config, for: id)
            // Stop independent timer, ensure sync group timer is running
            stopIndependentTimer(forScreenID: id)
            startSyncGroupTimerIfNeeded()
        } else {
            config.isSynced = false
            SettingsManager.shared.setScreenConfig(config, for: id)
            // Start independent timer for this screen
            startIndependentTimer(forScreenID: id)
            // Stop sync group timer if no more synced screens
            let remainingSynced = NSScreen.screens
                .map { SettingsManager.screenIdentifier($0) }
                .filter { SettingsManager.shared.screenConfig(for: $0).isSynced }
            if remainingSynced.isEmpty {
                stopSyncGroupTimer()
            }
        }
    }

    private func startSyncGroupTimerIfNeeded() {
        guard syncGroupTimer == nil else { return }
        // Find interval from any synced screen
        let syncedIDs = NSScreen.screens
            .map { SettingsManager.screenIdentifier($0) }
            .filter { SettingsManager.shared.screenConfig(for: $0).isSynced }
        guard let firstID = syncedIDs.first else { return }
        let config = SettingsManager.shared.screenConfig(for: firstID)
        guard config.isRotationEnabled else { return }
        let interval = TimeInterval(max(1, config.rotationIntervalMinutes) * 60)
        syncGroupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceSyncGroup()
        }
    }

    private func stopSyncGroupTimer() {
        syncGroupTimer?.invalidate()
        syncGroupTimer = nil
    }

    private func advanceSyncGroup() {
        syncGroupPlaylistIndex += 1
        let syncedScreens = NSScreen.screens.filter {
            SettingsManager.shared.screenConfig(for: SettingsManager.screenIdentifier($0)).isSynced
        }
        for screen in syncedScreens {
            let id = SettingsManager.screenIdentifier(screen)
            nextWallpaper(forScreenID: id)
            syncGroupPlaylistIndex = playlistIndexesByScreen[id] ?? syncGroupPlaylistIndex
        }
    }

    private func startIndependentTimer(forScreenID id: String) {
        stopIndependentTimer(forScreenID: id)
        guard let list = playlistsByScreen[id], list.count > 1 else { return }
        let config = SettingsManager.shared.screenConfig(for: id)
        guard config.isRotationEnabled else { return }
        let interval = TimeInterval(max(1, config.rotationIntervalMinutes) * 60)
        independentTimersByScreen[id] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.nextWallpaper(forScreenID: id)
        }
    }

    private func stopIndependentTimer(forScreenID id: String) {
        independentTimersByScreen[id]?.invalidate()
        independentTimersByScreen.removeValue(forKey: id)
    }

    func setWallpaper(url: URL) {
        let screens = NSScreen.screens
        stopAll()
        for screen in screens {
            let id = SettingsManager.screenIdentifier(screen)
            var config = Screen_Config.default
            config.wallpaperPath = url.path
            config.isFolderMode = false
            SettingsManager.shared.setScreenConfig(config, for: id)
            currentFiles[id] = url
        }
        SettingsManager.shared.addToHistory(url.path)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.createAllPlayers(for: screens)
            self?.startKeepVisibleTimer()
        }
    }

    func setWallpaper(url: URL, for screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        stopIndependentTimer(forScreenID: id)
        playlistsByScreen.removeValue(forKey: id)
        playlistIndexesByScreen.removeValue(forKey: id)

        players[id]?.cleanup()
        players.removeValue(forKey: id)

        var config = SettingsManager.shared.screenConfig(for: id)
        config.wallpaperPath = url.path
        config.folderPath = nil
        config.isFolderMode = false
        SettingsManager.shared.setScreenConfig(config, for: id)
        SettingsManager.shared.addToHistory(url.path)
        currentFiles[id] = url

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.createOrUpdatePlayer(for: screen, url: url)
            self.syncCurrentWallpaperToSystemDesktop(for: screen)
            if self.isPaused {
                self.players[id]?.pausePlayback()
                self.players[id]?.window?.orderOut(nil)
            }
            self.startKeepVisibleTimer()
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
        stopSyncGroupTimer()
        for (_, timer) in independentTimersByScreen { timer.invalidate() }
        independentTimersByScreen.removeAll()
        players.values.forEach { $0.cleanup() }
        players.removeAll()
        currentFiles.removeAll()
        pausedScreens.removeAll()
        playlistsByScreen.removeAll()
        playlistIndexesByScreen.removeAll()
        clearAllTransientDesktopSnapshots()
        // Restore original system desktop wallpapers for all screens
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            restoreOriginalDesktop(for: screen, screenID: id)
        }
        originalDesktopURLsByScreen.removeAll()
    }

    func stopWallpaper(for screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        players[id]?.cleanup()
        players.removeValue(forKey: id)
        currentFiles.removeValue(forKey: id)
        pausedScreens.remove(id)
        playlistsByScreen.removeValue(forKey: id)
        playlistIndexesByScreen.removeValue(forKey: id)
        stopIndependentTimer(forScreenID: id)
        clearTransientDesktopSnapshot(for: id)
        SettingsManager.shared.setScreenConfig(Screen_Config.default, for: id)
        // Restore original system desktop wallpaper for this screen
        restoreOriginalDesktop(for: screen, screenID: id)
        originalDesktopURLsByScreen.removeValue(forKey: id)
        if players.isEmpty { stopKeepVisibleTimer() }
    }

    private func restoreOriginalDesktop(for screen: NSScreen, screenID: String) {
        guard let originalURL = originalDesktopURLsByScreen[screenID],
              FileManager.default.fileExists(atPath: originalURL.path) else { return }
        do {
            let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
            try NSWorkspace.shared.setDesktopImageURL(originalURL, for: screen, options: options)
        } catch {
            print("Failed to restore original desktop for \(screenID): \(error)")
        }
    }

    private func selectPlaylistItem(at index: Int, forScreenID id: String) {
        guard let list = playlistsByScreen[id], index >= 0 && index < list.count else { return }
        playlistIndexesByScreen[id] = index
        let nextURL = list[index]
        currentFiles[id] = nextURL
        if let player = players[id] {
            player.updateMedia(url: nextURL)
            if isPaused || isPausedInternally {
                player.pausePlayback()
            }
        }
        if let screen = screen(forScreenID: id) {
            syncCurrentWallpaperToSystemDesktop(for: screen)
        }
        NotificationCenter.default.post(name: WallpaperManager.didRotateNotification, object: nil)
    }

    private func nextWallpaper(forScreenID id: String) {
        guard let list = playlistsByScreen[id], !list.isEmpty else { return }
        let config = SettingsManager.shared.screenConfig(for: id)
        guard config.isRotationEnabled else { return }

        let token = PerformanceMonitor.shared.begin("wallpaper.switch")
        let currentIndex = playlistIndexesByScreen[id] ?? 0
        let nextIndex = PlaylistBuilder.nextIndex(
            currentIndex: currentIndex,
            itemCount: list.count,
            shuffle: config.isShuffleMode
        )
        playlistIndexesByScreen[id] = nextIndex

        let nextURL = list[nextIndex]
        currentFiles[id] = nextURL
        if let player = players[id] {
            player.updateMedia(url: nextURL)
            if isPaused || isPausedInternally {
                player.pausePlayback()
            }
        }
        if let screen = screen(forScreenID: id) {
            syncCurrentWallpaperToSystemDesktop(for: screen)
        }
        PerformanceMonitor.shared.end(token, extra: "screen=\(id) file=\(nextURL.lastPathComponent)")
        NotificationCenter.default.post(name: WallpaperManager.didRotateNotification, object: nil)
    }

    private func screen(forScreenID id: String) -> NSScreen? {
        NSScreen.screens.first(where: { SettingsManager.screenIdentifier($0) == id })
    }

    private func currentMediaURL(forScreenID id: String) -> URL? {
        players[id]?.mediaURL ?? currentFiles[id]
    }

    private func startRotationTimer(forScreenID id: String) {
        stopIndependentTimer(forScreenID: id)
        guard let list = playlistsByScreen[id], list.count > 1 else { return }
        let config = SettingsManager.shared.screenConfig(for: id)
        guard config.isRotationEnabled else { return }
        let interval = TimeInterval(max(1, config.rotationIntervalMinutes) * 60)
        independentTimersByScreen[id] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.nextWallpaper(forScreenID: id)
        }
    }

    private func urlForScreen(_ screen: NSScreen) -> URL? {
        let id = SettingsManager.screenIdentifier(screen)
        if let currentURL = currentFiles[id], FileManager.default.fileExists(atPath: currentURL.path) {
            return currentURL
        }
        let config = SettingsManager.shared.screenConfig(for: id)
        if let path = config.wallpaperPath {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func createAllPlayers() {
        createAllPlayers(for: NSScreen.screens)
    }

    /// Overload that accepts a pre-captured screen snapshot (Bug 5 fix).
    /// Used by setWallpaper(url:) to ensure createAllPlayers operates on the same
    /// screen list that was current when stopAll() was called, eliminating sensitivity
    /// to topology changes in the asyncAfter window.
    private func createAllPlayers(for screens: [NSScreen]) {
        for screen in screens {
            let id = SettingsManager.screenIdentifier(screen)
            guard let url = urlForScreen(screen) else { continue }
            createOrUpdatePlayer(for: screen, url: url)
            currentFiles[id] = url
        }
    }

    private func createOrUpdatePlayer(for screen: NSScreen, url: URL) {
        let id = SettingsManager.screenIdentifier(screen)
        if let player = players[id] {
            // Resize the window and layers if the screen geometry has changed
            // (e.g. monitor reattached at a different resolution — Bug 1 fix).
            if player.window?.frame != screen.frame {
                player.resize(to: screen)
            }
            player.updateMedia(url: url)
        } else {
            let player = ScreenPlayer(fileURL: url, screen: screen)
            players[id] = player
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

    private func startBatteryCheckTimer() {
        guard batteryCheckTimer == nil else { return }
        batteryCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkPlaybackState()
        }
    }

    private func stopBatteryCheckTimer() {
        batteryCheckTimer?.invalidate()
        batteryCheckTimer = nil
    }

    private func shouldPauseForLowBattery() -> Bool {
        guard let battery = currentBatterySnapshot() else { return false }
        return !battery.isCharging && battery.level <= lowBatteryPauseThreshold
    }

    private func currentBatterySnapshot() -> (level: Int, isCharging: Bool)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = list.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else {
            return nil
        }

        guard let currentCapacity = info[kIOPSCurrentCapacityKey as String] as? Int,
              let maxCapacity = info[kIOPSMaxCapacityKey as String] as? Int,
              maxCapacity > 0
        else {
            return nil
        }

        let percentage = Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())
        let isCharging = (info[kIOPSIsChargingKey as String] as? Bool) == true
            || (info[kIOPSPowerSourceStateKey as String] as? String) == (kIOPSACPowerValue as String)
        return (level: percentage, isCharging: isCharging)
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

    // MARK: - Restore all screens (Task 6.7)

    func restoreAllScreens() {
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            let config = SettingsManager.shared.screenConfig(for: id)

            if let folderPath = config.folderPath,
               FileManager.default.fileExists(atPath: folderPath) {
                let folderURL = URL(fileURLWithPath: folderPath)
                setFolder(url: folderURL, for: screen, config: config)
            } else if let wallpaperPath = config.wallpaperPath,
                      FileManager.default.fileExists(atPath: wallpaperPath) {
                let wallpaperURL = URL(fileURLWithPath: wallpaperPath)
                setWallpaper(url: wallpaperURL, for: screen)
            }
            // else: leave stopped
        }
    }
}
