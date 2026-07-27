import Cocoa
import AVFoundation
import IOKit.ps

public class WallpaperManager {
    enum PlaybackStatus {
        case stopped
        case playing
        case pausedManual
        case pausedAuto
    }

    private var players: [String: ScreenPlayer] = [:]
    public var currentFiles: [String: URL] = [:]
    public var isActive: Bool { !players.isEmpty }
    public var isPaused: Bool = false
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
    private var accessedSecurityScopedURLs: [URL] = []
    private let playbackStateQueue = DispatchQueue(label: "com.sakura.wallpaper.playback-state", qos: .userInitiated)
    private var playbackStateCheckInFlight = false
    private var playbackStateCheckPending = false
    private var wallpaperWindowsNeedReordering = true
    private var activeSpaceReorderWorkItem: DispatchWorkItem?
    private var suppressWallpaperReorderingUntil: CFAbsoluteTime = 0
    private var systemIsSleeping = false

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

    public init() {
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
            selector: #selector(activeSpaceChanged),
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
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
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
        activeSpaceReorderWorkItem?.cancel()
        stopKeepVisibleTimer()
        stopBatteryCheckTimer()
        stopSyncGroupTimer()
        for (_, timer) in independentTimersByScreen { timer.invalidate() }
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }


    @objc private func handleSleep() {
        systemIsSleeping = true
        if !isPausedInternally {
            isPausedInternally = true
            pauseAll()
            NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
        }
    }

    @objc public func checkPlaybackState() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.checkPlaybackState()
            }
            return
        }

        guard !systemIsSleeping else { return }

        guard SettingsManager.shared.pauseWhenInvisible, !players.isEmpty else {
            applyAutoPauseState(shouldPause: false)
            return
        }

        guard !playbackStateCheckInFlight else {
            playbackStateCheckPending = true
            return
        }

        playbackStateCheckInFlight = true
        let screenFrames = quartzScreenFrames()
        let currentPID = ProcessInfo.processInfo.processIdentifier

        // WindowServer queries can stall while a Space animation is in progress.
        playbackStateQueue.async { [weak self] in
            guard let self else { return }
            let battery = self.currentBatterySnapshot()
            let desktopCovered = Self.isDesktopCovered(
                screenFrames: screenFrames,
                currentPID: currentPID
            )
            let shouldPause = WallpaperBehavior.shouldAutoPausePlayback(
                pauseWhenInvisibleEnabled: true,
                batteryLevel: battery?.level,
                isCharging: battery?.isCharging ?? false,
                isDesktopCovered: desktopCovered,
                lowBatteryThreshold: self.lowBatteryPauseThreshold
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.playbackStateCheckInFlight = false

                if !self.systemIsSleeping,
                   !self.players.isEmpty,
                   SettingsManager.shared.pauseWhenInvisible {
                    self.applyAutoPauseState(shouldPause: shouldPause)
                } else if !self.systemIsSleeping {
                    self.applyAutoPauseState(shouldPause: false)
                }

                if self.playbackStateCheckPending {
                    self.playbackStateCheckPending = false
                    self.checkPlaybackState()
                }
            }
        }
    }

    @objc private func activeSpaceChanged() {
        wallpaperWindowsNeedReordering = true
        suppressWallpaperReorderingUntil = CFAbsoluteTimeGetCurrent() + 0.4

        if !isPaused && !isPausedInternally {
            players.forEach { id, player in
                guard !pausedScreens.contains(id) else { return }
                player.beginSpaceTransition()
            }
        }

        activeSpaceReorderWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isPaused, !self.isPausedInternally else { return }
            self.players.forEach { id, player in
                guard !self.pausedScreens.contains(id) else { return }
                player.endSpaceTransition()
            }
            self.showAll()
        }
        activeSpaceReorderWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
        checkPlaybackState()
    }

    @objc private func handleWake() {
        systemIsSleeping = false
        wallpaperWindowsNeedReordering = true
        checkPlaybackState()
    }

    private func applyAutoPauseState(shouldPause: Bool) {
        guard shouldPause else {
            if isPausedInternally {
                isPausedInternally = false
                if !isPaused {
                    resumeAll()
                    showAll()
                }
                NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
            }
            return
        }

        if !isPausedInternally {
            isPausedInternally = true
            pauseAll()
            NotificationCenter.default.post(name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
        }
    }

    public private(set) var isPausedInternally: Bool = false

    func startRotationTimer() {
        stopSyncGroupTimer()
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

    @objc public func nextWallpaper() {
        // Advance sync group as a unit
        let syncedIDs = Set(NSScreen.screens
            .map { SettingsManager.screenIdentifier($0) }
            .filter { SettingsManager.shared.screenConfig(for: $0).isSynced })
        if !syncedIDs.isEmpty {
            advanceSyncGroup()
        }
        // Advance each independent (non-synced) screen individually
        for id in playlistsByScreen.keys where !syncedIDs.contains(id) {
            nextWallpaper(forScreenID: id)
        }
    }

    public func nextWallpaper(for screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        let config = SettingsManager.shared.screenConfig(for: id)
        if config.isSynced {
            // Advance the entire sync group together
            advanceSyncGroup()
        } else {
            nextWallpaper(forScreenID: id)
        }
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
        let config = SettingsManager.shared.screenConfig(for: id)
        
        selectPlaylistItem(at: index, forScreenID: id)
        
        if config.isSynced {
            let syncedScreens = NSScreen.screens.filter {
                let sid = SettingsManager.screenIdentifier($0)
                return sid != id && SettingsManager.shared.screenConfig(for: sid).isSynced
            }
            for syncedScreen in syncedScreens {
                let sid = SettingsManager.screenIdentifier(syncedScreen)
                selectPlaylistItem(at: index, forScreenID: sid)
            }
        }
    }

    // MARK: - Centralized Sync Group Propagation

    /// Propagates settings from the source screen to all other synced screens.
    /// Call this after updating a screen's config when the change should be
    /// reflected across the entire sync group.
    func propagateSettingsToSyncGroup(fromScreenID sourceID: String) {
        let sourceConfig = SettingsManager.shared.screenConfig(for: sourceID)
        guard sourceConfig.isSynced else { return }

        let syncedScreens = NSScreen.screens.filter {
            let sid = SettingsManager.screenIdentifier($0)
            return sid != sourceID && SettingsManager.shared.screenConfig(for: sid).isSynced
        }
        for syncedScreen in syncedScreens {
            let sid = SettingsManager.screenIdentifier(syncedScreen)
            var syncedConfig = SettingsManager.shared.screenConfig(for: sid)
            syncedConfig.folderPath = sourceConfig.folderPath
            syncedConfig.wallpaperPath = sourceConfig.wallpaperPath
            syncedConfig.rotationIntervalMinutes = sourceConfig.rotationIntervalMinutes
            syncedConfig.isShuffleMode = sourceConfig.isShuffleMode
            syncedConfig.isRotationEnabled = sourceConfig.isRotationEnabled
            syncedConfig.includeSubfolders = sourceConfig.includeSubfolders
            syncedConfig.isFolderMode = sourceConfig.isFolderMode
            SettingsManager.shared.setScreenConfig(syncedConfig, for: sid)
        }
    }

    public func setFolder(url: URL, for screen: NSScreen, config: Screen_Config) {
        let id = SettingsManager.screenIdentifier(screen)
        let token = PerformanceMonitor.shared.begin("playlist.build")
        PlaylistBuilder.clearCache()

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

            // Propagate settings and rebuild playlists for synced peers
            if updatedConfig.isSynced {
                propagateSettingsToSyncGroup(fromScreenID: id)
                let syncedScreens = NSScreen.screens.filter {
                    let sid = SettingsManager.screenIdentifier($0)
                    return sid != id && SettingsManager.shared.screenConfig(for: sid).isSynced
                }
                for syncedScreen in syncedScreens {
                    let sid = SettingsManager.screenIdentifier(syncedScreen)
                    let syncedConfig = SettingsManager.shared.screenConfig(for: sid)
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

        guard let mediaURL = currentFiles[id] else { return }
        applySystemDesktopWallpaper(for: screen, screenID: id, mediaURL: mediaURL, playbackTime: nil)
    }

    private func syncCurrentPlayerToSystemDesktop(_ player: ScreenPlayer, for screen: NSScreen, screenID: String) {
        let mediaURL = player.mediaURL
        let playbackTime = player.currentPlaybackTime()
        applySystemDesktopWallpaper(for: screen, screenID: screenID, mediaURL: mediaURL, playbackTime: playbackTime)
    }

    private func applySystemDesktopWallpaper(for screen: NSScreen, screenID: String, mediaURL: URL, playbackTime: CMTime?) {
        let fitMode = SettingsManager.shared.screenConfig(for: screenID).wallpaperFit
        switch MediaType.detect(mediaURL) {
        case .image, .gif:
            clearTransientDesktopSnapshot(for: screenID)
            if fitMode == .fit, let compositedURL = self.compositedImageSnapshot(from: mediaURL, for: screen, screenID: screenID) {
                replaceTransientDesktopSnapshot(for: screenID, with: compositedURL)
                applyDesktopImage(at: compositedURL, for: screen, screenID: screenID)
            } else {
                applyDesktopImage(at: mediaURL, for: screen, screenID: screenID)
            }
        case .video:
            let outputURL = makeTransientSnapshotURL(for: screenID)

            lockScreenCaptureQueue.async { [weak self] in
                guard let self else { return }
                let liveScreen = NSScreen.screens.first(where: { SettingsManager.screenIdentifier($0) == screenID }) ?? screen
                let targetSize = CGSize(
                    width: max(liveScreen.frame.width * liveScreen.backingScaleFactor, 1920),
                    height: max(liveScreen.frame.height * liveScreen.backingScaleFactor, 1080)
                )
                guard let snapshotURL = self.createDesktopSnapshot(from: mediaURL, at: playbackTime, outputURL: outputURL, maxSize: targetSize, fitMode: fitMode) else {
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard SettingsManager.shared.syncDesktopWallpaper,
                          self.currentMediaURL(forScreenID: screenID) == mediaURL else {
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
            captureOriginalDesktopIfNeeded(for: screen, screenID: screenID)
            let options = desktopOptions(for: screen, screenID: screenID)
            try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: options)
        } catch {
            print("Failed to set system desktop image for \(screenID): \(error)")
        }
    }

    private func createDesktopSnapshot(from mediaURL: URL, at playbackTime: CMTime?, outputURL: URL, maxSize: CGSize, fitMode: WallpaperFitMode) -> URL? {
        let asset = AVURLAsset(url: mediaURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let targetTime = normalizedSnapshotTime(playbackTime)
        guard let frameCGImage = copyImage(using: generator, at: targetTime) ?? copyImage(using: generator, at: .zero) else {
            print("Failed to create current-frame snapshot from \(mediaURL.lastPathComponent)")
            return nil
        }

        let frameSize = NSSize(width: frameCGImage.width, height: frameCGImage.height)
        let canvasSize = maxSize

        // Only composite when fit mode produces letterboxing
        guard fitMode == .fit else {
            // For fill/stretch modes there are no letterbox gaps;
            // the raw frame is sufficient.
            return writeDesktopSnapshot(frameCGImage, to: outputURL)
        }

        // Composite the video frame onto a black canvas matching the screen
        // dimensions.  This bakes the background into the image so the lock
        // screen shows black instead of the system blue tint.
        guard let compositedCGImage = compositeImage(
            frameCGImage, size: frameSize,
            ontoCanvas: canvasSize,
            fitMode: fitMode
        ) else {
            return writeDesktopSnapshot(frameCGImage, to: outputURL)
        }

        return writeDesktopSnapshot(compositedCGImage, to: outputURL)
    }

    /// Generates a screen-sized composited snapshot for images and GIFs when
    /// the user has selected Fit mode — prevents the lock screen from showing
    /// blue bars in the letterbox areas.
    private func compositedImageSnapshot(from mediaURL: URL, for screen: NSScreen, screenID: String) -> URL? {
        guard let image = NSImage(contentsOf: mediaURL) else { return nil }
        let imageReps = image.representations
        let pixelSize: NSSize
        if let rep = imageReps.first {
            pixelSize = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        } else {
            pixelSize = image.size
        }
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }

        let canvasSize = CGSize(
            width: max(screen.frame.width * screen.backingScaleFactor, 1920),
            height: max(screen.frame.height * screen.backingScaleFactor, 1080)
        )

        let canvasImage = NSImage(size: NSSize(width: canvasSize.width, height: canvasSize.height))
        canvasImage.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: canvasImage.size).fill()

        let drawRect = fitDrawRect(imageSize: pixelSize, canvasSize: canvasSize, fitMode: .fit)
        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        canvasImage.unlockFocus()

        guard let cgImage = canvasImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let outputURL = makeTransientSnapshotURL(for: screenID)
        return writeDesktopSnapshot(cgImage, to: outputURL)
    }

    /// Draws a CGImage onto a black canvas sized to `canvasSize` and returns the
    /// composited result.
    private func compositeImage(_ cgImage: CGImage, size imageSize: NSSize, ontoCanvas canvasSize: CGSize, fitMode: WallpaperFitMode) -> CGImage? {
        let nsImage = NSImage(size: NSSize(width: canvasSize.width, height: canvasSize.height))
        nsImage.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: nsImage.size).fill()

        let drawRect = fitDrawRect(imageSize: imageSize, canvasSize: canvasSize, fitMode: fitMode)
        NSImage(cgImage: cgImage, size: imageSize).draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        nsImage.unlockFocus()

        return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// Returns the draw rect that positions an image of `imageSize` onto a
    /// canvas of `canvasSize` according to the given fit mode.
    private func fitDrawRect(imageSize: NSSize, canvasSize: CGSize, fitMode: WallpaperFitMode) -> NSRect {
        let cw = canvasSize.width
        let ch = canvasSize.height
        let iw = imageSize.width
        let ih = imageSize.height
        guard iw > 0, ih > 0 else { return NSRect(origin: .zero, size: canvasSize) }

        switch fitMode {
        case .fill:
            let scale = max(cw / iw, ch / ih)
            let w = iw * scale
            let h = ih * scale
            return NSRect(x: (cw - w) / 2, y: (ch - h) / 2, width: w, height: h)
        case .fit:
            let scale = min(cw / iw, ch / ih)
            let w = iw * scale
            let h = ih * scale
            return NSRect(x: (cw - w) / 2, y: (ch - h) / 2, width: w, height: h)
        case .stretch:
            return NSRect(x: 0, y: 0, width: cw, height: ch)
        }
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
        wallpaperWindowsNeedReordering = true
        if !isPaused && !isPausedInternally {
            resumeAll()
            showAll()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if self?.isPaused == false && self?.isPausedInternally == false {
                self?.resumeAll()
                self?.showAll()
            }
        }
        checkPlaybackState()
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
                config.wallpaperPath = sourceConfig.wallpaperPath
                config.rotationIntervalMinutes = sourceConfig.rotationIntervalMinutes
                config.isShuffleMode = sourceConfig.isShuffleMode
                config.isRotationEnabled = sourceConfig.isRotationEnabled
                config.includeSubfolders = sourceConfig.includeSubfolders
                config.isFolderMode = sourceConfig.isFolderMode
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
        let syncedScreenIDs = NSScreen.screens
            .filter { SettingsManager.shared.screenConfig(for: SettingsManager.screenIdentifier($0)).isSynced }
            .map { SettingsManager.screenIdentifier($0) }

        guard !syncedScreenIDs.isEmpty else { return }

        // Use the first synced screen's playlist to compute ONE shared next index
        guard let referenceID = syncedScreenIDs.first,
              let referenceList = playlistsByScreen[referenceID],
              !referenceList.isEmpty else { return }

        let config = SettingsManager.shared.screenConfig(for: referenceID)
        guard config.isRotationEnabled else { return }

        let currentIndex = playlistIndexesByScreen[referenceID] ?? 0
        let nextIndex = PlaylistBuilder.nextIndex(
            currentIndex: currentIndex,
            itemCount: referenceList.count,
            shuffle: config.isShuffleMode
        )
        syncGroupPlaylistIndex = nextIndex

        // Apply the same index to ALL synced screens
        for sid in syncedScreenIDs {
            guard let list = playlistsByScreen[sid], nextIndex < list.count else { continue }
            playlistIndexesByScreen[sid] = nextIndex
            let nextURL = list[nextIndex]
            currentFiles[sid] = nextURL
            if let player = players[sid] {
                player.updateMedia(url: nextURL)
                if isPaused || isPausedInternally || pausedScreens.contains(sid) {
                    player.pausePlayback()
                }
            }
            if let screen = screen(forScreenID: sid) {
                syncCurrentWallpaperToSystemDesktop(for: screen)
            }
        }
        NotificationCenter.default.post(name: WallpaperManager.didRotateNotification, object: nil)
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

    public func setWallpaper(url: URL) {
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

    public func setWallpaper(url: URL, for screen: NSScreen) {
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

        // Propagate config and tear down synced peers' playlists/players
        if config.isSynced {
            propagateSettingsToSyncGroup(fromScreenID: id)
            let syncedScreens = NSScreen.screens.filter {
                let sid = SettingsManager.screenIdentifier($0)
                return sid != id && SettingsManager.shared.screenConfig(for: sid).isSynced
            }
            for syncedScreen in syncedScreens {
                let sid = SettingsManager.screenIdentifier(syncedScreen)
                stopIndependentTimer(forScreenID: sid)
                playlistsByScreen.removeValue(forKey: sid)
                playlistIndexesByScreen.removeValue(forKey: sid)
                players[sid]?.cleanup()
                players.removeValue(forKey: sid)
                currentFiles[sid] = url
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.createOrUpdatePlayer(for: screen, url: url)
            self.syncCurrentWallpaperToSystemDesktop(for: screen)
            if self.isPaused || self.pausedScreens.contains(id) {
                self.players[id]?.pausePlayback()
                self.players[id]?.window?.orderOut(nil)
            }
            
            if config.isSynced {
                let syncedScreens = NSScreen.screens.filter {
                    let sid = SettingsManager.screenIdentifier($0)
                    return sid != id && SettingsManager.shared.screenConfig(for: sid).isSynced
                }
                for syncedScreen in syncedScreens {
                    let sid = SettingsManager.screenIdentifier(syncedScreen)
                    self.createOrUpdatePlayer(for: syncedScreen, url: url)
                    self.syncCurrentWallpaperToSystemDesktop(for: syncedScreen)
                    if self.isPaused || self.pausedScreens.contains(sid) {
                        self.players[sid]?.pausePlayback()
                        self.players[sid]?.window?.orderOut(nil)
                    }
                }
            }
            self.startKeepVisibleTimer()
        }
    }

    func wallpaperPath(for screen: NSScreen) -> String? {
        let id = SettingsManager.screenIdentifier(screen)
        return currentFiles[id]?.path
    }

    func refreshWallpaperFit(for screen: NSScreen) {
        let id = SettingsManager.screenIdentifier(screen)
        guard let url = currentFiles[id] ?? urlForScreen(screen) else { return }
        createOrUpdatePlayer(for: screen, url: url)
        syncCurrentWallpaperToSystemDesktop(for: screen)
    }

    func setSyncDesktopWallpaperEnabled(_ enabled: Bool) {
        let wasEnabled = SettingsManager.shared.syncDesktopWallpaper
        SettingsManager.shared.syncDesktopWallpaper = enabled

        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            let hasOriginalDesktopRecord = SettingsManager.shared.originalDesktopRecord(for: id) != nil
            let action = WallpaperBehavior.desktopSyncAction(
                wasEnabled: wasEnabled,
                isEnabled: enabled,
                hasOriginalDesktopRecord: hasOriginalDesktopRecord
            )

            switch action {
            case .none:
                break
            case .syncCurrentWallpaper:
                syncCurrentWallpaperToSystemDesktop(for: screen)
            case .restoreOriginalDesktop:
                clearTransientDesktopSnapshot(for: id)
                _ = restoreOriginalDesktop(for: screen, screenID: id)
            }
        }
    }

    public func stopAll() {
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
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            _ = restoreOriginalDesktop(for: screen, screenID: id)
        }
    }

    public func stopWallpaper(for screen: NSScreen) {
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
        _ = restoreOriginalDesktop(for: screen, screenID: id)
        if players.isEmpty { stopKeepVisibleTimer() }
    }

    @discardableResult
    private func restoreOriginalDesktop(for screen: NSScreen, screenID: String) -> Bool {
        guard let record = SettingsManager.shared.originalDesktopRecord(for: screenID),
              FileManager.default.fileExists(atPath: record.imagePath) else { return false }
        do {
            try NSWorkspace.shared.setDesktopImageURL(record.imageURL, for: screen, options: record.desktopImageOptions)
            SettingsManager.shared.removeOriginalDesktopRecord(for: screenID)
            return true
        } catch {
            print("Failed to restore original desktop for \(screenID): \(error)")
            return false
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
        let fitMode = SettingsManager.shared.screenConfig(for: id).wallpaperFit
        if let player = players[id] {
            // Resize the window and layers if the screen geometry has changed
            // (e.g. monitor reattached at a different resolution — Bug 1 fix).
            if player.window?.frame != screen.frame {
                player.resize(to: screen)
            }
            player.updateFitMode(fitMode)
            player.updateMedia(url: url)
        } else {
            let player = ScreenPlayer(fileURL: url, screen: screen, fitMode: fitMode)
            players[id] = player
        }
    }

    private func showAll() {
        guard CFAbsoluteTimeGetCurrent() >= suppressWallpaperReorderingUntil else { return }

        let needsReordering = wallpaperWindowsNeedReordering
        players.forEach { id, player in
            guard !pausedScreens.contains(id) else { return }
            guard needsReordering || player.window?.isVisible == false else { return }
            player.window?.orderBack(nil)
        }
        wallpaperWindowsNeedReordering = false
    }

    private func startKeepVisibleTimer() {
        keepVisibleTimer?.invalidate()
        keepVisibleTimer = Timer.scheduledTimer(withTimeInterval: keepVisibleInterval, repeats: true) { [weak self] _ in
            self?.checkPlaybackState()
            guard let self, !self.isPaused, !self.isPausedInternally else { return }
            self.showAll()
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

    public func restoreAllScreens() {
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            var config = SettingsManager.shared.screenConfig(for: id)

            // Resolve security-scoped bookmark for persistent folder access
            // without repeated TCC permission prompts
            if let bookmarkData = config.securityScopedBookmark {
                var isStale = false
                if let resolvedURL = try? URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ) {
                    if resolvedURL.startAccessingSecurityScopedResource() {
                        accessedSecurityScopedURLs.append(resolvedURL)
                    }
                    if isStale {
                        // Refresh stale bookmark
                        if let newBookmark = try? resolvedURL.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        ) {
                            config.securityScopedBookmark = newBookmark
                            SettingsManager.shared.setScreenConfig(config, for: id)
                        }
                    }
                }
            }

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

    func stopAllSecurityScopedAccess() {
        for url in accessedSecurityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        accessedSecurityScopedURLs.removeAll()
    }

    private func captureOriginalDesktopIfNeeded(for screen: NSScreen, screenID: String) {
        guard SettingsManager.shared.originalDesktopRecord(for: screenID) == nil,
              let currentURL = NSWorkspace.shared.desktopImageURL(for: screen),
              !isTransientSnapshotURL(currentURL) else { return }

        let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
        SettingsManager.shared.setOriginalDesktopRecord(
            OriginalDesktopRecord(imageURL: currentURL, desktopOptions: options),
            for: screenID
        )
    }

    private func desktopOptions(for screen: NSScreen, screenID: String) -> [NSWorkspace.DesktopImageOptionKey: Any] {
        let currentOptions = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
        return currentOptions.merging(fitDesktopOptions(for: SettingsManager.shared.screenConfig(for: screenID).wallpaperFit)) { _, new in
            new
        }
    }

    private func fitDesktopOptions(for fitMode: WallpaperFitMode) -> [NSWorkspace.DesktopImageOptionKey: Any] {
        switch fitMode {
        case .fill:
            return [
                .imageScaling: NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue),
                .allowClipping: NSNumber(value: true)
            ]
        case .fit:
            return [
                .imageScaling: NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue),
                .allowClipping: NSNumber(value: false)
            ]
        case .stretch:
            return [
                .imageScaling: NSNumber(value: NSImageScaling.scaleAxesIndependently.rawValue),
                .allowClipping: NSNumber(value: false)
            ]
        }
    }

    private func isTransientSnapshotURL(_ url: URL) -> Bool {
        url.path.contains("/SakuraWallpaper/lockscreen-current-")
    }

    private func quartzScreenFrames() -> [CGRect] {
        let screens = NSScreen.screens
        let frames: [CGRect] = screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
        }
        return frames.count == screens.count ? frames : []
    }

    private static func isDesktopCovered(screenFrames: [CGRect], currentPID: pid_t) -> Bool {
        guard !screenFrames.isEmpty,
              let windowList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
              ) as? [[String: Any]] else { return false }

        let coveringWindowFrames = windowList.compactMap { window -> CGRect? in
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }

            let alpha = window[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0.01 else { return nil }

            if let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t, ownerPID == currentPID {
                return nil
            }

            let ownerName = window[kCGWindowOwnerName as String] as? String ?? ""
            if ownerName == "Dock" || ownerName == "Window Server" {
                return nil
            }

            guard let boundsDictionary = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
                  bounds.width > 32,
                  bounds.height > 32 else { return nil }

            return bounds
        }

        // Playback is global, so keep it running while any configured desktop remains visible.
        return screenFrames.allSatisfy { screenFrame in
            coveringWindowFrames.contains { windowFrame in
                WallpaperBehavior.isScreenCovered(screenFrame, by: windowFrame)
            }
        }
    }
}
