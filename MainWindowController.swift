import Cocoa
import AVFoundation
import AVKit
import CoreGraphics

class MainWindowController: NSWindowController, NSCollectionViewDataSource, NSCollectionViewDelegate {
    let wallpaperManager: WallpaperManager

    private var previewImageView: NSImageView!
    private var previewPlayerLayer: AVPlayerLayer!
    private var previewPlayer: AVPlayer?
    private var previewEndObserver: Any?
    private var previewContainer: NSView!
    private var fileNameLabel: NSTextField!
    private var fileTypeLabel: NSTextField!
    private var statusIndicator: NSView!
    private var statusLabel: NSTextField!
    private var selectFileButton: NSButton!
    private var selectFolderButton: NSButton!
    private var stopButton: NSButton!
    private var applyAllButton: NSButton!
    private var launchSwitch: NSButton!
    private var pauseSwitch: NSButton!
    private var rotationSwitch: NSButton!
    private var shuffleSwitch: NSButton!
    private var intervalField: NSTextField!
    private var intervalStepper: NSStepper!
    private var intervalLabel: NSTextField!
    private var intervalPrefix: NSTextField!
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    private var dropZone: NSView!
    private var dropLabel: NSTextField!
    private var screenPopUp: NSPopUpButton!
    private var selectedScreen: NSScreen?

    init(wallpaperManager: WallpaperManager) {
        self.wallpaperManager = wallpaperManager
        self.selectedScreen = NSScreen.main
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "app.name".localized
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor.windowBackgroundColor
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        contentView.addSubview(createHeader())
        contentView.addSubview(createScreenSelector())
        contentView.addSubview(createPreviewContainer())
        contentView.addSubview(createInfoBar())
        contentView.addSubview(createControls())
        contentView.addSubview(createSettings())
        contentView.addSubview(createFooter())

        NotificationCenter.default.addObserver(self, selector: #selector(rotationHappened), name: WallpaperManager.didRotateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(statusChanged), name: WallpaperManager.playbackStateDidChangeNotification, object: nil)

        updateUI()
    }

    @objc private func statusChanged() {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }

    @objc private func rotationHappened() {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.updateUI()
        }
    }

    private func createHeader() -> NSView {
        let header = NSView(frame: NSRect(x: 0, y: 560, width: 500, height: 60))

        let appIcon = NSTextField(labelWithString: "🌸")
        appIcon.font = NSFont.systemFont(ofSize: 32)
        appIcon.frame = NSRect(x: 20, y: 10, width: 40, height: 40)
        header.addSubview(appIcon)

        let title = NSTextField(labelWithString: "app.name".localized)
        title.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        title.frame = NSRect(x: 65, y: 15, width: 250, height: 28)
        header.addSubview(title)

        let statusContainer = NSView(frame: NSRect(x: 350, y: 10, width: 130, height: 40))
        statusIndicator = NSView(frame: NSRect(x: 0, y: 14, width: 8, height: 8))
        statusIndicator.wantsLayer = true
        statusIndicator.layer?.cornerRadius = 4
        statusIndicator.layer?.backgroundColor = NSColor.systemGray.cgColor
        statusContainer.addSubview(statusIndicator)

        statusLabel = NSTextField(labelWithString: "ui.status".localized("ui.notSet".localized))
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 15, y: 10, width: 110, height: 16)
        statusContainer.addSubview(statusLabel)
        header.addSubview(statusContainer)

        let separator = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 1))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        header.addSubview(separator)

        return header
    }

    private func createScreenSelector() -> NSView {
        let container = NSView(frame: NSRect(x: 20, y: 510, width: 460, height: 40))

        let label = NSTextField(labelWithString: "\("ui.screen".localized):")
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.frame = NSRect(x: 0, y: 10, width: 60, height: 20)
        container.addSubview(label)

        screenPopUp = NSPopUpButton(frame: NSRect(x: 65, y: 8, width: 220, height: 25))
        screenPopUp.target = self
        screenPopUp.action = #selector(screenSelectionChanged)
        container.addSubview(screenPopUp)

        applyAllButton = NSButton(title: "ui.applyToAll".localized, target: self, action: #selector(applyToAllScreens))
        applyAllButton.bezelStyle = .recessed
        applyAllButton.font = NSFont.systemFont(ofSize: 11)
        applyAllButton.frame = NSRect(x: 295, y: 8, width: 120, height: 25)
        container.addSubview(applyAllButton)

        updateScreenMenu()

        return container
    }

    private func updateScreenMenu() {
        screenPopUp.removeAllItems()
        
        // Option 1: All Screens
        screenPopUp.addItem(withTitle: "ui.allScreens".localized)
        screenPopUp.lastItem?.representedObject = nil

        // Individual Screens
        for (index, screen) in NSScreen.screens.enumerated() {
            let displayName: String
            if #available(macOS 10.15, *) {
                displayName = screen.localizedName
            } else {
                displayName = "screen.display".localized(index + 1)
            }
            let isBuiltIn = screen.isBuiltIn
            let suffix = isBuiltIn ? "screen.builtIn".localized : ""
            screenPopUp.addItem(withTitle: "  \(displayName)\(suffix)")
            screenPopUp.lastItem?.representedObject = screen
        }
        
        if let selected = selectedScreen, let index = NSScreen.screens.firstIndex(of: selected) {
            screenPopUp.selectItem(at: index + 1)
        } else {
            screenPopUp.selectItem(at: 0)
            selectedScreen = nil
        }
    }

    @objc private func screenSelectionChanged(_ sender: NSPopUpButton) {
        selectedScreen = sender.selectedItem?.representedObject as? NSScreen
        updateUI()
    }

    @objc private func applyToAllScreens() {
        if SettingsManager.shared.isFolderMode {
            if let path = SettingsManager.shared.folderPath {
                wallpaperManager.setFolder(url: URL(fileURLWithPath: path))
            }
        } else if let url = wallpaperManager.currentFile {
            wallpaperManager.setWallpaper(url: url)
            SettingsManager.shared.wallpaperPath = url.path
        }
        updateUI()
    }

    private func createPreviewContainer() -> NSView {
        previewContainer = NSView(frame: NSRect(x: 20, y: 260, width: 460, height: 240))
        previewContainer.wantsLayer = true
        previewContainer.layer?.cornerRadius = 12
        previewContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        previewContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        previewContainer.layer?.borderWidth = 1
        previewContainer.layer?.masksToBounds = true

        dropZone = NSView(frame: previewContainer.bounds)
        dropZone.wantsLayer = true

        let icon = NSTextField(labelWithString: "📁")
        icon.font = NSFont.systemFont(ofSize: 40)
        icon.alignment = .center
        icon.frame = NSRect(x: 0, y: 140, width: 460, height: 50)
        dropZone.addSubview(icon)

        dropLabel = NSTextField(labelWithString: "ui.dropHere".localized)
        dropLabel.font = NSFont.systemFont(ofSize: 13)
        dropLabel.textColor = .secondaryLabelColor
        dropLabel.alignment = .center
        dropLabel.frame = NSRect(x: 0, y: 110, width: 460, height: 20)
        dropZone.addSubview(dropLabel)

        let formats = NSTextField(labelWithString: "ui.formats".localized)
        formats.font = NSFont.systemFont(ofSize: 10)
        formats.textColor = .tertiaryLabelColor
        formats.alignment = .center
        formats.frame = NSRect(x: 0, y: 90, width: 460, height: 16)
        dropZone.addSubview(formats)

        previewContainer.addSubview(dropZone)

        previewImageView = NSImageView(frame: previewContainer.bounds)
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.imageAlignment = .alignCenter
        previewImageView.isHidden = true
        previewContainer.addSubview(previewImageView)

        previewPlayerLayer = AVPlayerLayer()
        previewPlayerLayer.videoGravity = .resizeAspectFill
        previewPlayerLayer.frame = previewContainer.bounds
        previewContainer.layer?.addSublayer(previewPlayerLayer)

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 80, height: 80)
        layout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.scrollDirection = .horizontal

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.delegate = self
        collectionView.register(ThumbnailItem.self, forItemWithIdentifier: ThumbnailItem.identifier)
        collectionView.dataSource = self

        scrollView = NSScrollView(frame: previewContainer.bounds)
        scrollView.documentView = collectionView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.isHidden = true
        previewContainer.addSubview(scrollView)

        return previewContainer
    }

    private func createInfoBar() -> NSView {
        let bar = NSView(frame: NSRect(x: 20, y: 220, width: 460, height: 30))

        fileNameLabel = NSTextField(labelWithString: "ui.noWallpaper".localized)
        fileNameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        fileNameLabel.lineBreakMode = .byTruncatingMiddle
        fileNameLabel.frame = NSRect(x: 0, y: 6, width: 340, height: 16)
        bar.addSubview(fileNameLabel)

        fileTypeLabel = NSTextField(labelWithString: "")
        fileTypeLabel.font = NSFont.systemFont(ofSize: 10)
        fileTypeLabel.textColor = .secondaryLabelColor
        fileTypeLabel.alignment = .right
        fileTypeLabel.frame = NSRect(x: 350, y: 6, width: 110, height: 16)
        bar.addSubview(fileTypeLabel)

        return bar
    }

    private func createControls() -> NSView {
        let controls = NSView(frame: NSRect(x: 20, y: 160, width: 460, height: 50))

        selectFileButton = NSButton(title: "ui.selectFile".localized, target: self, action: #selector(selectFile))
        selectFileButton.bezelStyle = .rounded
        selectFileButton.frame = NSRect(x: 0, y: 5, width: 110, height: 40)
        controls.addSubview(selectFileButton)

        selectFolderButton = NSButton(title: "ui.selectFolder".localized, target: self, action: #selector(selectFolder))
        selectFolderButton.bezelStyle = .rounded
        selectFolderButton.frame = NSRect(x: 115, y: 5, width: 110, height: 40)
        controls.addSubview(selectFolderButton)

        stopButton = NSButton(title: "ui.stopWallpaper".localized, target: self, action: #selector(stopWallpaper))
        stopButton.bezelStyle = .rounded
        stopButton.controlSize = .large
        stopButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        stopButton.frame = NSRect(x: 230, y: 5, width: 160, height: 40)
        controls.addSubview(stopButton)

        return controls
    }

    private func createSettings() -> NSView {
        let settings = NSView(frame: NSRect(x: 20, y: 50, width: 460, height: 100))

        launchSwitch = NSButton(checkboxWithTitle: "ui.launchAtLogin".localized,
                                target: self, action: #selector(launchSwitchChanged))
        launchSwitch.font = NSFont.systemFont(ofSize: 12)
        launchSwitch.frame = NSRect(x: 0, y: 70, width: 120, height: 20)
        launchSwitch.state = SettingsManager.shared.launchAtLogin ? .on : .off
        settings.addSubview(launchSwitch)

        pauseSwitch = NSButton(checkboxWithTitle: "ui.pauseWhenInvisible".localized,
                               target: self, action: #selector(pauseSwitchChanged))
        pauseSwitch.font = NSFont.systemFont(ofSize: 12)
        pauseSwitch.frame = NSRect(x: 130, y: 70, width: 160, height: 20)
        pauseSwitch.state = SettingsManager.shared.pauseWhenInvisible ? .on : .off
        settings.addSubview(pauseSwitch)

        rotationSwitch = NSButton(checkboxWithTitle: "ui.enableRotation".localized,
                                  target: self, action: #selector(rotationSwitchChanged))
        rotationSwitch.font = NSFont.systemFont(ofSize: 12)
        rotationSwitch.frame = NSRect(x: 300, y: 70, width: 120, height: 20)
        rotationSwitch.state = SettingsManager.shared.isRotationEnabled ? .on : .off
        settings.addSubview(rotationSwitch)

        shuffleSwitch = NSButton(checkboxWithTitle: "ui.shuffleMode".localized,
                                 target: self, action: #selector(shuffleSwitchChanged))
        shuffleSwitch.font = NSFont.systemFont(ofSize: 12)
        shuffleSwitch.frame = NSRect(x: 0, y: 30, width: 150, height: 20)
        shuffleSwitch.state = SettingsManager.shared.isShuffleMode ? .on : .off
        settings.addSubview(shuffleSwitch)

        intervalPrefix = NSTextField(labelWithString: "ui.rotationInterval".localized + ":")
        intervalPrefix.font = NSFont.systemFont(ofSize: 12)
        intervalPrefix.frame = NSRect(x: 160, y: 30, width: 120, height: 20)
        settings.addSubview(intervalPrefix)

        intervalField = NSTextField(frame: NSRect(x: 285, y: 30, width: 50, height: 22))
        intervalField.font = NSFont.systemFont(ofSize: 12)
        intervalField.alignment = .right
        intervalField.target = self
        intervalField.action = #selector(intervalFieldChanged)
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 1
        intervalField.formatter = formatter
        intervalField.integerValue = SettingsManager.shared.rotationIntervalMinutes
        settings.addSubview(intervalField)

        intervalStepper = NSStepper(frame: NSRect(x: 335, y: 30, width: 15, height: 22))
        intervalStepper.minValue = 1
        intervalStepper.maxValue = 1440
        intervalStepper.increment = 1
        intervalStepper.valueWraps = false
        intervalStepper.integerValue = SettingsManager.shared.rotationIntervalMinutes
        intervalStepper.target = self
        intervalStepper.action = #selector(intervalStepperChanged)
        settings.addSubview(intervalStepper)

        intervalLabel = NSTextField(labelWithString: formatInterval(minutes: SettingsManager.shared.rotationIntervalMinutes))
        intervalLabel.font = NSFont.systemFont(ofSize: 11)
        intervalLabel.textColor = .secondaryLabelColor
        intervalLabel.frame = NSRect(x: 360, y: 30, width: 140, height: 20)
        settings.addSubview(intervalLabel)

        return settings
    }

    private func createFooter() -> NSView {
        let footer = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 40))

        let separator = NSView(frame: NSRect(x: 20, y: 35, width: 460, height: 1))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        footer.addSubview(separator)

        let author = NSTextField(labelWithString: "ui.madeBy".localized("❤️"))
        author.font = NSFont.systemFont(ofSize: 11)
        author.textColor = .secondaryLabelColor
        author.alignment = .center
        author.frame = NSRect(x: 20, y: 10, width: 460, height: 16)
        footer.addSubview(author)

        return footer
    }

    @objc func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        openPicker(panel: panel)
    }

    @objc func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        openPicker(panel: panel)
    }

    private func openPicker(panel: NSOpenPanel) {
        panel.title = "ui.chooseWallpaper".localized
        panel.allowsMultipleSelection = false

        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [
                .mpeg4Movie, .quickTimeMovie, .gif, .movie,
                .png, .jpeg, .heic, .webP, .bmp, .tiff
            ]
        } else {
            panel.allowedFileTypes = ["mp4", "mov", "gif", "m4v",
                                       "png", "jpg", "jpeg", "heic", "webp", "bmp", "tiff"]
        }

        NSApp.activate(ignoringOtherApps: true)

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try setWallpaper(url: url)
            } catch {
                showError(error)
            }
        }
    }

    private func setWallpaper(url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw WallpaperError.fileNotFound
        }

        if isDir.boolValue {
            wallpaperManager.setFolder(url: url)
        } else {
            let type = MediaType.detect(url)
            guard type != .unsupported else {
                throw WallpaperError.unsupportedFormat
            }
            SettingsManager.shared.isFolderMode = false

            if let screen = selectedScreen {
                wallpaperManager.setWallpaper(url: url, for: screen)
            } else {
                wallpaperManager.setWallpaper(url: url)
                SettingsManager.shared.wallpaperPath = url.path
            }
        }
        updateUI()
        (NSApp.delegate as? AppDelegate)?.rebuildRecentMenu()
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = error.localizedDescription
        alert.informativeText = (error as? WallpaperError)?.recoverySuggestion ?? ""
        alert.alertStyle = .warning
        alert.addButton(withTitle: "alert.ok".localized)
        alert.beginSheetModal(for: window!)
    }

    @objc func stopWallpaper() {
        if let screen = selectedScreen {
            wallpaperManager.stopWallpaper(for: screen)
        } else {
            wallpaperManager.stopAll()
            SettingsManager.shared.wallpaperPath = nil
            SettingsManager.shared.isFolderMode = false
            SettingsManager.shared.folderPath = nil
        }
        updateUI()
        (NSApp.delegate as? AppDelegate)?.rebuildRecentMenu()
    }

    @objc func launchSwitchChanged(_ sender: NSButton) {
        SettingsManager.shared.launchAtLogin = (sender.state == .on)
    }

    @objc func pauseSwitchChanged(_ sender: NSButton) {
        SettingsManager.shared.pauseWhenInvisible = (sender.state == .on)
        wallpaperManager.checkPlaybackState()
    }

    @objc func shuffleSwitchChanged(_ sender: NSButton) {
        SettingsManager.shared.isShuffleMode = (sender.state == .on)
        updateUI()
    }

    @objc func rotationSwitchChanged(_ sender: NSButton) {
        SettingsManager.shared.isRotationEnabled = (sender.state == .on)
        if sender.state == .on {
            wallpaperManager.startRotationTimer()
        } else {
            // Timer is stopped inside startRotationTimer if guard fails, 
            // but let's be explicit if needed. WallpaperManager handles it.
            wallpaperManager.startRotationTimer() 
        }
        updateUI()
    }

    @objc func intervalFieldChanged(_ sender: NSTextField) {
        let val = max(1, sender.integerValue)
        sender.integerValue = val
        intervalStepper.integerValue = val
        updateInterval(minutes: val)
    }

    @objc func intervalStepperChanged(_ sender: NSStepper) {
        let val = sender.integerValue
        intervalField.integerValue = val
        updateInterval(minutes: val)
    }

    private func updateInterval(minutes: Int) {
        SettingsManager.shared.rotationIntervalMinutes = minutes
        intervalLabel.stringValue = formatInterval(minutes: minutes)
        if SettingsManager.shared.isFolderMode && SettingsManager.shared.isRotationEnabled {
            wallpaperManager.startRotationTimer()
        }
    }

    private func formatInterval(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) \("ui.minutes".localized)"
        }
        let hrs = minutes / 60
        let remainingMinutes = minutes % 60
        let hrString = hrs == 1 ? "ui.hour".localized : "ui.hours".localized
        
        if remainingMinutes == 0 {
            return "\(hrs) \(hrString)"
        }
        return "\(hrs) \(hrString) \(remainingMinutes) \("ui.minutes".localized)"
    }

    private var currentPreviewPath: String?

    func updateUI() {
        updateScreenMenu()

        let isAllScreens = (selectedScreen == nil)
        stopButton.isEnabled = isAllScreens ? wallpaperManager.isActive : (wallpaperManager.wallpaperPath(for: selectedScreen!) != nil)
        stopButton.title = isAllScreens ? "ui.stopWallpaper".localized : "\("ui.stopWallpaper".localized) (\("ui.screen".localized))"
        applyAllButton.isEnabled = !isAllScreens
        
        let isFolderMode = SettingsManager.shared.isFolderMode
        let isRotationEnabled = SettingsManager.shared.isRotationEnabled
        let isShuffleMode = SettingsManager.shared.isShuffleMode
        
        rotationSwitch.isEnabled = isFolderMode
        rotationSwitch.state = isRotationEnabled ? .on : .off
        
        shuffleSwitch.isEnabled = isFolderMode && isRotationEnabled
        shuffleSwitch.state = isShuffleMode ? .on : .off
        
        intervalField.isEnabled = isFolderMode && isRotationEnabled
        intervalStepper.isEnabled = isFolderMode && isRotationEnabled
        
        rotationSwitch.contentTintColor = isFolderMode ? nil : .disabledControlTextColor
        shuffleSwitch.contentTintColor = (isFolderMode && isRotationEnabled) ? nil : .disabledControlTextColor
        intervalPrefix.textColor = (isFolderMode && isRotationEnabled) ? .labelColor : .disabledControlTextColor
        intervalLabel.textColor = (isFolderMode && isRotationEnabled) ? .secondaryLabelColor : .disabledControlTextColor

        var wallpaperPath: String?
        var isCurrentlyPaused = false

        if let screen = selectedScreen {
            wallpaperPath = wallpaperManager.wallpaperPath(for: screen)
                ?? SettingsManager.shared.wallpaperPath(for: screen)
            isCurrentlyPaused = wallpaperManager.isPaused || wallpaperManager.isScreenPaused(screen)
        } else {
            wallpaperPath = SettingsManager.shared.wallpaperPath
            isCurrentlyPaused = wallpaperManager.isPaused
        }

        if let path = wallpaperPath,
           FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            let filename = (path as NSString).lastPathComponent
            let type = MediaType.detect(url)

            if isFolderMode {
                let current = wallpaperManager.currentPlaylistIndex + 1
                let total = wallpaperManager.playlist.count
                let shuffleIcon = isShuffleMode ? "🔀 " : ""
                fileNameLabel.stringValue = "\(shuffleIcon)\(filename) (\(current)/\(total))"
                fileTypeLabel.stringValue = "ui.folderMode".localized
            } else {
                fileNameLabel.stringValue = filename
                fileTypeLabel.stringValue = type == .video ? "ui.video".localized : "ui.image".localized
            }

            let isAutoPaused = SettingsManager.shared.pauseWhenInvisible && wallpaperManager.isPausedInternally
            if isCurrentlyPaused || isAutoPaused {
                statusIndicator.layer?.backgroundColor = NSColor.systemYellow.cgColor
                statusLabel.stringValue = "ui.status".localized("ui.paused".localized)
                statusLabel.textColor = .systemYellow
                previewPlayer?.pause()
            } else {
                statusIndicator.layer?.backgroundColor = NSColor.systemGreen.cgColor
                statusLabel.stringValue = "ui.status".localized("ui.playing".localized)
                statusLabel.textColor = .systemGreen
                previewPlayer?.play()
            }

            showPreview(url: url, type: type)
        } else {
            currentPreviewPath = nil
            clearPreview()
            fileNameLabel.stringValue = "ui.noWallpaper".localized
            fileTypeLabel.stringValue = ""

            statusIndicator.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            statusLabel.stringValue = "ui.status".localized("ui.notSet".localized)
            statusLabel.textColor = .secondaryLabelColor

            dropZone.isHidden = false
            dropLabel.stringValue = "ui.dropHere".localized
            previewImageView.isHidden = true
            previewPlayerLayer.isHidden = true
        }
    }

    private func showPreview(url: URL, type: MediaType) {
        if currentPreviewPath == url.path {
            if SettingsManager.shared.isFolderMode {
                collectionView.reloadData()
            }
            return
        }
        
        currentPreviewPath = url.path
        clearPreview()
        dropZone.isHidden = true
        
        let isFolder = SettingsManager.shared.isFolderMode
        
        if isFolder {
            scrollView.isHidden = false
            scrollView.frame = NSRect(x: 0, y: 0, width: 460, height: 100)
            let previewFrame = NSRect(x: 0, y: 100, width: 460, height: 140)
            previewImageView.frame = previewFrame
            previewPlayerLayer.frame = previewFrame
            collectionView.reloadData()
        } else {
            scrollView.isHidden = true
            previewImageView.frame = previewContainer.bounds
            previewPlayerLayer.frame = previewContainer.bounds
        }

        switch type {
        case .image:
            if let image = NSImage(contentsOf: url) {
                previewImageView.image = image
                previewImageView.isHidden = false
                previewPlayerLayer.isHidden = true
            }
        case .video:
            previewPlayer = AVPlayer(url: url)
            previewPlayer?.isMuted = true
            previewPlayerLayer.player = previewPlayer
            previewPlayerLayer.isHidden = false
            previewImageView.isHidden = true
            previewPlayer?.play()

            previewEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: previewPlayer?.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.previewPlayer?.seek(to: .zero)
                self?.previewPlayer?.play()
            }
        case .unsupported:
            break
        }
    }

    private func clearPreview() {
        previewPlayer?.pause()
        if let observer = previewEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        previewEndObserver = nil
        previewPlayer = nil
        previewPlayerLayer.player = nil
        previewImageView.image = nil
        scrollView.isHidden = true
    }
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        if let indexPath = indexPaths.first {
            // Stop rotation when user manually picks a wallpaper
            if SettingsManager.shared.isRotationEnabled {
                SettingsManager.shared.isRotationEnabled = false
                wallpaperManager.startRotationTimer() // This will stop it because of the guard
            }
            wallpaperManager.selectPlaylistItem(at: indexPath.item)
            updateUI()
        }
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return wallpaperManager.playlist.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ThumbnailItem.identifier, for: indexPath) as! ThumbnailItem
        let url = wallpaperManager.playlist[indexPath.item]
        let isActive = (indexPath.item == wallpaperManager.currentPlaylistIndex)
        item.configure(with: url, isActive: isActive)
        return item
    }
}

extension NSScreen {
    var isBuiltIn: Bool {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }
        return CGDisplayIsBuiltin(number.uint32Value) != 0
    }
}
