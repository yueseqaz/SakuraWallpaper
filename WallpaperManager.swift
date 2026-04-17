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
    private var rotationTimersByScreen: [String: Timer] = [:]
    private var uiScreenID: String?
    private let fileManager = FileManager.default
    private let lockScreenCaptureQueue = DispatchQueue(label: "com.sakura.wallpaper.lockscreen", qos: .userInitiated)
    private var transientDesktopSnapshotsByScreen: [String: URL] = [:]
    private var screensChangedWorkItem: DispatchWorkItem?

    static let didRotateNotification = Notification.Name("WallpaperManagerDidRotate")
    static let playbackStateDidChangeNotification = Notification.Name("WallpaperManagerPlaybackStateDidChange")

    var playlist: [URL] {
        let id = uiOrFirstPlaylistScreenID()
        return id.flatMap { playlistsByScreen[$0] } ?? []
    }

    var playlistItemCount: Int { playlist.count }

    var currentPlaylistIndex: Int {
        let id = uiOrFirstPlaylistScreenID()
        return id.flatMap { playlistIndexesByScreen[$0] } ?? 0
    }

    var currentFile: URL? {
        if let id = uiScreenID, let file = currentFiles[id] {
            return file
        }
        return currentFiles.values.first
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
        stopRotationTimer()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func setUIScreen(_ screen: NSScreen?) {
        uiScreenID = screen.map { SettingsManager.screenIdentifier($0) }
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
        if let id = uiScreenID {
            startRotationTimer(forScreenID: id)
            return
        }
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            startRotationTimer(forScreenID: id)
        }
    }

    @objc func nextWallpaper() {
        if let id = uiScreenID {
            nextWallpaper(forScreenID: id)
            return
        }
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

    func selectPlaylistItem(at index: Int) {
        if let id = uiScreenID {
            selectPlaylistItem(at: index, forScreenID: id)
            return
        }
        for id in playlistsByScreen.keys {
            selectPlaylistItem(at: index, forScreenID: id)
        }
    }

    func setFolder(url: URL) {
        let baseConfig = ScreenFolderConfig(
            folderPath: url.path,
            rotationIntervalMinutes: SettingsManager.shared.rotationIntervalMinutes,
            isShuffleMode: SettingsManager.shared.isShuffleMode,
            isRotationEnabled: SettingsManager.shared.isRotationEnabled,
            includeSubfolders: SettingsManager.shared.includeSubfolders
        )

        for screen in NSScreen.screens {
            setFolder(url: url, for: screen, config: baseConfig)
        }
        SettingsManager.shared.isFolderMode = true
        SettingsManager.shared.folderPath = url.path
    }

    func setFolder(url: URL, for screen: NSScreen, config: ScreenFolderConfig) {
        let id = SettingsManager.screenIdentifier(screen)
        let token = PerformanceMonitor.shared.begin("playlist.build")

        do {
            let files = try PlaylistBuilder.collectMediaFiles(in: url, includeSubfolders: config.includeSubfolders)
            playlistsByScreen[id] = files
            playlistIndexesByScreen[id] = 0
            PerformanceMonitor.shared.end(token, extra: "screen=\(id) count=\(files.count) recursive=\(config.includeSubfolders)")

            SettingsManager.shared.setFolderConfig(config, for: screen)
            SettingsManager.shared.isFolderMode = true
            SettingsManager.shared.folderPath = config.folderPath
            SettingsManager.shared.rotationIntervalMinutes = config.rotationIntervalMinutes
            SettingsManager.shared.isShuffleMode = config.isShuffleMode
            SettingsManager.shared.isRotationEnabled = config.isRotationEnabled
            SettingsManager.shared.includeSubfolders = config.includeSubfolders

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
            startRotationTimer(forScreenID: id)
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
        for screen in NSScreen.screens {
            syncCurrentWallpaperToSystemDesktop(for: screen)
        }
    }

    private func syncCurrentWallpaperToSystemDesktop(for screen: NSScreen) {
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
            let targetSize = CGSize(
                width: max(screen.frame.width * screen.backingScaleFactor, 1920),
                height: max(screen.frame.height * screen.backingScaleFactor, 1080)
            )

            lockScreenCaptureQueue.async { [weak self] in
                guard let self else { return }
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
                    self.applyDesktopImage(at: snapshotURL, for: screen, screenID: screenID)
                }
            }
        case .unsupported:
            break
        }
    }

    private func applyDesktopImage(at imageURL: URL, for screen: NSScreen, screenID: String) {
        do {
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

        for removedId in existingIds.subtracting(currentScreenIds) {
            players[removedId]?.cleanup()
            players.removeValue(forKey: removedId)
            currentFiles.removeValue(forKey: removedId)
            playlistsByScreen.removeValue(forKey: removedId)
            playlistIndexesByScreen.removeValue(forKey: removedId)
            stopRotationTimer(forScreenID: removedId)
            pausedScreens.remove(removedId)
            clearTransientDesktopSnapshot(for: removedId)
        }

        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            if players[id] != nil { continue }

            if let config = SettingsManager.shared.folderConfig(for: screen),
               FileManager.default.fileExists(atPath: config.folderPath) {
                let folderURL = URL(fileURLWithPath: config.folderPath)
                setFolder(url: folderURL, for: screen, config: config)
                continue
            }

            if let sourceScreen = inheritanceSourceScreen(excluding: id) {
                if let sourceConfig = SettingsManager.shared.folderConfig(for: sourceScreen),
                   FileManager.default.fileExists(atPath: sourceConfig.folderPath) {
                    let folderURL = URL(fileURLWithPath: sourceConfig.folderPath)
                    setFolder(url: folderURL, for: screen, config: sourceConfig)
                    continue
                }

                if let sourceURL = urlForScreen(sourceScreen),
                   FileManager.default.fileExists(atPath: sourceURL.path) {
                    setWallpaper(url: sourceURL, for: screen)
                    continue
                }
            }

            if SettingsManager.shared.isFolderMode,
               let globalFolderPath = SettingsManager.shared.folderPath,
               FileManager.default.fileExists(atPath: globalFolderPath) {
                let globalConfig = ScreenFolderConfig(
                    folderPath: globalFolderPath,
                    rotationIntervalMinutes: SettingsManager.shared.rotationIntervalMinutes,
                    isShuffleMode: SettingsManager.shared.isShuffleMode,
                    isRotationEnabled: SettingsManager.shared.isRotationEnabled,
                    includeSubfolders: SettingsManager.shared.includeSubfolders
                )
                let folderURL = URL(fileURLWithPath: globalFolderPath)
                setFolder(url: folderURL, for: screen, config: globalConfig)
                continue
            }

            if let url = urlForScreen(screen) {
                createOrUpdatePlayer(for: screen, url: url)
                currentFiles[id] = url
                syncCurrentWallpaperToSystemDesktop(for: screen)
            }
        }

        if isPaused {
            pauseAll()
        } else {
            showAll()
        }
    }

    private func inheritanceSourceScreen(excluding screenId: String) -> NSScreen? {
        let settings = SettingsManager.shared
        switch settings.newScreenInheritanceMode {
        case .primaryScreen:
            return primaryScreenForInheritance(excluding: screenId)
        case .specificScreen:
            if let sourceId = settings.newScreenInheritanceScreenId,
               sourceId != screenId,
               let sourceScreen = NSScreen.screens.first(where: { SettingsManager.screenIdentifier($0) == sourceId }) {
                return sourceScreen
            }
            return primaryScreenForInheritance(excluding: screenId)
        }
    }

    private func primaryScreenForInheritance(excluding screenId: String) -> NSScreen? {
        if let builtIn = NSScreen.screens.first(where: { $0.isBuiltIn && SettingsManager.screenIdentifier($0) != screenId }) {
            return builtIn
        }
        if let main = NSScreen.main,
           SettingsManager.screenIdentifier(main) != screenId {
            return main
        }
        return NSScreen.screens.first(where: { SettingsManager.screenIdentifier($0) != screenId })
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

    func setWallpaper(url: URL) {
        stopAll()
        SettingsManager.shared.clearAllFolderConfigs()
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
        let id = SettingsManager.screenIdentifier(screen)
        stopRotationTimer(forScreenID: id)
        playlistsByScreen.removeValue(forKey: id)
        playlistIndexesByScreen.removeValue(forKey: id)
        SettingsManager.shared.clearFolderConfig(for: screen)

        players[id]?.cleanup()
        players.removeValue(forKey: id)

        SettingsManager.shared.setWallpaper(path: url.path, for: screen)
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
        stopRotationTimer()
        players.values.forEach { $0.cleanup() }
        players.removeAll()
        currentFiles.removeAll()
        pausedScreens.removeAll()
        playlistsByScreen.removeAll()
        playlistIndexesByScreen.removeAll()
        clearAllTransientDesktopSnapshots()
    }

    func stopWallpaper(for screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        players[id]?.cleanup()
        players.removeValue(forKey: id)
        currentFiles.removeValue(forKey: id)
        pausedScreens.remove(id)
        playlistsByScreen.removeValue(forKey: id)
        playlistIndexesByScreen.removeValue(forKey: id)
        stopRotationTimer(forScreenID: id)
        clearTransientDesktopSnapshot(for: id)
        SettingsManager.shared.setWallpaper(path: nil, for: screen)
        SettingsManager.shared.clearFolderConfig(for: screen)
        if players.isEmpty { stopKeepVisibleTimer() }
    }

    private func uiOrFirstPlaylistScreenID() -> String? {
        // Keep playlist/thumbnail data strictly bound to the UI-selected screen.
        // If the selected screen has no folder playlist, return nil instead of
        // falling back to another screen's playlist.
        if let id = uiScreenID {
            return playlistsByScreen[id] != nil ? id : nil
        }
        return playlistsByScreen.keys.sorted().first
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
        guard let config = folderConfig(forScreenID: id), config.isRotationEnabled else { return }

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

    private func folderConfig(forScreenID id: String) -> ScreenFolderConfig? {
        guard let screen = screen(forScreenID: id) else { return nil }
        return SettingsManager.shared.folderConfig(for: screen)
    }

    private func screen(forScreenID id: String) -> NSScreen? {
        NSScreen.screens.first(where: { SettingsManager.screenIdentifier($0) == id })
    }

    private func currentMediaURL(forScreenID id: String) -> URL? {
        players[id]?.mediaURL ?? currentFiles[id]
    }

    private func startRotationTimer(forScreenID id: String) {
        stopRotationTimer(forScreenID: id)
        guard let list = playlistsByScreen[id], list.count > 1 else { return }
        guard let config = folderConfig(forScreenID: id), config.isRotationEnabled else { return }

        let interval = TimeInterval(max(1, config.rotationIntervalMinutes) * 60)
        rotationTimersByScreen[id] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.nextWallpaper(forScreenID: id)
        }
    }

    private func stopRotationTimer(forScreenID id: String) {
        rotationTimersByScreen[id]?.invalidate()
        rotationTimersByScreen.removeValue(forKey: id)
    }

    private func stopRotationTimer() {
        for timer in rotationTimersByScreen.values {
            timer.invalidate()
        }
        rotationTimersByScreen.removeAll()
    }

    private func urlForScreen(_ screen: NSScreen) -> URL? {
        let id = SettingsManager.screenIdentifier(screen)
        if let currentURL = currentFiles[id], FileManager.default.fileExists(atPath: currentURL.path) {
            return currentURL
        }
        if let path = SettingsManager.shared.wallpaperPath(for: screen) {
            return URL(fileURLWithPath: path)
        }
        if let url = SettingsManager.shared.wallpaperURL {
            return url
        }
        return nil
    }

    private func createAllPlayers() {
        for screen in NSScreen.screens {
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
            player.setVolume(0)
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
}
