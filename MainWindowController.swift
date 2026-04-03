import Cocoa
import AVFoundation
import AVKit
import CoreGraphics

class MainWindowController: NSWindowController {
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
    private var chooseButton: NSButton!
    private var stopButton: NSButton!
    private var launchSwitch: NSButton!
    private var pauseSwitch: NSButton!
    private var intervalField: NSTextField!
    private var intervalStepper: NSStepper!
    private var intervalLabel: NSTextField!
    private var dropZone: NSView!
    private var dropLabel: NSTextField!
    private var screenPopUp: NSPopUpButton!
    private var selectedScreen: NSScreen?

    init(wallpaperManager: WallpaperManager) {
        self.wallpaperManager = wallpaperManager
        self.selectedScreen = NSScreen.main
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 480),
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

        updateUI()
    }

    private func createHeader() -> NSView {
        let header = NSView(frame: NSRect(x: 0, y: 460, width: 460, height: 60))

        let appIcon = NSTextField(labelWithString: "🌸")
        appIcon.font = NSFont.systemFont(ofSize: 32)
        appIcon.frame = NSRect(x: 20, y: 10, width: 40, height: 40)
        header.addSubview(appIcon)

        let title = NSTextField(labelWithString: "app.name".localized)
        title.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        title.frame = NSRect(x: 60, y: 18, width: 220, height: 28)
        header.addSubview(title)

        statusIndicator = NSView(frame: NSRect(x: 380, y: 24, width: 10, height: 10))
        statusIndicator.wantsLayer = true
        statusIndicator.layer?.cornerRadius = 5
        statusIndicator.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
        header.addSubview(statusIndicator)

        statusLabel = NSTextField(labelWithString: "ui.inactive".localized)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right
        statusLabel.frame = NSRect(x: 240, y: 20, width: 130, height: 16)
        header.addSubview(statusLabel)

        let separator = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 1))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        header.addSubview(separator)

        return header
    }

    private func createScreenSelector() -> NSView {
        let container = NSView(frame: NSRect(x: 20, y: 415, width: 420, height: 40))

        let label = NSTextField(labelWithString: "\("ui.screen".localized):")
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.frame = NSRect(x: 0, y: 10, width: 50, height: 20)
        container.addSubview(label)

        screenPopUp = NSPopUpButton(frame: NSRect(x: 55, y: 6, width: 260, height: 28))
        screenPopUp.target = self
        screenPopUp.action = #selector(screenSelectionChanged)
        container.addSubview(screenPopUp)

        let allScreensButton = NSButton(title: "ui.applyToAll".localized, target: self, action: #selector(applyToAllScreens))
        allScreensButton.bezelStyle = .rounded
        allScreensButton.controlSize = .small
        allScreensButton.font = NSFont.systemFont(ofSize: 11)
        allScreensButton.frame = NSRect(x: 325, y: 6, width: 95, height: 28)
        container.addSubview(allScreensButton)

        updateScreenMenu()

        return container
    }

    private func updateScreenMenu() {
        screenPopUp.removeAllItems()
        for (index, screen) in NSScreen.screens.enumerated() {
            let displayName: String
            if #available(macOS 10.15, *) {
                displayName = screen.localizedName
            } else {
                displayName = "screen.display".localized(index + 1)
            }
            let isBuiltIn = screen.isBuiltIn
            let suffix = isBuiltIn ? "screen.builtIn".localized : ""
            screenPopUp.addItem(withTitle: "\(displayName)\(suffix)")
            screenPopUp.lastItem?.representedObject = screen
        }
        if let selected = selectedScreen, let index = NSScreen.screens.firstIndex(of: selected) {
            screenPopUp.selectItem(at: index)
        } else {
            screenPopUp.selectItem(at: 0)
            selectedScreen = NSScreen.screens.first
        }
    }

    @objc private func screenSelectionChanged(_ sender: NSPopUpButton) {
        if let screen = sender.selectedItem?.representedObject as? NSScreen {
            selectedScreen = screen
            updateUI()
        }
    }

    @objc private func applyToAllScreens() {
        guard let url = wallpaperManager.currentFile else { return }
        wallpaperManager.setWallpaper(url: url)
        SettingsManager.shared.wallpaperPath = url.path
        updateUI()
    }

    private func createPreviewContainer() -> NSView {
        previewContainer = NSView(frame: NSRect(x: 20, y: 200, width: 420, height: 200))
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
        icon.frame = NSRect(x: 0, y: 120, width: 420, height: 50)
        dropZone.addSubview(icon)

        dropLabel = NSTextField(labelWithString: "ui.dropHere".localized)
        dropLabel.font = NSFont.systemFont(ofSize: 13)
        dropLabel.textColor = .secondaryLabelColor
        dropLabel.alignment = .center
        dropLabel.frame = NSRect(x: 0, y: 90, width: 420, height: 20)
        dropZone.addSubview(dropLabel)

        let formats = NSTextField(labelWithString: "ui.formats".localized)
        formats.font = NSFont.systemFont(ofSize: 10)
        formats.textColor = .tertiaryLabelColor
        formats.alignment = .center
        formats.frame = NSRect(x: 0, y: 70, width: 420, height: 16)
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

        return previewContainer
    }

    private func createInfoBar() -> NSView {
        let bar = NSView(frame: NSRect(x: 20, y: 165, width: 420, height: 30))

        fileNameLabel = NSTextField(labelWithString: "ui.noWallpaper".localized)
        fileNameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        fileNameLabel.lineBreakMode = .byTruncatingMiddle
        fileNameLabel.frame = NSRect(x: 0, y: 6, width: 300, height: 16)
        bar.addSubview(fileNameLabel)

        fileTypeLabel = NSTextField(labelWithString: "")
        fileTypeLabel.font = NSFont.systemFont(ofSize: 10)
        fileTypeLabel.textColor = .secondaryLabelColor
        fileTypeLabel.alignment = .right
        fileTypeLabel.frame = NSRect(x: 310, y: 6, width: 110, height: 16)
        bar.addSubview(fileTypeLabel)

        return bar
    }

    private func createControls() -> NSView {
        let controls = NSView(frame: NSRect(x: 20, y: 75, width: 420, height: 45))

        chooseButton = NSButton(title: "ui.chooseWallpaper".localized, target: self, action: #selector(chooseFile))
        chooseButton.bezelStyle = .rounded
        chooseButton.controlSize = .large
        chooseButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        chooseButton.frame = NSRect(x: 0, y: 2, width: 150, height: 40)
        controls.addSubview(chooseButton)

        stopButton = NSButton(title: "ui.stopWallpaper".localized, target: self, action: #selector(stopWallpaper))
        stopButton.bezelStyle = .rounded
        stopButton.controlSize = .large
        stopButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        stopButton.frame = NSRect(x: 160, y: 2, width: 140, height: 40)
        controls.addSubview(stopButton)

        return controls
    }

    private func createSettings() -> NSView {
        let settings = NSView(frame: NSRect(x: 20, y: 45, width: 420, height: 60))

        launchSwitch = NSButton(checkboxWithTitle: "ui.launchAtLogin".localized,
                                target: self, action: #selector(launchSwitchChanged))
        launchSwitch.font = NSFont.systemFont(ofSize: 12)
        launchSwitch.frame = NSRect(x: 0, y: 35, width: 120, height: 20)
        launchSwitch.state = SettingsManager.shared.launchAtLogin ? .on : .off
        settings.addSubview(launchSwitch)

        pauseSwitch = NSButton(checkboxWithTitle: "ui.pauseWhenInvisible".localized,
                               target: self, action: #selector(pauseSwitchChanged))
        pauseSwitch.font = NSFont.systemFont(ofSize: 12)
        pauseSwitch.frame = NSRect(x: 130, y: 35, width: 160, height: 20)
        pauseSwitch.state = SettingsManager.shared.pauseWhenInvisible ? .on : .off
        settings.addSubview(pauseSwitch)

        let intervalLabelPrefix = NSTextField(labelWithString: "ui.rotationInterval".localized + ":")
        intervalLabelPrefix.font = NSFont.systemFont(ofSize: 12)
        intervalLabelPrefix.frame = NSRect(x: 0, y: 5, width: 100, height: 20)
        settings.addSubview(intervalLabelPrefix)

        intervalField = NSTextField(frame: NSRect(x: 105, y: 5, width: 40, height: 22))
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

        intervalStepper = NSStepper(frame: NSRect(x: 145, y: 5, width: 15, height: 22))
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
        intervalLabel.frame = NSRect(x: 170, y: 5, width: 150, height: 20)
        settings.addSubview(intervalLabel)

        return settings
    }

    private func createFooter() -> NSView {
        let footer = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 40))

        let separator = NSView(frame: NSRect(x: 20, y: 35, width: 420, height: 1))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        footer.addSubview(separator)

        let author = NSTextField(labelWithString: "ui.madeBy".localized("❤️"))
        author.font = NSFont.systemFont(ofSize: 11)
        author.textColor = .secondaryLabelColor
        author.alignment = .center
        author.frame = NSRect(x: 20, y: 10, width: 420, height: 16)
        footer.addSubview(author)

        return footer
    }

    @objc func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = "ui.chooseWallpaper".localized
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
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
        }
        updateUI()
        (NSApp.delegate as? AppDelegate)?.rebuildRecentMenu()
    }

    @objc func launchSwitchChanged(_ sender: NSButton) {
        SettingsManager.shared.launchAtLogin = (sender.state == .on)
    }

    @objc func pauseSwitchChanged(_ sender: NSButton) {
        SettingsManager.shared.pauseWhenInvisible = (sender.state == .on)
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
        if SettingsManager.shared.isFolderMode {
            wallpaperManager.startRotationTimer()
        }
    }

    private func formatInterval(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) \("ui.minutes".localized)"
        }
        let hrs = minutes / 60
        let mins = minutes % 60
        let hrString = hrs == 1 ? "ui.hour".localized : "ui.hours".localized
        if mins == 0 {
            return "\(hrs) \(hrString)"
        }
        return "\(hrs) \(hrString) \(mins) \("ui.minutes".localized)"
    }

    func updateUI() {
        clearPreview()
        updateScreenMenu()

        stopButton.isEnabled = wallpaperManager.isActive

        var wallpaperPath: String?
        if let screen = selectedScreen {
            wallpaperPath = wallpaperManager.wallpaperPath(for: screen)
                ?? SettingsManager.shared.wallpaperPath(for: screen)
        }
        if wallpaperPath == nil {
            wallpaperPath = SettingsManager.shared.wallpaperPath
        }

        if let path = wallpaperPath,
           FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            let filename = (path as NSString).lastPathComponent
            let type = MediaType.detect(url)

            fileNameLabel.stringValue = filename
            if SettingsManager.shared.isFolderMode {
                fileTypeLabel.stringValue = "ui.folderMode".localized
            } else {
                fileTypeLabel.stringValue = type == .video ? "ui.video".localized : "ui.image".localized
            }

            statusIndicator.layer?.backgroundColor = NSColor.systemGreen.cgColor
            statusLabel.stringValue = "ui.active".localized
            statusLabel.textColor = .systemGreen

            showPreview(url: url, type: type)
        } else {
            fileNameLabel.stringValue = "ui.noWallpaper".localized
            fileTypeLabel.stringValue = ""

            statusIndicator.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            statusLabel.stringValue = "ui.inactive".localized
            statusLabel.textColor = .secondaryLabelColor

            dropZone.isHidden = false
            dropLabel.stringValue = "ui.dropHere".localized
            previewImageView.isHidden = true
            previewPlayerLayer.isHidden = true
        }
    }

    private func showPreview(url: URL, type: MediaType) {
        dropZone.isHidden = true

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
