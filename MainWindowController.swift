import Cocoa
import AVFoundation
import AVKit
import CoreGraphics

private final class DragDropContainerView: NSView {
    var onFilesDropped: (([URL]) -> Bool)?
    var onDragStateChanged: ((Bool) -> Void)?
    var canAcceptDrop: ((URL) -> Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard hasAcceptableURL(in: sender) else {
            onDragStateChanged?(false)
            return []
        }
        onDragStateChanged?(true)
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onDragStateChanged?(false)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        onDragStateChanged?(false)
        guard let urls = droppedURLs(from: sender), !urls.isEmpty else { return false }
        return onFilesDropped?(urls) ?? false
    }

    private func droppedURLs(from info: NSDraggingInfo) -> [URL]? {
        info.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
    }

    private func hasAcceptableURL(in info: NSDraggingInfo) -> Bool {
        guard let urls = droppedURLs(from: info), !urls.isEmpty else { return false }
        if let canAcceptDrop {
            return urls.contains(where: canAcceptDrop)
        }
        return true
    }
}

class MainWindowController: NSWindowController, NSCollectionViewDataSource, NSCollectionViewDelegate {
    let wallpaperManager: WallpaperManager

    private var previewImageView: NSImageView!
    private var previewPlayerLayer: AVPlayerLayer!
    private var previewPlayer: AVPlayer?
    private var previewEndObserver: Any?
    private var previewContainer: DragDropContainerView!
    private var previewLoadingOverlay: NSView!
    private var previewLoadingSpinner: NSProgressIndicator!
    private var previewLoadingLabel: NSTextField!
    private var fileNameLabel: NSTextField!
    private var fileTypeLabel: NSTextField!
    private var statusIndicator: NSView!
    private var statusLabel: NSTextField!
    private var selectFileButton: NSButton!
    private var selectFolderButton: NSButton!
    private var stopButton: NSButton!
    private var launchSwitch: NSButton!
    private var pauseSwitch: NSButton!
    private var syncDesktopSwitch: NSButton!
    private var rotationSwitch: NSButton!
    private var shuffleSwitch: NSButton!
    private var includeSubfoldersSwitch: NSButton!
    private var intervalField: NSTextField!
    private var intervalStepper: NSStepper!
    private var intervalLabel: NSTextField!
    private var intervalPrefix: NSTextField!
    private var folderCountLabel: NSTextField!
    private var syncCheckbox: NSButton!
    private var newScreenPolicyLabel: NSTextField!
    private var newScreenPolicyPopUp: NSPopUpButton!
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    private var dropZone: NSView!
    private var dropIconView: NSImageView!
    private var dropLabel: NSTextField!
    private var dropFormatsLabel: NSTextField!
    private var dropTapHintLabel: NSTextField!
    private var screenPopUp: NSPopUpButton!
    private var selectedScreen: NSScreen?

    init(wallpaperManager: WallpaperManager) {
        self.wallpaperManager = wallpaperManager
        self.selectedScreen = NSScreen.screens.first(where: { $0.isBuiltIn }) ?? NSScreen.main
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 756),
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
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        contentView.addSubview(createHeader())
        contentView.addSubview(createScreenSelector())
        contentView.addSubview(createPreviewContainer())
        contentView.addSubview(createInfoBar())
        contentView.addSubview(createControls())
        contentView.addSubview(createSettings())
        contentView.addSubview(createFooter())

        NotificationCenter.default.addObserver(self, selector: #selector(rotationHappened), name: WallpaperManager.didRotateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(statusChanged), name: WallpaperManager.playbackStateDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenListChanged), name: WallpaperManager.screenListDidChangeNotification, object: nil)

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

    /// Called when a screen is detached and uiScreenID has been updated (Bug 6 fix).
    /// Refreshes the screen picker so it reflects the current display topology.
    @objc private func screenListChanged() {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }

    private func createHeader() -> NSView {
        let header = NSView(frame: NSRect(x: 0, y: 684, width: 500, height: 60))
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor.clear.cgColor

        let appIcon = NSTextField(labelWithString: "🌸")
        appIcon.font = NSFont.systemFont(ofSize: 30)
        appIcon.alignment = .center
        appIcon.frame = NSRect(x: 18, y: 12, width: 34, height: 34)
        header.addSubview(appIcon)

        let title = NSTextField(labelWithString: "app.name".localized)
        title.font = NSFont(name: "Avenir Next Demi Bold", size: 22) ?? NSFont.systemFont(ofSize: 22, weight: .semibold)
        title.textColor = .labelColor
        title.frame = NSRect(x: 58, y: 15, width: 250, height: 28)
        header.addSubview(title)

        let statusContainer = NSView(frame: NSRect(x: 350, y: 10, width: 130, height: 40))
        statusIndicator = NSView(frame: NSRect(x: 0, y: 14, width: 8, height: 8))
        statusIndicator.wantsLayer = true
        statusIndicator.layer?.cornerRadius = 4
        statusIndicator.layer?.backgroundColor = NSColor.systemGray.cgColor
        statusContainer.addSubview(statusIndicator)

        statusLabel = NSTextField(labelWithString: "ui.status".localized("ui.notSet".localized))
        statusLabel.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .medium)
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
        let container = NSView(frame: NSRect(x: 20, y: 636, width: 460, height: 40))
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let label = NSTextField(labelWithString: "\("ui.screen".localized):")
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        label.frame = NSRect(x: 0, y: 10, width: 60, height: 20)
        container.addSubview(label)

        screenPopUp = NSPopUpButton(frame: NSRect(x: 65, y: 8, width: 240, height: 25))
        screenPopUp.target = self
        screenPopUp.action = #selector(screenSelectionChanged)
        container.addSubview(screenPopUp)

        syncCheckbox = NSButton(checkboxWithTitle: "ui.syncScreens".localized, target: self, action: #selector(syncCheckboxChanged(_:)))
        syncCheckbox.font = NSFont.systemFont(ofSize: 12)
        syncCheckbox.frame = NSRect(x: 315, y: 10, width: 145, height: 20)
        syncCheckbox.toolTip = "ui.syncScreens.tooltip".localized
        container.addSubview(syncCheckbox)

        updateScreenMenu()

        return container
    }

    private func updateScreenMenu() {
        screenPopUp.removeAllItems()

        // Sort screens: built-in display first, then external displays by name
        let sortedScreens = NSScreen.screens.sorted { a, b in
            if a.isBuiltIn != b.isBuiltIn { return a.isBuiltIn }
            return a.localizedName < b.localizedName
        }

        for (index, screen) in sortedScreens.enumerated() {
            let displayName: String
            if #available(macOS 10.15, *) {
                displayName = screen.localizedName
            } else {
                displayName = "screen.display".localized(index + 1)
            }
            let suffix = screen.isBuiltIn ? "screen.builtIn".localized : ""
            screenPopUp.addItem(withTitle: "\(displayName)\(suffix)")
            screenPopUp.lastItem?.representedObject = screen
        }

        if let selected = selectedScreen,
           let index = sortedScreens.firstIndex(of: selected) {
            screenPopUp.selectItem(at: index)
        } else if let first = sortedScreens.first {
            selectedScreen = first
            screenPopUp.selectItem(at: 0)
        } else {
            selectedScreen = nil
        }
    }

    @objc private func screenSelectionChanged(_ sender: NSPopUpButton) {
        selectedScreen = sender.selectedItem?.representedObject as? NSScreen
        updateUI()
    }

    @objc private func syncCheckboxChanged(_ sender: NSButton) {
        guard let screen = selectedScreen else { return }
        wallpaperManager.setSynced(sender.state == .on, for: screen)
        updateUI()
    }

    private func createPreviewContainer() -> NSView {
        previewContainer = DragDropContainerView(frame: NSRect(x: 20, y: 348, width: 460, height: 280))
        previewContainer.wantsLayer = true
        previewContainer.layer?.cornerRadius = 16
        previewContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        previewContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        previewContainer.layer?.borderWidth = 1
        previewContainer.layer?.masksToBounds = true
        previewContainer.layer?.shadowColor = NSColor.black.cgColor
        previewContainer.layer?.shadowOpacity = 0.10
        previewContainer.layer?.shadowRadius = 8
        previewContainer.layer?.shadowOffset = NSSize(width: 0, height: -2)
        previewContainer.canAcceptDrop = { [weak self] url in
            self?.isAcceptableDropURL(url) ?? false
        }
        previewContainer.onDragStateChanged = { [weak self] isActive in
            self?.setDropHighlight(active: isActive)
        }
        previewContainer.onFilesDropped = { [weak self] urls in
            self?.handleDroppedURLs(urls) ?? false
        }
        previewContainer.toolTip = "ui.pickHint".localized

        dropZone = NSView(frame: previewContainer.bounds)
        dropZone.wantsLayer = true
        dropZone.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.95).cgColor

        dropIconView = NSImageView(frame: NSRect(x: 0, y: 152, width: 460, height: 44))
        dropIconView.imageAlignment = .alignCenter
        dropIconView.imageScaling = .scaleProportionallyDown
        if #available(macOS 11.0, *) {
            dropIconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 44, weight: .regular)
            dropIconView.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
            dropIconView.contentTintColor = NSColor.systemTeal
        } else {
            dropIconView.image = NSImage(named: NSImage.folderName)
        }
        dropZone.addSubview(dropIconView)

        dropLabel = NSTextField(labelWithString: "ui.dropHere".localized)
        dropLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 14) ?? NSFont.systemFont(ofSize: 13, weight: .semibold)
        dropLabel.textColor = .labelColor
        dropLabel.alignment = .center
        dropLabel.frame = NSRect(x: 0, y: 108, width: 460, height: 34)
        dropZone.addSubview(dropLabel)

        dropFormatsLabel = NSTextField(labelWithString: "ui.formats".localized)
        dropFormatsLabel.font = NSFont(name: "Avenir Next Medium", size: 10) ?? NSFont.systemFont(ofSize: 10)
        dropFormatsLabel.textColor = .secondaryLabelColor
        dropFormatsLabel.alignment = .center
        dropFormatsLabel.frame = NSRect(x: 0, y: 92, width: 460, height: 16)
        dropZone.addSubview(dropFormatsLabel)

        dropTapHintLabel = NSTextField(labelWithString: "ui.tapToPick".localized)
        dropTapHintLabel.font = NSFont(name: "Avenir Next Medium", size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .medium)
        dropTapHintLabel.textColor = .secondaryLabelColor
        dropTapHintLabel.alignment = .center
        dropTapHintLabel.frame = NSRect(x: 0, y: 72, width: 460, height: 18)
        dropZone.addSubview(dropTapHintLabel)

        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(selectFromDropZone))
        dropZone.addGestureRecognizer(clickRecognizer)

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
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.isHidden = true
        scrollView.drawsBackground = false
        previewContainer.addSubview(scrollView)

        previewLoadingOverlay = NSView(frame: previewContainer.bounds)
        previewLoadingOverlay.autoresizingMask = [.width, .height]
        previewLoadingOverlay.wantsLayer = true
        previewLoadingOverlay.layer?.backgroundColor = NSColor(calibratedWhite: 0.09, alpha: 0.76).cgColor
        previewLoadingOverlay.isHidden = true

        previewLoadingSpinner = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        previewLoadingSpinner.style = .spinning
        previewLoadingSpinner.controlSize = .small
        previewLoadingSpinner.frame.origin = NSPoint(x: (previewLoadingOverlay.bounds.width - 20) / 2, y: (previewLoadingOverlay.bounds.height - 20) / 2 + 10)
        previewLoadingSpinner.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        previewLoadingOverlay.addSubview(previewLoadingSpinner)

        previewLoadingLabel = NSTextField(labelWithString: "ui.loadingPreview".localized)
        previewLoadingLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        previewLoadingLabel.textColor = .secondaryLabelColor
        previewLoadingLabel.alignment = .center
        previewLoadingLabel.frame = NSRect(x: 0, y: previewLoadingSpinner.frame.minY - 24, width: previewLoadingOverlay.bounds.width, height: 18)
        previewLoadingLabel.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        previewLoadingOverlay.addSubview(previewLoadingLabel)

        previewContainer.addSubview(previewLoadingOverlay)

        return previewContainer
    }

    private func createInfoBar() -> NSView {
        let bar = NSView(frame: NSRect(x: 20, y: 310, width: 460, height: 30))
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 8
        bar.layer?.backgroundColor = NSColor.clear.cgColor
        bar.layer?.borderColor = NSColor.clear.cgColor
        bar.layer?.borderWidth = 1

        fileNameLabel = NSTextField(labelWithString: "ui.noWallpaper".localized)
        fileNameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        fileNameLabel.textColor = .labelColor
        fileNameLabel.lineBreakMode = .byTruncatingMiddle
        fileNameLabel.frame = NSRect(x: 10, y: 6, width: 330, height: 16)
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
        let controls = NSView(frame: NSRect(x: 20, y: 252, width: 460, height: 50))
        controls.wantsLayer = true
        controls.layer?.cornerRadius = 8
        controls.layer?.backgroundColor = NSColor.clear.cgColor

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
        stopButton.controlSize = .regular
        stopButton.font = NSFont(name: "Avenir Next Demi Bold", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .semibold)
        stopButton.frame = NSRect(x: 230, y: 5, width: 180, height: 40)
        stopButton.toolTip = "ui.stopWallpaperTooltip".localized
        controls.addSubview(stopButton)

        return controls
    }

    private func createSettings() -> NSView {
        let settings = NSView(frame: NSRect(x: 20, y: 58, width: 460, height: 186))
        settings.wantsLayer = true
        settings.layer?.cornerRadius = 8
        settings.layer?.backgroundColor = NSColor.clear.cgColor
        settings.layer?.borderColor = NSColor.clear.cgColor
        settings.layer?.borderWidth = 1

        launchSwitch = NSButton(checkboxWithTitle: "ui.launchAtLogin".localized,
                                target: self, action: #selector(launchSwitchChanged))
        launchSwitch.font = NSFont.systemFont(ofSize: 12)
        launchSwitch.frame = NSRect(x: 0, y: 156, width: 150, height: 20)
        launchSwitch.state = SettingsManager.shared.launchAtLogin ? .on : .off
        settings.addSubview(launchSwitch)

        pauseSwitch = NSButton(checkboxWithTitle: "ui.pauseWhenInvisible".localized,
                               target: self, action: #selector(pauseSwitchChanged))
        pauseSwitch.font = NSFont.systemFont(ofSize: 12)
        pauseSwitch.frame = NSRect(x: 160, y: 156, width: 200, height: 20)
        pauseSwitch.state = SettingsManager.shared.pauseWhenInvisible ? .on : .off
        settings.addSubview(pauseSwitch)

        syncDesktopSwitch = NSButton(checkboxWithTitle: "ui.syncDesktopWallpaper".localized,
                                     target: self, action: #selector(syncDesktopSwitchChanged))
        syncDesktopSwitch.font = NSFont.systemFont(ofSize: 12)
        syncDesktopSwitch.frame = NSRect(x: 0, y: 130, width: 380, height: 20)
        syncDesktopSwitch.state = SettingsManager.shared.syncDesktopWallpaper ? .on : .off
        syncDesktopSwitch.toolTip = "ui.syncDesktopWallpaper.tooltip".localized
        settings.addSubview(syncDesktopSwitch)

        rotationSwitch = NSButton(checkboxWithTitle: "ui.enableRotation".localized,
                                  target: self, action: #selector(rotationSwitchChanged))
        rotationSwitch.font = NSFont.systemFont(ofSize: 12)
        rotationSwitch.frame = NSRect(x: 0, y: 104, width: 120, height: 20)
        rotationSwitch.state = Screen_Config.default.isRotationEnabled ? .on : .off
        settings.addSubview(rotationSwitch)

        shuffleSwitch = NSButton(checkboxWithTitle: "ui.shuffleMode".localized,
                                 target: self, action: #selector(shuffleSwitchChanged))
        shuffleSwitch.font = NSFont.systemFont(ofSize: 12)
        shuffleSwitch.frame = NSRect(x: 160, y: 104, width: 200, height: 20)
        shuffleSwitch.state = Screen_Config.default.isShuffleMode ? .on : .off
        settings.addSubview(shuffleSwitch)

        includeSubfoldersSwitch = NSButton(checkboxWithTitle: "ui.includeSubfolders".localized,
                                           target: self, action: #selector(includeSubfoldersChanged))
        includeSubfoldersSwitch.font = NSFont.systemFont(ofSize: 12)
        includeSubfoldersSwitch.frame = NSRect(x: 0, y: 80, width: 180, height: 20)
        includeSubfoldersSwitch.state = Screen_Config.default.includeSubfolders ? .on : .off
        settings.addSubview(includeSubfoldersSwitch)

        intervalPrefix = NSTextField(labelWithString: "ui.rotationInterval".localized + ":")
        intervalPrefix.font = NSFont.systemFont(ofSize: 12)
        intervalPrefix.textColor = .labelColor
        intervalPrefix.frame = NSRect(x: 0, y: 52, width: 120, height: 20)
        settings.addSubview(intervalPrefix)

        intervalField = NSTextField(frame: NSRect(x: 125, y: 52, width: 50, height: 22))
        intervalField.font = NSFont.systemFont(ofSize: 12)
        intervalField.alignment = .right
        intervalField.target = self
        intervalField.action = #selector(intervalFieldChanged)
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 1
        intervalField.formatter = formatter
        intervalField.integerValue = Screen_Config.default.rotationIntervalMinutes
        settings.addSubview(intervalField)

        intervalStepper = NSStepper(frame: NSRect(x: 175, y: 52, width: 15, height: 22))
        intervalStepper.minValue = 1
        intervalStepper.maxValue = 1440
        intervalStepper.increment = 1
        intervalStepper.valueWraps = false
        intervalStepper.integerValue = Screen_Config.default.rotationIntervalMinutes
        intervalStepper.target = self
        intervalStepper.action = #selector(intervalStepperChanged)
        settings.addSubview(intervalStepper)

        intervalLabel = NSTextField(labelWithString: formatInterval(minutes: Screen_Config.default.rotationIntervalMinutes))
        intervalLabel.font = NSFont.systemFont(ofSize: 11)
        intervalLabel.textColor = .secondaryLabelColor
        intervalLabel.frame = NSRect(x: 200, y: 52, width: 250, height: 20)
        settings.addSubview(intervalLabel)

        folderCountLabel = NSTextField(labelWithString: "")
        folderCountLabel.font = NSFont.systemFont(ofSize: 11)
        folderCountLabel.textColor = .secondaryLabelColor
        folderCountLabel.frame = NSRect(x: 0, y: 28, width: 430, height: 18)
        settings.addSubview(folderCountLabel)
        
        newScreenPolicyLabel = NSTextField(labelWithString: "ui.newScreenPolicy".localized + ":")
        newScreenPolicyLabel.font = NSFont.systemFont(ofSize: 12)
        newScreenPolicyLabel.textColor = .labelColor
        newScreenPolicyLabel.frame = NSRect(x: 0, y: 4, width: 120, height: 20)
        settings.addSubview(newScreenPolicyLabel)

        newScreenPolicyPopUp = NSPopUpButton(frame: NSRect(x: 125, y: 2, width: 200, height: 25))
        newScreenPolicyPopUp.target = self
        newScreenPolicyPopUp.action = #selector(newScreenPolicyChanged(_:))
        newScreenPolicyPopUp.toolTip = "ui.newScreenPolicy.tooltip".localized
        newScreenPolicyPopUp.addItem(withTitle: "ui.newScreenPolicy.inheritSyncGroup".localized)
        newScreenPolicyPopUp.lastItem?.representedObject = New_Screen_Policy.inheritSyncGroup.rawValue
        newScreenPolicyPopUp.addItem(withTitle: "ui.newScreenPolicy.blank".localized)
        newScreenPolicyPopUp.lastItem?.representedObject = New_Screen_Policy.blank.rawValue
        settings.addSubview(newScreenPolicyPopUp)



        return settings
    }

    @objc private func newScreenPolicyChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let policy = New_Screen_Policy(rawValue: rawValue) else { return }
        SettingsManager.shared.newScreenPolicy = policy
        updateNewScreenPolicyMenu()
    }

    private func updateNewScreenPolicyMenu() {
        // Sync newScreenPolicyPopUp to current setting
        let currentPolicy = SettingsManager.shared.newScreenPolicy
        for (index, item) in newScreenPolicyPopUp.itemArray.enumerated() {
            if let rawValue = item.representedObject as? String,
               rawValue == currentPolicy.rawValue {
                newScreenPolicyPopUp.selectItem(at: index)
                break
            }
        }
    }

    private func createFooter() -> NSView {
        let footer = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 50))

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

    @objc private func selectFromDropZone() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        openPicker(panel: panel)
    }

    private func openPicker(panel: NSOpenPanel) {
        panel.title = "ui.chooseWallpaper".localized
        panel.allowsMultipleSelection = false
        panel.directoryURL = suggestedPickerDirectoryURL()

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
            let config = Screen_Config(
                folderPath: url.path,
                wallpaperPath: nil,
                rotationIntervalMinutes: max(1, intervalField.integerValue),
                isShuffleMode: (shuffleSwitch.state == .on),
                isRotationEnabled: (rotationSwitch.state == .on),
                includeSubfolders: (includeSubfoldersSwitch.state == .on),
                isFolderMode: true,
                isSynced: selectedScreen.map { SettingsManager.shared.screenConfig(for: SettingsManager.screenIdentifier($0)).isSynced } ?? true
            )
            if let screen = selectedScreen {
                wallpaperManager.setFolder(url: url, for: screen, config: config)
            } else {
                for screen in NSScreen.screens {
                    wallpaperManager.setFolder(url: url, for: screen, config: config)
                }
            }
        } else {
            let type = MediaType.detect(url)
            guard type != .unsupported else {
                throw WallpaperError.unsupportedFormat
            }
            if let screen = selectedScreen {
                wallpaperManager.setWallpaper(url: url, for: screen)
            } else {
                for screen in NSScreen.screens {
                    wallpaperManager.setWallpaper(url: url, for: screen)
                }
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
        }
        updateUI()
        (NSApp.delegate as? AppDelegate)?.rebuildRecentMenu()
    }

    @objc private func clearThenRepick() {
        stopWallpaper()
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        openPicker(panel: panel)
    }

    @objc func launchSwitchChanged(_ sender: NSButton) {
        SettingsManager.shared.launchAtLogin = (sender.state == .on)
    }

    @objc func pauseSwitchChanged(_ sender: NSButton) {
        SettingsManager.shared.pauseWhenInvisible = (sender.state == .on)
        wallpaperManager.checkPlaybackState()
    }

    @objc func syncDesktopSwitchChanged(_ sender: NSButton) {
        SettingsManager.shared.syncDesktopWallpaper = (sender.state == .on)
    }
    
    @objc func includeSubfoldersChanged(_ sender: NSButton) {
        guard let screen = selectedScreen else { return }
        let id = SettingsManager.screenIdentifier(screen)
        var config = SettingsManager.shared.screenConfig(for: id)
        config.includeSubfolders = (sender.state == .on)
        if let folderPath = config.folderPath {
            wallpaperManager.setFolder(url: URL(fileURLWithPath: folderPath), for: screen, config: config)
        } else {
            SettingsManager.shared.setScreenConfig(config, for: id)
        }
        updateUI()
    }

    @objc func shuffleSwitchChanged(_ sender: NSButton) {
        guard let screen = selectedScreen else { return }
        let id = SettingsManager.screenIdentifier(screen)
        var config = SettingsManager.shared.screenConfig(for: id)
        config.isShuffleMode = (sender.state == .on)
        SettingsManager.shared.setScreenConfig(config, for: id)
        wallpaperManager.startRotationTimer()
        updateUI()
    }

    @objc func rotationSwitchChanged(_ sender: NSButton) {
        guard let screen = selectedScreen else { return }
        let id = SettingsManager.screenIdentifier(screen)
        var config = SettingsManager.shared.screenConfig(for: id)
        config.isRotationEnabled = (sender.state == .on)
        SettingsManager.shared.setScreenConfig(config, for: id)
        if sender.state == .on {
            wallpaperManager.startRotationTimer()
        } else {
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
        guard let screen = selectedScreen else { return }
        let id = SettingsManager.screenIdentifier(screen)
        var config = SettingsManager.shared.screenConfig(for: id)
        config.rotationIntervalMinutes = minutes
        SettingsManager.shared.setScreenConfig(config, for: id)
        intervalLabel.stringValue = formatInterval(minutes: minutes)
        wallpaperManager.startRotationTimer()
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

    private func suggestedPickerDirectoryURL() -> URL? {
        let selectedPath: String?
        if let screen = selectedScreen {
            let id = SettingsManager.screenIdentifier(screen)
            let config = SettingsManager.shared.screenConfig(for: id)
            selectedPath = wallpaperManager.wallpaperPath(for: screen)
                ?? config.wallpaperPath
                ?? config.folderPath
        } else {
            selectedPath = nil
        }

        guard let path = selectedPath, !path.isEmpty else { return nil }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return URL(fileURLWithPath: path)
            }
            return URL(fileURLWithPath: path).deletingLastPathComponent()
        }
        return URL(fileURLWithPath: path).deletingLastPathComponent()
    }

    private func isAcceptableDropURL(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        if isDirectory.boolValue {
            return true
        }
        return MediaType.detect(url) != .unsupported
    }

    private func setDropHighlight(active: Bool) {
        guard dropZone.isHidden == false else { return }
        previewContainer.layer?.borderColor = active
            ? NSColor.systemBlue.cgColor
            : NSColor.separatorColor.cgColor
        dropLabel.textColor = active
            ? NSColor.systemBlue
            : .labelColor
        dropFormatsLabel.textColor = active
            ? NSColor.systemBlue
            : .secondaryLabelColor
        dropTapHintLabel.textColor = active
            ? NSColor.systemBlue
            : .secondaryLabelColor
        if #available(macOS 11.0, *) {
            dropIconView.contentTintColor = active
                ? NSColor.systemBlue
                : NSColor.systemTeal
        }
    }

    private func handleDroppedURLs(_ urls: [URL]) -> Bool {
        guard let url = urls.first(where: { isAcceptableDropURL($0) }) else { return false }
        do {
            try setWallpaper(url: url)
            return true
        } catch {
            showError(error)
            return false
        }
    }

    func updateUI() {
        updateScreenMenu()
        updateNewScreenPolicyMenu()

        let selectedScreenID = selectedScreen.map { SettingsManager.screenIdentifier($0) } ?? ""
        let config = SettingsManager.shared.screenConfig(for: selectedScreenID)

        // Sync checkbox — only meaningful with multiple screens
        syncCheckbox.state = config.isSynced ? .on : .off
        syncCheckbox.isEnabled = NSScreen.screens.count > 1

        let activeScreen = selectedScreen ?? NSScreen.main ?? NSScreen.screens.first
        stopButton.title = "ui.stopWallpaper".localized
        stopButton.isEnabled = activeScreen.flatMap { wallpaperManager.wallpaperPath(for: $0) } != nil
            || config.folderPath != nil

        let isFolderMode = config.isFolderMode
        let isRotationEnabled = config.isRotationEnabled
        let isShuffleMode = config.isShuffleMode
        let currentIncludeSubfolders = config.includeSubfolders
        let currentInterval = config.rotationIntervalMinutes

        pauseSwitch.state = SettingsManager.shared.pauseWhenInvisible ? .on : .off
        syncDesktopSwitch.state = SettingsManager.shared.syncDesktopWallpaper ? .on : .off
        intervalField.integerValue = currentInterval
        intervalStepper.integerValue = currentInterval
        intervalLabel.stringValue = formatInterval(minutes: currentInterval)

        rotationSwitch.isEnabled = isFolderMode
        rotationSwitch.state = isRotationEnabled ? .on : .off

        shuffleSwitch.isEnabled = isFolderMode && isRotationEnabled
        shuffleSwitch.state = isShuffleMode ? .on : .off

        intervalField.isEnabled = isFolderMode && isRotationEnabled
        intervalStepper.isEnabled = isFolderMode && isRotationEnabled
        includeSubfoldersSwitch.state = currentIncludeSubfolders ? .on : .off

        rotationSwitch.contentTintColor = isFolderMode ? nil : .tertiaryLabelColor
        shuffleSwitch.contentTintColor = (isFolderMode && isRotationEnabled) ? nil : .tertiaryLabelColor
        intervalPrefix.textColor = (isFolderMode && isRotationEnabled) ? .labelColor : .tertiaryLabelColor
        intervalLabel.textColor = (isFolderMode && isRotationEnabled) ? .secondaryLabelColor : .tertiaryLabelColor
        folderCountLabel.textColor = isFolderMode ? .secondaryLabelColor : .tertiaryLabelColor
        if isFolderMode {
            let recursive = currentIncludeSubfolders ? "ui.recursiveEnabled".localized : "ui.recursiveDisabled".localized
            let playlistCount = wallpaperManager.playlist(for: selectedScreenID).count
            folderCountLabel.stringValue = "ui.folderItems".localized(playlistCount, recursive)
        } else {
            folderCountLabel.stringValue = ""
        }

        var wallpaperPath: String?
        var isCurrentlyPaused = false

        if let screen = activeScreen {
            wallpaperPath = wallpaperManager.wallpaperPath(for: screen)
            isCurrentlyPaused = wallpaperManager.isPaused || wallpaperManager.isScreenPaused(screen)
        }

        if let path = wallpaperPath,
           FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            let filename = (path as NSString).lastPathComponent
            let type = MediaType.detect(url)

            if isFolderMode {
                let current = wallpaperManager.currentPlaylistIndex(for: selectedScreenID) + 1
                let total = wallpaperManager.playlist(for: selectedScreenID).count
                let isRotating = isFolderMode && isRotationEnabled
                let shuffleIcon = (isShuffleMode && isRotating) ? "🔀 " : ""
                fileNameLabel.stringValue = "\(shuffleIcon)\(filename) (\(current)/\(total))"
                fileTypeLabel.stringValue = "ui.folderMode".localized
            } else {
                fileNameLabel.stringValue = filename
                fileTypeLabel.stringValue = type == .video ? "ui.video".localized : "ui.image".localized
            }

            let isAutoPaused = SettingsManager.shared.pauseWhenInvisible && wallpaperManager.isPausedInternally && !isCurrentlyPaused
            if isCurrentlyPaused {
                statusIndicator.layer?.backgroundColor = NSColor.systemYellow.cgColor
                statusLabel.stringValue = "ui.status".localized("ui.pausedManual".localized)
                statusLabel.textColor = .systemYellow
                previewPlayer?.pause()
            } else if isAutoPaused {
                statusIndicator.layer?.backgroundColor = NSColor.systemOrange.cgColor
                statusLabel.stringValue = "ui.status".localized("ui.pausedAuto".localized)
                statusLabel.textColor = .systemOrange
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
            setDropHighlight(active: false)
            previewImageView.isHidden = true
            previewPlayerLayer.isHidden = true
        }
    }

    private func showPreview(url: URL, type: MediaType) {
        let previewScreenID = selectedScreen.map { SettingsManager.screenIdentifier($0) } ?? ""
        let previewConfig = SettingsManager.shared.screenConfig(for: previewScreenID)
        let isFolder = previewConfig.isFolderMode

        if currentPreviewPath == url.path {
            if isFolder {
                collectionView.reloadData()
            }
            return
        }
        
        currentPreviewPath = url.path
        clearPreview()
        dropZone.isHidden = true
        
        if isFolder {
            scrollView.isHidden = false
            scrollView.frame = NSRect(x: 0, y: 0, width: 460, height: 100)
            let previewFrame = NSRect(x: 0, y: 100, width: 460, height: 180)
            previewImageView.frame = previewFrame
            previewPlayerLayer.frame = previewFrame
            collectionView.reloadData()
            collectionView.layoutSubtreeIfNeeded()
            scrollView.reflectScrolledClipView(scrollView.contentView)
        } else {
            scrollView.isHidden = true
            previewImageView.frame = previewContainer.bounds
            previewPlayerLayer.frame = previewContainer.bounds
        }

        switch type {
        case .image:
            setPreviewLoading(true)
            let targetSize = previewImageView.frame.size
            let fallbackSize = NSSize(width: 460, height: isFolder ? 180 : 280)
            let requestedSize = (targetSize.width > 0 && targetSize.height > 0) ? targetSize : fallbackSize

            ThumbnailProvider.shared.requestThumbnail(for: url, size: requestedSize) { [weak self] image in
                guard let self, self.currentPreviewPath == url.path else { return }
                self.setPreviewLoading(false)
                guard let image else { return }
                previewImageView.image = image
                previewImageView.isHidden = false
                previewPlayerLayer.isHidden = true
            }
        case .video:
            setPreviewLoading(false)
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
            setPreviewLoading(false)
            break
        }
    }

    private func clearPreview() {
        setPreviewLoading(false)
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

    private func setPreviewLoading(_ loading: Bool) {
        previewLoadingOverlay.isHidden = !loading
        if loading {
            previewLoadingSpinner.startAnimation(nil)
        } else {
            previewLoadingSpinner.stopAnimation(nil)
        }
    }

    func runOnboardingIfNeeded() {
        guard !SettingsManager.shared.onboardingCompleted else { return }
        // Check if any screen has a non-default config
        let hasExistingSetup = NSScreen.screens.contains { screen in
            let id = SettingsManager.screenIdentifier(screen)
            let config = SettingsManager.shared.screenConfig(for: id)
            return config.folderPath != nil || config.wallpaperPath != nil
        } || !SettingsManager.shared.wallpaperHistory.isEmpty
        if hasExistingSetup {
            SettingsManager.shared.onboardingCompleted = true
            return
        }

        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let step1 = NSAlert()
        step1.messageText = "onboarding.step1.title".localized
        step1.informativeText = "onboarding.step1.message".localized
        step1.alertStyle = .informational
        step1.addButton(withTitle: "onboarding.pickFile".localized)
        step1.addButton(withTitle: "onboarding.pickFolder".localized)
        step1.addButton(withTitle: "onboarding.skip".localized)
        let step1Result = step1.runModal()
        if step1Result == .alertFirstButtonReturn {
            selectFile()
        } else if step1Result == .alertSecondButtonReturn {
            selectFolder()
        }

        let step2 = NSAlert()
        step2.messageText = "onboarding.step2.title".localized
        step2.informativeText = "onboarding.step2.message".localized
        step2.alertStyle = .informational
        step2.addButton(withTitle: "onboarding.interval15".localized)
        step2.addButton(withTitle: "onboarding.interval5".localized)
        step2.addButton(withTitle: "onboarding.interval30".localized)
        let step2Result = step2.runModal()
        let minutes: Int
        if step2Result == .alertSecondButtonReturn {
            minutes = 5
        } else if step2Result == .alertThirdButtonReturn {
            minutes = 30
        } else {
            minutes = 15
        }
        updateInterval(minutes: minutes)
        intervalField.integerValue = minutes
        intervalStepper.integerValue = minutes

        let step3 = NSAlert()
        step3.messageText = "onboarding.step3.title".localized
        step3.informativeText = "onboarding.step3.message".localized
        step3.alertStyle = .informational
        step3.addButton(withTitle: "onboarding.enable".localized)
        step3.addButton(withTitle: "onboarding.notNow".localized)
        let enableLaunch = (step3.runModal() == .alertFirstButtonReturn)
        SettingsManager.shared.launchAtLogin = enableLaunch
        launchSwitch.state = enableLaunch ? .on : .off

        SettingsManager.shared.onboardingCompleted = true
        updateUI()
    }
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        if let indexPath = indexPaths.first {
            guard let screen = selectedScreen else { return }
            let id = SettingsManager.screenIdentifier(screen)
            var config = SettingsManager.shared.screenConfig(for: id)
            if config.isRotationEnabled {
                config.isRotationEnabled = false
                SettingsManager.shared.setScreenConfig(config, for: id)
                wallpaperManager.startRotationTimer()
            }
            wallpaperManager.selectPlaylistItem(at: indexPath.item, for: screen)
            updateUI()
        }
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        let id = selectedScreen.map { SettingsManager.screenIdentifier($0) } ?? ""
        return wallpaperManager.playlist(for: id).count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ThumbnailItem.identifier, for: indexPath) as! ThumbnailItem
        let id = selectedScreen.map { SettingsManager.screenIdentifier($0) } ?? ""
        let playlist = wallpaperManager.playlist(for: id)
        let url = playlist[indexPath.item]
        let isActive = (indexPath.item == wallpaperManager.currentPlaylistIndex(for: id))
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
