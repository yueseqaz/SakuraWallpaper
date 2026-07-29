import Cocoa
import AVFoundation
import AVKit
import CoreGraphics

private final class DragDropContainerView: NSView {
    var onFilesDropped: (([URL]) -> Bool)?
    var onDragStateChanged: ((Bool) -> Void)?
    var canAcceptDrop: ((URL) -> Bool)?

    var isHighlightedForDrop: Bool = false {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderColor = isHighlightedForDrop
            ? NSColor(calibratedRed: 0.10, green: 0.47, blue: 0.91, alpha: 0.95).cgColor
            : NSColor.separatorColor.cgColor
    }

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

class MainWindowController: NSWindowController, NSCollectionViewDataSource, NSCollectionViewDelegate, NSWindowDelegate {
    private enum Theme {
        static let windowBackground = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.055, alpha: 1.0)
                : NSColor(calibratedWhite: 0.96, alpha: 1.0)
        }
        static let panel = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.105, alpha: 1.0)
                : NSColor(calibratedWhite: 0.985, alpha: 1.0)
        }
        static let panelStrong = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.15, alpha: 1.0)
                : NSColor(calibratedWhite: 0.90, alpha: 1.0)
        }
        static let browserSurface = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.12, alpha: 1.0)
                : NSColor(calibratedWhite: 0.97, alpha: 1.0)
        }
        static let border = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.24, alpha: 1.0)
                : NSColor(calibratedWhite: 0.78, alpha: 1.0)
        }
        static let accent = NSColor.systemBlue
        static let accentSoft = NSColor.systemBlue
        static let textPrimary = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white
                : NSColor(calibratedWhite: 0.08, alpha: 1.0)
        }
        static let textSecondary = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.68, alpha: 1.0)
                : NSColor(calibratedWhite: 0.34, alpha: 1.0)
        }
        static let disabledText = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.45, alpha: 1.0)
                : NSColor(calibratedWhite: 0.62, alpha: 1.0)
        }
    }

    private enum Layout {
        static let windowWidth: CGFloat = 720
        static let windowHeight: CGFloat = 860
        static let sideInset: CGFloat = 24
        static let contentWidth: CGFloat = 672
        static let headerY: CGFloat = 778
        static let selectorY: CGFloat = 700
        static let previewY: CGFloat = 344
        static let infoY: CGFloat = 286
        static let controlsY: CGFloat = 230
        static let settingsY: CGFloat = 54
    }

    let wallpaperManager: WallpaperManager

    private var previewImageView: NSImageView!
    private var previewPlayerLayer: AVPlayerLayer!
    private var previewStageView: NSView!
    private var previewPlayer: AVPlayer?
    private var previewOwnsPlayer = false
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
    private var fitModeLabel: NSTextField!
    private var fitModePopUp: NSPopUpButton!
    private var browseFolderButton: NSButton!
    private var folderCountLabel: NSTextField!
    private var syncCheckbox: NSButton!
    private var appearanceModeLabel: NSTextField!
    private var appearanceModePopUp: NSPopUpButton!
    private var newScreenPolicyLabel: NSTextField!
    private var newScreenPolicyPopUp: NSPopUpButton!
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    private var previewBrowserChromeView: NSView!
    private var dropZone: NSView!
    private var dropIconView: NSImageView!
    private var dropLabel: NSTextField!
    private var dropFormatsLabel: NSTextField!
    private var dropTapHintLabel: NSTextField!
    private var screenPopUp: NSPopUpButton!
    private var selectedScreen: NSScreen?
    private var baseBackgroundView: NSVisualEffectView?
    private var headerView: NSView?
    private var screenSelectorView: NSView?
    private var controlsView: NSView?
    private var settingsView: NSView?
    private var footerView: NSView?
    private var statusContainerView: NSView?
    private var backdropGradientLayer: CAGradientLayer?
    private var previewDisplayFrame: NSRect = .zero

    init(wallpaperManager: WallpaperManager) {
        self.wallpaperManager = wallpaperManager
        self.selectedScreen = NSScreen.screens.first(where: { $0.isBuiltIn }) ?? NSScreen.main
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Layout.windowWidth, height: Layout.windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "app.name".localized
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = Theme.windowBackground
        // Minimum size that prevents content overlap / compression:
        // bottom group (304) + top group (160) + preview-min (100) + gaps = ~620
        window.contentMinSize = NSSize(width: 540, height: 620)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.delegate = self
        window.setFrameAutosaveName("SakuraWallpaperMainWindow")
        setupUI()
    }

    required init?(coder: NSCoder) { nil }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        updateUI()
    }

    func windowDidMiniaturize(_ notification: Notification) {
        releasePreviewResources()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        updateUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let observer = previewEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        installBackdrop(in: contentView)

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
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResize), name: NSWindow.didResizeNotification, object: window)

        applyAppearanceMode()
        updateUI()
        layoutContent()
    }

    private func installBackdrop(in contentView: NSView) {
        let visual = NSVisualEffectView(frame: contentView.bounds)
        visual.autoresizingMask = [.width, .height]
        visual.blendingMode = .withinWindow
        visual.state = .active
        visual.material = .windowBackground
        visual.wantsLayer = true

        let gradient = CAGradientLayer()
        gradient.frame = visual.bounds
        gradient.colors = [
            resolvedCGColor(Theme.windowBackground),
            resolvedCGColor(Theme.windowBackground)
        ]
        gradient.startPoint = CGPoint(x: 0.1, y: 1)
        gradient.endPoint = CGPoint(x: 0.9, y: 0)
        visual.layer?.addSublayer(gradient)
        backdropGradientLayer = gradient

        contentView.addSubview(visual, positioned: .below, relativeTo: nil)
        baseBackgroundView = visual
    }

    private func styleGlassCard(_ view: NSView, cornerRadius: CGFloat = 16, alpha: CGFloat = 1.0) {
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.backgroundColor = resolvedCGColor(Theme.panel.withAlphaComponent(alpha))
        view.layer?.borderWidth = 1
        view.layer?.borderColor = resolvedCGColor(Theme.border)
        view.layer?.shadowOpacity = 0
    }

    private func resolvedCGColor(_ color: NSColor) -> CGColor {
        var cgColor = color.cgColor
        (window?.effectiveAppearance ?? NSApp.effectiveAppearance).performAsCurrentDrawingAppearance {
            cgColor = color.cgColor
        }
        return cgColor
    }

    private func stylePrimaryButton(_ button: NSButton) {
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 7
        button.layer?.backgroundColor = resolvedCGColor(Theme.panelStrong)
        button.layer?.borderWidth = 1
        button.layer?.borderColor = resolvedCGColor(Theme.border)
        button.contentTintColor = Theme.textPrimary
        button.font = NSFont.systemFont(ofSize: 13)
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: Theme.textPrimary,
                .font: button.font ?? NSFont.systemFont(ofSize: 13)
            ]
        )
    }

    private func styleGhostButton(_ button: NSButton) {
        stylePrimaryButton(button)
    }

    private func styleCompactGhostButton(_ button: NSButton) {
        stylePrimaryButton(button)
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 12)
    }

    private func styleCheckbox(_ button: NSButton) {
        button.setButtonType(.switch)
        button.isBordered = false
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.contentTintColor = button.isEnabled ? Theme.accent : Theme.disabledText
        button.image = nil
        button.alternateImage = nil
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: Theme.textPrimary,
                .font: button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ]
        )
    }

    private func stylePopUp(_ popUp: NSPopUpButton) {
        popUp.isBordered = true
        popUp.bezelStyle = .rounded
        popUp.contentTintColor = Theme.textPrimary
        for item in popUp.itemArray {
            item.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [
                    .foregroundColor: Theme.textPrimary,
                    .font: popUp.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                ]
            )
        }
    }

    private func sectionLabel(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(labelWithString: text.uppercased())
        label.font = NSFont(name: "Avenir Next Demi Bold", size: 10) ?? NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.textColor = Theme.textSecondary
        label.frame = frame
        return label
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
        let header = NSView(frame: NSRect(x: 0, y: Layout.headerY, width: Layout.windowWidth, height: 82))
        header.wantsLayer = true
        headerView = header

        let appIcon = NSTextField(labelWithString: "🌸")
        appIcon.font = NSFont.systemFont(ofSize: 28)
        appIcon.alignment = .center
        appIcon.frame = NSRect(x: 24, y: 26, width: 34, height: 34)
        header.addSubview(appIcon)

        let title = NSTextField(labelWithString: "app.name".localized)
        title.font = NSFont(name: "Avenir Next Demi Bold", size: 20) ?? NSFont.systemFont(ofSize: 20, weight: .semibold)
        title.textColor = Theme.textPrimary
        title.frame = NSRect(x: 68, y: 38, width: 320, height: 24)
        header.addSubview(title)

        let subtitle = NSTextField(labelWithString: "Wallpaper Workspace")
        subtitle.font = NSFont(name: "Avenir Next Medium", size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .medium)
        subtitle.textColor = Theme.textSecondary
        subtitle.frame = NSRect(x: 69, y: 21, width: 220, height: 14)
        header.addSubview(subtitle)

        let statusContainer = NSView(frame: NSRect(x: 526, y: 24, width: 170, height: 34))
        statusContainer.wantsLayer = true
        statusContainerView = statusContainer
        let indicatorBox = NSView(frame: NSRect(x: 12, y: 12, width: 8, height: 8))
        indicatorBox.wantsLayer = true
        indicatorBox.layer?.cornerRadius = 4
        indicatorBox.layer?.backgroundColor = resolvedCGColor(.systemGray)
        statusIndicator = indicatorBox
        statusContainer.addSubview(statusIndicator)

        statusLabel = NSTextField(labelWithString: "ui.status".localized("ui.notSet".localized))
        statusLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .semibold)
        statusLabel.textColor = Theme.textSecondary
        statusLabel.frame = NSRect(x: 28, y: 9, width: 128, height: 16)
        statusContainer.addSubview(statusLabel)
        header.addSubview(statusContainer)

        let separator = NSBox(frame: NSRect(x: Layout.sideInset, y: 0, width: Layout.contentWidth, height: 1))
        separator.boxType = .separator
        header.addSubview(separator)

        return header
    }

    private func createScreenSelector() -> NSView {
        let container = NSView(frame: NSRect(x: Layout.sideInset, y: Layout.selectorY, width: Layout.contentWidth, height: 62))
        styleGlassCard(container, cornerRadius: 12, alpha: 0.94)
        screenSelectorView = container

        container.addSubview(sectionLabel("screen", frame: NSRect(x: 18, y: 39, width: 92, height: 14)))

        let label = NSTextField(labelWithString: "\("ui.screen".localized):")
        label.font = NSFont(name: "Avenir Next Demi Bold", size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = Theme.textSecondary
        label.frame = NSRect(x: 18, y: 14, width: 60, height: 16)
        container.addSubview(label)

        screenPopUp = NSPopUpButton(frame: NSRect(x: 80, y: 10, width: 350, height: 28))
        screenPopUp.target = self
        screenPopUp.action = #selector(screenSelectionChanged)
        screenPopUp.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .medium)
        stylePopUp(screenPopUp)
        container.addSubview(screenPopUp)

        syncCheckbox = NSButton(checkboxWithTitle: "ui.syncScreens".localized, target: self, action: #selector(syncCheckboxChanged(_:)))
        syncCheckbox.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        styleCheckbox(syncCheckbox)
        syncCheckbox.frame = NSRect(x: 458, y: 14, width: 190, height: 20)
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
            let id = SettingsManager.screenIdentifier(screen)
            let isLinked = SettingsManager.shared.screenConfig(for: id).isSynced
            let linkIndicator = isLinked ? " 🔗" : ""
            screenPopUp.addItem(withTitle: "\(displayName)\(suffix)\(linkIndicator)")
            screenPopUp.lastItem?.representedObject = screen
        }
        stylePopUp(screenPopUp)

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

    // MARK: - Window resize

    @objc private func windowDidResize() {
        layoutContent()
        applyPreviewLayout(isFolder: currentPreviewIsFolder ?? false, browserVisible: currentPreviewBrowserVisible ?? false)
    }

    private func layoutContent() {
        guard let contentView = window?.contentView else { return }
        let w = contentView.bounds.width
        let h = contentView.bounds.height
        let cw = w - Layout.sideInset * 2

        // ── Static element heights ──
        let headerH:    CGFloat = 82
        let selectorH:  CGFloat = 62
        let infoH:      CGFloat = 44
        let controlsH:  CGFloat = 42
        let settingsH:  CGFloat = 158
        let footerH:    CGFloat = 28

        // ── Default gaps (measured from the original 860-pt design) ──
        let gFooterSettings:     CGFloat = 26   // footer top  → settings bottom
        let gSettingsControls:   CGFloat = 18   // settings top → controls bottom
        let gControlsInfo:       CGFloat = 14   // controls top  → info bottom
        let gInfoPreview:        CGFloat = 14   // info top      → preview bottom
        let gPreviewSelector:    CGFloat = 16   // preview top   → selector bottom
        let gSelectorHeader:     CGFloat = 16   // selector top  → header bottom

        let totalFixed = headerH + selectorH + infoH + controlsH + settingsH + footerH
        let totalGaps  = gFooterSettings + gSettingsControls + gControlsInfo
                       + gInfoPreview + gPreviewSelector + gSelectorHeader
        let minPreviewH: CGFloat = 120
        let designH = totalFixed + totalGaps + 340  // 340 = default preview height

        // Extra height beyond the design height
        let extra = max(h - designH, 0)
        // Distribute extra: preview absorbs the rest, 30 % to gaps, 20 % to top
        let gapExtra = extra * 0.30
        let topExtra = extra * 0.20

        // ── Scale each gap proportionally ──
        let scaleGap = totalGaps > 0 ? gapExtra / totalGaps : 0
        let gf = gFooterSettings   + gFooterSettings   * scaleGap
        let gs = gSettingsControls + gSettingsControls * scaleGap
        let gc = gControlsInfo     + gControlsInfo     * scaleGap
        let gi = gInfoPreview      + gInfoPreview      * scaleGap
        let gp = gPreviewSelector  + gPreviewSelector  * scaleGap
        let gh = gSelectorHeader   + gSelectorHeader   * scaleGap + topExtra

        // ── Lay out bottom → top ──
        var y: CGFloat = 0

        // Footer
        footerView?.frame = NSRect(x: 0, y: y, width: w, height: footerH)
        if let f = footerView {
            if let sep = f.subviews.first(where: { $0 is NSBox }) {
                sep.frame = NSRect(x: Layout.sideInset, y: footerH - 1, width: cw, height: 1)
            }
            if let author = f.subviews.last(where: { $0 is NSTextField }) {
                author.frame = NSRect(x: Layout.sideInset, y: 6, width: cw, height: 16)
            }
        }
        y += footerH + gf

        // Settings
        settingsView?.frame = NSRect(x: Layout.sideInset, y: y, width: cw, height: settingsH)
        y += settingsH + gs

        // Controls
        controlsView?.frame = NSRect(x: Layout.sideInset, y: y, width: cw, height: controlsH)
        y += controlsH + gc

        // Info bar
        if let bar = fileNameLabel?.superview {
            bar.frame = NSRect(x: Layout.sideInset, y: y, width: cw, height: infoH)
        }
        y += infoH + gi

        // Preview — fills remaining space, gets most of the extra height
        let previewY = y
        let headerBottom = h - headerH
        let selectorY = headerBottom - gh - selectorH
        let previewH = max(selectorY - gp - previewY, minPreviewH)

        // Constrain preview aspect ratio so it doesn't turn into a thin strip
        // when the window is very wide (e.g. fullscreen).
        let maxPreviewAspect: CGFloat = 2.4
        var previewW = cw
        var previewX = Layout.sideInset
        if previewH > 0 && previewW / previewH > maxPreviewAspect {
            previewW = previewH * maxPreviewAspect
            previewX = (w - previewW) / 2
        }
        previewContainer?.frame = NSRect(x: previewX, y: previewY, width: previewW, height: previewH)
        y = previewY + previewH + gp

        // Selector
        screenSelectorView?.frame = NSRect(x: Layout.sideInset, y: y, width: cw, height: selectorH)
        y += selectorH + gh

        // Header: pin to top (y is the header bottom after accumulation)
        headerView?.frame = NSRect(x: 0, y: y, width: w, height: headerH)
        if let hdr = headerView, let sep = hdr.subviews.first(where: { $0 is NSBox }) {
            sep.frame = NSRect(x: Layout.sideInset, y: 0, width: cw, height: 1)
        }
        if let sc = statusContainerView {
            sc.frame.origin.x = w - sc.frame.width - Layout.sideInset
        }

        // Backdrop
        backdropGradientLayer?.frame = contentView.bounds

        // Preview internals
        if let pc = previewContainer {
            previewDisplayFrame = pc.bounds
            previewStageView?.frame = previewDisplayFrame
            previewPlayerLayer?.frame = previewStageView?.bounds ?? .zero
            previewImageView?.frame = previewStageView?.bounds ?? .zero
            previewLoadingOverlay?.frame = pc.bounds
        }
    }

    private func createPreviewContainer() -> NSView {
        previewContainer = DragDropContainerView(frame: NSRect(x: Layout.sideInset, y: Layout.previewY, width: Layout.contentWidth, height: 340))
        styleGlassCard(previewContainer, cornerRadius: 16, alpha: 0.98)
        previewContainer.layer?.masksToBounds = true
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

        let dropBox = NSView(frame: previewContainer.bounds)
        dropBox.wantsLayer = true
        dropBox.layer?.cornerRadius = 10
        dropBox.layer?.backgroundColor = resolvedCGColor(Theme.panel)
        dropZone = dropBox

        dropIconView = NSImageView(frame: NSRect(x: 0, y: 192, width: Layout.contentWidth, height: 48))
        dropIconView.imageAlignment = .alignCenter
        dropIconView.imageScaling = .scaleProportionallyDown
        if #available(macOS 11.0, *) {
            dropIconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 44, weight: .regular)
            dropIconView.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: nil)
            dropIconView.contentTintColor = Theme.accent
        } else {
            dropIconView.image = NSImage(named: NSImage.folderName)
        }
        dropZone.addSubview(dropIconView)

        dropLabel = NSTextField(labelWithString: "ui.dropHere".localized)
        dropLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 14) ?? NSFont.systemFont(ofSize: 13, weight: .semibold)
        dropLabel.textColor = Theme.textPrimary
        dropLabel.alignment = .center
        dropLabel.frame = NSRect(x: 0, y: 150, width: Layout.contentWidth, height: 34)
        dropZone.addSubview(dropLabel)

        dropFormatsLabel = NSTextField(labelWithString: "ui.formats".localized)
        dropFormatsLabel.font = NSFont(name: "Avenir Next Medium", size: 10) ?? NSFont.systemFont(ofSize: 10)
        dropFormatsLabel.textColor = Theme.textSecondary
        dropFormatsLabel.alignment = .center
        dropFormatsLabel.frame = NSRect(x: 0, y: 130, width: Layout.contentWidth, height: 16)
        dropZone.addSubview(dropFormatsLabel)

        dropTapHintLabel = NSTextField(labelWithString: "ui.tapToPick".localized)
        dropTapHintLabel.font = NSFont(name: "Avenir Next Medium", size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .medium)
        dropTapHintLabel.textColor = Theme.textSecondary
        dropTapHintLabel.alignment = .center
        dropTapHintLabel.frame = NSRect(x: 0, y: 106, width: Layout.contentWidth, height: 18)
        dropZone.addSubview(dropTapHintLabel)

        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(selectFromDropZone))
        dropZone.addGestureRecognizer(clickRecognizer)

        previewContainer.addSubview(dropZone)

        previewStageView = NSView(frame: previewContainer.bounds)
        previewStageView.wantsLayer = true
        previewStageView.layer?.masksToBounds = true
        previewStageView.layer?.backgroundColor = NSColor.black.cgColor
        previewContainer.addSubview(previewStageView)

        previewImageView = NSImageView(frame: previewStageView.bounds)
        previewImageView.imageScaling = .scaleAxesIndependently
        previewImageView.imageAlignment = .alignCenter
        previewImageView.isHidden = true
        previewStageView.addSubview(previewImageView)

        previewPlayerLayer = AVPlayerLayer()
        previewPlayerLayer.videoGravity = .resizeAspectFill
        previewPlayerLayer.frame = previewStageView.bounds
        previewStageView.layer?.addSublayer(previewPlayerLayer)

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 120, height: 76)
        layout.sectionInset = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.scrollDirection = .horizontal

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.delegate = self
        collectionView.register(ThumbnailItem.self, forItemWithIdentifier: ThumbnailItem.identifier)
        collectionView.dataSource = self

        previewBrowserChromeView = NSView(frame: NSRect(x: 16, y: 16, width: Layout.contentWidth - 32, height: 96))
        previewBrowserChromeView.wantsLayer = true
        previewBrowserChromeView.layer?.cornerRadius = 14
        previewBrowserChromeView.layer?.borderWidth = 1
        previewBrowserChromeView.layer?.borderColor = resolvedCGColor(Theme.border)
        previewBrowserChromeView.layer?.backgroundColor = resolvedCGColor(Theme.browserSurface)
        previewBrowserChromeView.isHidden = true

        scrollView = NSScrollView(frame: NSRect(x: 8, y: 8, width: previewBrowserChromeView.bounds.width - 16, height: previewBrowserChromeView.bounds.height - 16))
        scrollView.documentView = collectionView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.drawsBackground = false
        scrollView.isHidden = true
        previewBrowserChromeView.addSubview(scrollView)
        previewContainer.addSubview(previewBrowserChromeView)

        let overlayBox = NSView(frame: previewContainer.bounds)
        overlayBox.wantsLayer = true
        overlayBox.layer?.cornerRadius = 10
        overlayBox.layer?.backgroundColor = resolvedCGColor(Theme.panel.withAlphaComponent(0.9))
        overlayBox.autoresizingMask = [.width, .height]
        overlayBox.isHidden = true
        previewLoadingOverlay = overlayBox

        previewLoadingSpinner = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        previewLoadingSpinner.style = .spinning
        previewLoadingSpinner.controlSize = .small
        previewLoadingSpinner.frame.origin = NSPoint(x: (previewLoadingOverlay.bounds.width - 20) / 2, y: (previewLoadingOverlay.bounds.height - 20) / 2 + 10)
        previewLoadingSpinner.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        previewLoadingOverlay.addSubview(previewLoadingSpinner)

        previewLoadingLabel = NSTextField(labelWithString: "ui.loadingPreview".localized)
        previewLoadingLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        previewLoadingLabel.textColor = Theme.textSecondary
        previewLoadingLabel.alignment = .center
        previewLoadingLabel.frame = NSRect(x: 0, y: previewLoadingSpinner.frame.minY - 24, width: previewLoadingOverlay.bounds.width, height: 18)
        previewLoadingLabel.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        previewLoadingOverlay.addSubview(previewLoadingLabel)

        previewContainer.addSubview(previewLoadingOverlay)

        return previewContainer
    }

    private func createInfoBar() -> NSView {
        let bar = NSView(frame: NSRect(x: Layout.sideInset, y: Layout.infoY, width: Layout.contentWidth, height: 44))
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.clear.cgColor

        fileNameLabel = NSTextField(labelWithString: "ui.noWallpaper".localized)
        fileNameLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .semibold)
        fileNameLabel.textColor = Theme.textPrimary
        fileNameLabel.lineBreakMode = .byTruncatingMiddle
        fileNameLabel.frame = NSRect(x: 0, y: 22, width: 430, height: 18)
        bar.addSubview(fileNameLabel)

        fileTypeLabel = NSTextField(labelWithString: "")
        fileTypeLabel.font = NSFont(name: "Avenir Next Medium", size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .medium)
        fileTypeLabel.textColor = Theme.textSecondary
        fileTypeLabel.alignment = .right
        fileTypeLabel.frame = NSRect(x: 438, y: 22, width: 106, height: 18)
        bar.addSubview(fileTypeLabel)

        folderCountLabel = NSTextField(labelWithString: "")
        folderCountLabel.font = NSFont(name: "Avenir Next Medium", size: 11) ?? NSFont.systemFont(ofSize: 11)
        folderCountLabel.textColor = Theme.textSecondary
        folderCountLabel.frame = NSRect(x: 0, y: 2, width: 360, height: 16)
        bar.addSubview(folderCountLabel)

        browseFolderButton = NSButton(title: "ui.browseFolder".localized, target: self, action: #selector(toggleFolderBrowser))
        browseFolderButton.frame = NSRect(x: 552, y: 8, width: 120, height: 28)
        browseFolderButton.isHidden = true
        styleCompactGhostButton(browseFolderButton)
        bar.addSubview(browseFolderButton)

        return bar
    }

    private func createControls() -> NSView {
        let controls = NSView(frame: NSRect(x: Layout.sideInset, y: Layout.controlsY, width: Layout.contentWidth, height: 42))
        controls.wantsLayer = true
        controls.layer?.backgroundColor = NSColor.clear.cgColor
        controlsView = controls

        selectFileButton = NSButton(title: "ui.selectFile".localized, target: self, action: #selector(selectFile))
        selectFileButton.frame = NSRect(x: 0, y: 0, width: 210, height: 38)
        stylePrimaryButton(selectFileButton)
        controls.addSubview(selectFileButton)

        selectFolderButton = NSButton(title: "ui.selectFolder".localized, target: self, action: #selector(selectFolder))
        selectFolderButton.frame = NSRect(x: 224, y: 0, width: 210, height: 38)
        styleGhostButton(selectFolderButton)
        controls.addSubview(selectFolderButton)

        stopButton = NSButton(title: "ui.stopWallpaper".localized, target: self, action: #selector(stopWallpaper))
        stopButton.controlSize = .regular
        stopButton.frame = NSRect(x: 448, y: 0, width: 224, height: 38)
        styleGhostButton(stopButton)
        stopButton.toolTip = "ui.stopWallpaperTooltip".localized
        controls.addSubview(stopButton)

        return controls
    }

    private func createSettings() -> NSView {
        let settings = NSView(frame: NSRect(x: Layout.sideInset, y: Layout.settingsY, width: Layout.contentWidth, height: 158))
        styleGlassCard(settings, cornerRadius: 14, alpha: 0.95)
        settingsView = settings

        settings.addSubview(sectionLabel("wallpaper", frame: NSRect(x: 18, y: 130, width: 120, height: 14)))
        settings.addSubview(sectionLabel("app", frame: NSRect(x: 346, y: 130, width: 120, height: 14)))

        let divider = NSBox(frame: NSRect(x: 326, y: 18, width: 1, height: 120))
        divider.boxType = .separator
        settings.addSubview(divider)

        launchSwitch = NSButton(checkboxWithTitle: "ui.launchAtLogin".localized,
                                target: self, action: #selector(launchSwitchChanged))
        launchSwitch.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        styleCheckbox(launchSwitch)
        launchSwitch.frame = NSRect(x: 346, y: 100, width: 260, height: 20)
        launchSwitch.state = SettingsManager.shared.launchAtLogin ? .on : .off
        settings.addSubview(launchSwitch)

        pauseSwitch = NSButton(checkboxWithTitle: "ui.pauseWhenInvisible".localized,
                               target: self, action: #selector(pauseSwitchChanged))
        pauseSwitch.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        styleCheckbox(pauseSwitch)
        pauseSwitch.frame = NSRect(x: 346, y: 76, width: 280, height: 20)
        pauseSwitch.state = SettingsManager.shared.pauseWhenInvisible ? .on : .off
        settings.addSubview(pauseSwitch)

        syncDesktopSwitch = NSButton(checkboxWithTitle: "ui.syncDesktopWallpaper".localized,
                                     target: self, action: #selector(syncDesktopSwitchChanged))
        syncDesktopSwitch.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        styleCheckbox(syncDesktopSwitch)
        syncDesktopSwitch.frame = NSRect(x: 346, y: 52, width: 290, height: 20)
        syncDesktopSwitch.state = SettingsManager.shared.syncDesktopWallpaper ? .on : .off
        syncDesktopSwitch.toolTip = "ui.syncDesktopWallpaper.tooltip".localized
        settings.addSubview(syncDesktopSwitch)

        rotationSwitch = NSButton(checkboxWithTitle: "ui.enableRotation".localized,
                                  target: self, action: #selector(rotationSwitchChanged))
        rotationSwitch.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        styleCheckbox(rotationSwitch)
        rotationSwitch.frame = NSRect(x: 18, y: 92, width: 130, height: 20)
        rotationSwitch.state = Screen_Config.default.isRotationEnabled ? .on : .off
        settings.addSubview(rotationSwitch)

        shuffleSwitch = NSButton(checkboxWithTitle: "ui.shuffleMode".localized,
                                 target: self, action: #selector(shuffleSwitchChanged))
        shuffleSwitch.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        styleCheckbox(shuffleSwitch)
        shuffleSwitch.frame = NSRect(x: 156, y: 92, width: 130, height: 20)
        shuffleSwitch.state = Screen_Config.default.isShuffleMode ? .on : .off
        settings.addSubview(shuffleSwitch)

        includeSubfoldersSwitch = NSButton(checkboxWithTitle: "ui.includeSubfolders".localized,
                                           target: self, action: #selector(includeSubfoldersChanged))
        includeSubfoldersSwitch.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        styleCheckbox(includeSubfoldersSwitch)
        includeSubfoldersSwitch.frame = NSRect(x: 18, y: 68, width: 220, height: 20)
        includeSubfoldersSwitch.state = Screen_Config.default.includeSubfolders ? .on : .off
        settings.addSubview(includeSubfoldersSwitch)

        fitModeLabel = NSTextField(labelWithString: "ui.fitMode".localized + ":")
        fitModeLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .semibold)
        fitModeLabel.textColor = Theme.textPrimary
        fitModeLabel.frame = NSRect(x: 18, y: 40, width: 76, height: 20)
        settings.addSubview(fitModeLabel)

        fitModePopUp = NSPopUpButton(frame: NSRect(x: 94, y: 36, width: 138, height: 26))
        fitModePopUp.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        fitModePopUp.target = self
        fitModePopUp.action = #selector(fitModeChanged(_:))
        fitModePopUp.addItem(withTitle: "ui.fit.fill".localized)
        fitModePopUp.lastItem?.representedObject = WallpaperFitMode.fill.rawValue
        fitModePopUp.addItem(withTitle: "ui.fit.fit".localized)
        fitModePopUp.lastItem?.representedObject = WallpaperFitMode.fit.rawValue
        fitModePopUp.addItem(withTitle: "ui.fit.stretch".localized)
        fitModePopUp.lastItem?.representedObject = WallpaperFitMode.stretch.rawValue
        stylePopUp(fitModePopUp)
        settings.addSubview(fitModePopUp)

        intervalPrefix = NSTextField(labelWithString: "ui.rotationInterval".localized + ":")
        intervalPrefix.font = NSFont(name: "Avenir Next Demi Bold", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .semibold)
        intervalPrefix.textColor = Theme.textPrimary
        intervalPrefix.frame = NSRect(x: 18, y: 12, width: 112, height: 20)
        settings.addSubview(intervalPrefix)

        intervalField = NSTextField(frame: NSRect(x: 130, y: 8, width: 56, height: 24))
        intervalField.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        intervalField.alignment = .right
        intervalField.target = self
        intervalField.action = #selector(intervalFieldChanged)
        intervalField.wantsLayer = true
        intervalField.layer?.cornerRadius = 8
        intervalField.layer?.borderWidth = 1
        intervalField.layer?.borderColor = resolvedCGColor(Theme.border)
        intervalField.backgroundColor = .textBackgroundColor
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 1
        intervalField.formatter = formatter
        intervalField.integerValue = Screen_Config.default.rotationIntervalMinutes
        settings.addSubview(intervalField)

        intervalStepper = NSStepper(frame: NSRect(x: 192, y: 10, width: 18, height: 22))
        intervalStepper.minValue = 1
        intervalStepper.maxValue = 1440
        intervalStepper.increment = 1
        intervalStepper.valueWraps = false
        intervalStepper.integerValue = Screen_Config.default.rotationIntervalMinutes
        intervalStepper.target = self
        intervalStepper.action = #selector(intervalStepperChanged)
        settings.addSubview(intervalStepper)

        intervalLabel = NSTextField(labelWithString: formatInterval(minutes: Screen_Config.default.rotationIntervalMinutes))
        intervalLabel.font = NSFont(name: "Avenir Next Medium", size: 11) ?? NSFont.systemFont(ofSize: 11)
        intervalLabel.textColor = Theme.textSecondary
        intervalLabel.frame = NSRect(x: 218, y: 12, width: 70, height: 16)
        settings.addSubview(intervalLabel)

        appearanceModeLabel = NSTextField(labelWithString: "ui.appearance".localized + ":")
        appearanceModeLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .semibold)
        appearanceModeLabel.textColor = Theme.textPrimary
        appearanceModeLabel.frame = NSRect(x: 346, y: 28, width: 120, height: 18)
        settings.addSubview(appearanceModeLabel)

        appearanceModePopUp = NSPopUpButton(frame: NSRect(x: 346, y: 4, width: 136, height: 26))
        appearanceModePopUp.target = self
        appearanceModePopUp.action = #selector(appearanceModeChanged(_:))
        appearanceModePopUp.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        appearanceModePopUp.addItem(withTitle: "ui.appearance.system".localized)
        appearanceModePopUp.lastItem?.representedObject = AppearanceMode.system.rawValue
        appearanceModePopUp.addItem(withTitle: "ui.appearance.light".localized)
        appearanceModePopUp.lastItem?.representedObject = AppearanceMode.light.rawValue
        appearanceModePopUp.addItem(withTitle: "ui.appearance.dark".localized)
        appearanceModePopUp.lastItem?.representedObject = AppearanceMode.dark.rawValue
        stylePopUp(appearanceModePopUp)
        settings.addSubview(appearanceModePopUp)

        newScreenPolicyLabel = NSTextField(labelWithString: "ui.newScreenPolicy".localized + ":")
        newScreenPolicyLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .semibold)
        newScreenPolicyLabel.textColor = Theme.textPrimary
        newScreenPolicyLabel.frame = NSRect(x: 500, y: 28, width: 148, height: 18)
        settings.addSubview(newScreenPolicyLabel)

        newScreenPolicyPopUp = NSPopUpButton(frame: NSRect(x: 500, y: 4, width: 148, height: 26))
        newScreenPolicyPopUp.target = self
        newScreenPolicyPopUp.action = #selector(newScreenPolicyChanged(_:))
        newScreenPolicyPopUp.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        newScreenPolicyPopUp.toolTip = "ui.newScreenPolicy.tooltip".localized
        newScreenPolicyPopUp.addItem(withTitle: "ui.newScreenPolicy.inheritSyncGroup".localized)
        newScreenPolicyPopUp.lastItem?.representedObject = New_Screen_Policy.inheritSyncGroup.rawValue
        newScreenPolicyPopUp.addItem(withTitle: "ui.newScreenPolicy.blank".localized)
        newScreenPolicyPopUp.lastItem?.representedObject = New_Screen_Policy.blank.rawValue
        stylePopUp(newScreenPolicyPopUp)
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

    private func updateAppearanceModeMenu() {
        let currentMode = SettingsManager.shared.appearanceMode
        for (index, item) in appearanceModePopUp.itemArray.enumerated() {
            if let rawValue = item.representedObject as? String,
               rawValue == currentMode.rawValue {
                appearanceModePopUp.selectItem(at: index)
                break
            }
        }
    }

    private func updateFitModeMenu(for fitMode: WallpaperFitMode) {
        for (index, item) in fitModePopUp.itemArray.enumerated() {
            if let rawValue = item.representedObject as? String,
               rawValue == fitMode.rawValue {
                fitModePopUp.selectItem(at: index)
                break
            }
        }
    }

    private func applyAppearanceMode() {
        switch SettingsManager.shared.appearanceMode {
        case .system:
            window?.appearance = nil
        case .light:
            window?.appearance = NSAppearance(named: .aqua)
        case .dark:
            window?.appearance = NSAppearance(named: .darkAqua)
        }
        refreshTheme()
    }

    private func refreshTheme() {
        backdropGradientLayer?.colors = [
            resolvedCGColor(Theme.windowBackground),
            resolvedCGColor(Theme.windowBackground)
        ]
        baseBackgroundView?.material = .contentBackground
        window?.backgroundColor = Theme.windowBackground
        if let previewContainer {
            styleGlassCard(previewContainer, cornerRadius: 16, alpha: 0.98)
            previewContainer.layer?.masksToBounds = true
        }
        if let screenSelectorView {
            styleGlassCard(screenSelectorView, cornerRadius: 12, alpha: 0.94)
        }
        if let settingsView {
            styleGlassCard(settingsView, cornerRadius: 14, alpha: 0.95)
        }
        if let headerView {
            headerView.layer?.backgroundColor = resolvedCGColor(Theme.windowBackground)
        }
        controlsView?.layer?.backgroundColor = NSColor.clear.cgColor
        if let footerView {
            footerView.layer?.backgroundColor = resolvedCGColor(Theme.windowBackground)
        }
        if let statusContainerView {
            statusContainerView.layer?.cornerRadius = 9
            statusContainerView.layer?.backgroundColor = resolvedCGColor(Theme.panelStrong.withAlphaComponent(0.86))
            statusContainerView.layer?.borderWidth = 1
            statusContainerView.layer?.borderColor = resolvedCGColor(Theme.border)
        }
        if let browseFolderButton {
            styleCompactGhostButton(browseFolderButton)
        }
        stylePrimaryButton(selectFileButton)
        styleGhostButton(selectFolderButton)
        styleGhostButton(stopButton)
        styleCheckbox(syncCheckbox)
        styleCheckbox(launchSwitch)
        styleCheckbox(pauseSwitch)
        styleCheckbox(syncDesktopSwitch)
        styleCheckbox(rotationSwitch)
        styleCheckbox(shuffleSwitch)
        styleCheckbox(includeSubfoldersSwitch)
        stylePopUp(screenPopUp)
        stylePopUp(fitModePopUp)
        stylePopUp(appearanceModePopUp)
        stylePopUp(newScreenPolicyPopUp)
        previewBrowserChromeView?.layer?.backgroundColor = resolvedCGColor(Theme.browserSurface)
        previewBrowserChromeView?.layer?.borderColor = resolvedCGColor(Theme.border)
        intervalField?.backgroundColor = Theme.panelStrong
        intervalField?.textColor = Theme.textPrimary
        previewStageView?.layer?.backgroundColor = NSColor.black.cgColor
        dropZone?.layer?.backgroundColor = resolvedCGColor(Theme.panelStrong)
        previewLoadingOverlay?.layer?.backgroundColor = resolvedCGColor(Theme.panelStrong.withAlphaComponent(0.88))
    }

    private func createFooter() -> NSView {
        let footer = NSView(frame: NSRect(x: 0, y: 0, width: Layout.windowWidth, height: 28))
        footer.wantsLayer = true
        footerView = footer

        let separator = NSBox(frame: NSRect(x: Layout.sideInset, y: 27, width: Layout.contentWidth, height: 1))
        separator.boxType = .separator
        footer.addSubview(separator)

        let author = NSTextField(labelWithString: "ui.madeBy".localized("❤️"))
        author.font = NSFont(name: "Avenir Next Medium", size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .medium)
        author.textColor = Theme.textSecondary
        author.alignment = .center
        author.frame = NSRect(x: Layout.sideInset, y: 6, width: Layout.contentWidth, height: 16)
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
                // Create a security-scoped bookmark for persistent access
                // across app launches — prevents repeated TCC prompts
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                try setWallpaper(url: url, bookmarkData: bookmarkData)
            } catch {
                showError(error)
            }
        }
    }

    private func setWallpaper(url: URL, bookmarkData: Data? = nil) throws {
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
                isSynced: selectedScreen.map { SettingsManager.shared.screenConfig(for: SettingsManager.screenIdentifier($0)).isSynced } ?? true,
                securityScopedBookmark: bookmarkData
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
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
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
        wallpaperManager.setSyncDesktopWallpaperEnabled(sender.state == .on)
    }

    @objc func fitModeChanged(_ sender: NSPopUpButton) {
        guard let screen = selectedScreen,
              let rawValue = sender.selectedItem?.representedObject as? String,
              let fitMode = WallpaperFitMode(rawValue: rawValue) else { return }
        let id = SettingsManager.screenIdentifier(screen)
        var config = SettingsManager.shared.screenConfig(for: id)
        config.wallpaperFit = fitMode
        SettingsManager.shared.setScreenConfig(config, for: id)
        wallpaperManager.propagateSettingsToSyncGroup(fromScreenID: id)
        wallpaperManager.refreshWallpaperFit(for: screen)

        if config.isSynced {
            for syncedScreen in NSScreen.screens where syncedScreen != screen {
                let sid = SettingsManager.screenIdentifier(syncedScreen)
                if SettingsManager.shared.screenConfig(for: sid).isSynced {
                    wallpaperManager.refreshWallpaperFit(for: syncedScreen)
                }
            }
        }
        updateUI()
    }

    @objc func appearanceModeChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let mode = AppearanceMode(rawValue: rawValue) else { return }
        SettingsManager.shared.appearanceMode = mode
        applyAppearanceMode()
        updateUI()
    }

    @objc private func toggleFolderBrowser() {
        guard let screen = selectedScreen else { return }
        let id = SettingsManager.screenIdentifier(screen)
        var config = SettingsManager.shared.screenConfig(for: id)
        config.isFolderBrowserVisible.toggle()
        SettingsManager.shared.setScreenConfig(config, for: id)
        wallpaperManager.propagateSettingsToSyncGroup(fromScreenID: id)
        currentPreviewBrowserVisible = config.isFolderBrowserVisible
        updateUI()
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
            wallpaperManager.propagateSettingsToSyncGroup(fromScreenID: id)
        }
        updateUI()
    }

    @objc func shuffleSwitchChanged(_ sender: NSButton) {
        guard let screen = selectedScreen else { return }
        let id = SettingsManager.screenIdentifier(screen)
        var config = SettingsManager.shared.screenConfig(for: id)
        config.isShuffleMode = (sender.state == .on)
        SettingsManager.shared.setScreenConfig(config, for: id)
        wallpaperManager.propagateSettingsToSyncGroup(fromScreenID: id)
        wallpaperManager.startRotationTimer()
        updateUI()
    }

    @objc func rotationSwitchChanged(_ sender: NSButton) {
        guard let screen = selectedScreen else { return }
        let id = SettingsManager.screenIdentifier(screen)
        var config = SettingsManager.shared.screenConfig(for: id)
        config.isRotationEnabled = (sender.state == .on)
        SettingsManager.shared.setScreenConfig(config, for: id)
        wallpaperManager.propagateSettingsToSyncGroup(fromScreenID: id)
        wallpaperManager.startRotationTimer()
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
        wallpaperManager.propagateSettingsToSyncGroup(fromScreenID: id)
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
    private var currentPreviewFitMode: WallpaperFitMode?
    private var currentPreviewIsFolder: Bool?
    private var currentPreviewBrowserVisible: Bool?

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
        previewContainer.isHighlightedForDrop = active
        dropLabel.textColor = active
            ? Theme.accent
            : Theme.textPrimary
        dropFormatsLabel.textColor = active
            ? Theme.accent
            : Theme.textSecondary
        dropTapHintLabel.textColor = active
            ? Theme.accent
            : Theme.textSecondary
        if #available(macOS 11.0, *) {
            dropIconView.contentTintColor = active
                ? Theme.accent
                : Theme.accentSoft
        }
    }

    private func handleDroppedURLs(_ urls: [URL]) -> Bool {
        guard let url = urls.first(where: { isAcceptableDropURL($0) }) else { return false }
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            try setWallpaper(url: url, bookmarkData: bookmarkData)
            return true
        } catch {
            showError(error)
            return false
        }
    }

    func updateUI() {
        updateScreenMenu()
        updateNewScreenPolicyMenu()
        updateAppearanceModeMenu()

        let selectedScreenID = selectedScreen.map { SettingsManager.screenIdentifier($0) } ?? ""
        let config = SettingsManager.shared.screenConfig(for: selectedScreenID)
        updateFitModeMenu(for: config.wallpaperFit)

        // Sync checkbox — only meaningful with multiple screens
        syncCheckbox.state = config.isSynced ? .on : .off
        syncCheckbox.isEnabled = NSScreen.screens.count > 1

        let activeScreen = selectedScreen ?? NSScreen.main ?? NSScreen.screens.first
        stopButton.title = "ui.stopWallpaper".localized
        stopButton.isEnabled = activeScreen.flatMap { wallpaperManager.wallpaperPath(for: $0) } != nil
            || config.folderPath != nil
        styleGhostButton(stopButton)
        stopButton.alphaValue = stopButton.isEnabled ? 1.0 : 0.55

        let isFolderMode = config.isFolderMode
        let isRotationEnabled = config.isRotationEnabled
        let isShuffleMode = config.isShuffleMode
        let currentIncludeSubfolders = config.includeSubfolders
        let currentInterval = config.rotationIntervalMinutes
        let browserVisible = config.isFolderBrowserVisible

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

        rotationSwitch.contentTintColor = isFolderMode ? Theme.accent : Theme.disabledText
        shuffleSwitch.contentTintColor = (isFolderMode && isRotationEnabled) ? Theme.accent : Theme.disabledText
        styleCheckbox(rotationSwitch)
        styleCheckbox(shuffleSwitch)
        styleCheckbox(includeSubfoldersSwitch)
        intervalPrefix.textColor = (isFolderMode && isRotationEnabled) ? Theme.textPrimary : Theme.disabledText
        intervalLabel.textColor = (isFolderMode && isRotationEnabled) ? Theme.textSecondary : Theme.disabledText
        folderCountLabel.textColor = isFolderMode ? Theme.textSecondary : Theme.disabledText
        if isFolderMode {
            let recursive = currentIncludeSubfolders ? "ui.recursiveEnabled".localized : "ui.recursiveDisabled".localized
            let playlistCount = wallpaperManager.playlist(for: selectedScreenID).count
            folderCountLabel.stringValue = "ui.folderItems".localized(playlistCount, recursive)
            browseFolderButton.isHidden = playlistCount == 0
            browseFolderButton.title = browserVisible ? "ui.hideFolderBrowser".localized : "ui.browseFolder".localized
            styleCompactGhostButton(browseFolderButton)
            browseFolderButton.alphaValue = playlistCount == 0 ? 0.0 : 1.0
        } else {
            folderCountLabel.stringValue = ""
            browseFolderButton.isHidden = true
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
                switch type {
                case .video:
                    fileTypeLabel.stringValue = "ui.video".localized
                case .gif:
                    fileTypeLabel.stringValue = "ui.gif".localized
                case .image:
                    fileTypeLabel.stringValue = "ui.image".localized
                case .unsupported:
                    fileTypeLabel.stringValue = ""
                }
            }

            let isAutoPaused = SettingsManager.shared.pauseWhenInvisible && wallpaperManager.isPausedInternally && !isCurrentlyPaused
            if let indicator = statusIndicator {
                if isCurrentlyPaused {
                    indicator.layer?.backgroundColor = resolvedCGColor(.systemYellow)
                    statusLabel.stringValue = "ui.status".localized("ui.pausedManual".localized)
                    statusLabel.textColor = Theme.textPrimary
                    if previewOwnsPlayer { previewPlayer?.pause() }
                } else if isAutoPaused {
                    indicator.layer?.backgroundColor = resolvedCGColor(.systemOrange)
                    statusLabel.stringValue = "ui.status".localized("ui.pausedAuto".localized)
                    statusLabel.textColor = Theme.textPrimary
                    if previewOwnsPlayer { previewPlayer?.pause() }
                } else {
                    indicator.layer?.backgroundColor = resolvedCGColor(.systemGreen)
                    statusLabel.stringValue = "ui.status".localized("ui.playing".localized)
                    statusLabel.textColor = Theme.textPrimary
                    if previewOwnsPlayer { previewPlayer?.play() }
                }
            }

            if window?.isVisible == true {
                showPreview(url: url, type: type)
            } else {
                releasePreviewResources()
            }
        } else {
            currentPreviewPath = nil
            currentPreviewFitMode = nil
            currentPreviewIsFolder = nil
            currentPreviewBrowserVisible = nil
            clearPreview()
            fileNameLabel.stringValue = "ui.noWallpaper".localized
            fileTypeLabel.stringValue = ""

            if let indicator = statusIndicator {
                indicator.layer?.backgroundColor = resolvedCGColor(Theme.textSecondary.withAlphaComponent(0.45))
            }
            statusLabel.stringValue = "ui.status".localized("ui.notSet".localized)
            statusLabel.textColor = Theme.textSecondary

            previewStageView.isHidden = true
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
        let browserVisible = isFolder && previewConfig.isFolderBrowserVisible

        if currentPreviewPath == url.path,
           currentPreviewFitMode == previewConfig.wallpaperFit,
           currentPreviewIsFolder == isFolder,
           currentPreviewBrowserVisible == browserVisible {
            if isFolder && browserVisible {
                applyPreviewLayout(isFolder: true, browserVisible: true)
                collectionView.reloadData()
            }
            return
        }
        
        currentPreviewPath = url.path
        currentPreviewFitMode = previewConfig.wallpaperFit
        currentPreviewIsFolder = isFolder
        currentPreviewBrowserVisible = browserVisible
        clearPreview()
        previewStageView.isHidden = false
        dropZone.isHidden = true

        applyPreviewLayout(isFolder: isFolder, browserVisible: browserVisible)
        if isFolder && browserVisible {
            collectionView.reloadData()
            collectionView.layoutSubtreeIfNeeded()
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        switch type {
        case .image:
            setPreviewLoading(true)
            let targetSize = previewDisplayFrame.size
            let fallbackSize = NSSize(width: Layout.contentWidth, height: 340)
            let requestedSize = (targetSize.width > 0 && targetSize.height > 0) ? targetSize : fallbackSize

            ThumbnailProvider.shared.requestThumbnail(for: url, size: requestedSize) { [weak self] image in
                guard let self, self.currentPreviewPath == url.path else { return }
                self.setPreviewLoading(false)
                guard let image else { return }
                self.previewImageView.image = image
                self.layoutPreviewImage(for: image.size, fitMode: previewConfig.wallpaperFit)
                self.previewImageView.isHidden = false
                self.previewPlayerLayer.isHidden = true
            }
        case .gif:
            setPreviewLoading(false)
            guard let image = NSImage(contentsOf: url) else { return }
            previewImageView.image = image
            previewImageView.animates = true
            layoutPreviewImage(for: image.size, fitMode: previewConfig.wallpaperFit)
            previewImageView.isHidden = false
            previewPlayerLayer.isHidden = true
        case .video:
            setPreviewLoading(false)
            if let selectedScreen,
               let wallpaperPlayer = wallpaperManager.videoPlayer(for: selectedScreen, mediaURL: url) {
                previewPlayer = wallpaperPlayer
                previewOwnsPlayer = false
            } else {
                previewPlayer = AVPlayer(url: url)
                previewPlayer?.isMuted = true
                previewOwnsPlayer = true
            }
            previewPlayerLayer.player = previewPlayer
            previewPlayerLayer.videoGravity = previewConfig.wallpaperFit.avLayerVideoGravity
            previewPlayerLayer.frame = previewStageView.bounds
            previewPlayerLayer.isHidden = false
            previewImageView.isHidden = true
            if previewOwnsPlayer {
                previewPlayer?.play()
                previewEndObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: previewPlayer?.currentItem,
                    queue: .main
                ) { [weak self] _ in
                    self?.previewPlayer?.seek(to: .zero)
                    self?.previewPlayer?.play()
                }
            }
        case .unsupported:
            setPreviewLoading(false)
            break
        }
    }

    private func clearPreview() {
        setPreviewLoading(false)
        if previewOwnsPlayer {
            previewPlayer?.pause()
        }
        if let observer = previewEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        previewEndObserver = nil
        previewPlayer = nil
        previewOwnsPlayer = false
        previewPlayerLayer.player = nil
        previewImageView.image = nil
        previewImageView.animates = false
        previewStageView.isHidden = false
        scrollView.isHidden = true
        previewBrowserChromeView.isHidden = true
    }

    private func releasePreviewResources() {
        currentPreviewPath = nil
        currentPreviewFitMode = nil
        currentPreviewIsFolder = nil
        currentPreviewBrowserVisible = nil
        clearPreview()
    }

    private func applyPreviewLayout(isFolder: Bool, browserVisible: Bool) {
        currentPreviewIsFolder = isFolder
        currentPreviewBrowserVisible = browserVisible
        previewDisplayFrame = previewContainer.bounds
        previewStageView.frame = previewDisplayFrame
        previewPlayerLayer.frame = previewStageView.bounds
        previewImageView.frame = previewStageView.bounds

        let shouldShowBrowser = isFolder && browserVisible
        previewBrowserChromeView.isHidden = !shouldShowBrowser
        scrollView.isHidden = !shouldShowBrowser
        if shouldShowBrowser {
            previewBrowserChromeView.frame = NSRect(x: 16, y: 16, width: previewContainer.bounds.width - 32, height: 96)
            scrollView.frame = NSRect(x: 8, y: 8, width: previewBrowserChromeView.bounds.width - 16, height: previewBrowserChromeView.bounds.height - 16)
        }
    }

    private func layoutPreviewImage(for imageSize: NSSize, fitMode: WallpaperFitMode) {
        let bounds = previewStageView.bounds
        guard imageSize.width > 0, imageSize.height > 0 else {
            previewImageView.frame = bounds
            return
        }

        switch fitMode {
        case .stretch:
            previewImageView.frame = bounds
        case .fit:
            previewImageView.frame = aspectRect(for: imageSize, in: bounds, fill: false)
        case .fill:
            previewImageView.frame = aspectRect(for: imageSize, in: bounds, fill: true)
        }
    }

    private func aspectRect(for imageSize: NSSize, in bounds: NSRect, fill: Bool) -> NSRect {
        let widthRatio = bounds.width / imageSize.width
        let heightRatio = bounds.height / imageSize.height
        let scale = fill ? max(widthRatio, heightRatio) : min(widthRatio, heightRatio)
        let fittedSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return NSRect(
            x: bounds.midX - (fittedSize.width / 2),
            y: bounds.midY - (fittedSize.height / 2),
            width: fittedSize.width,
            height: fittedSize.height
        )
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
        step2.addButton(withTitle: "onboarding.interval5".localized)
        step2.addButton(withTitle: "onboarding.interval15".localized)
        step2.addButton(withTitle: "onboarding.interval30".localized)
        let step2Result = step2.runModal()
        let minutes: Int
        if step2Result == .alertFirstButtonReturn {
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
                wallpaperManager.propagateSettingsToSyncGroup(fromScreenID: id)
                wallpaperManager.startRotationTimer()
            }
            if config.isFolderBrowserVisible {
                config.isFolderBrowserVisible = false
                SettingsManager.shared.setScreenConfig(config, for: id)
                wallpaperManager.propagateSettingsToSyncGroup(fromScreenID: id)
                currentPreviewBrowserVisible = false
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
        guard let item = collectionView.makeItem(withIdentifier: ThumbnailItem.identifier, for: indexPath) as? ThumbnailItem else {
            return NSCollectionViewItem()
        }
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

private extension WallpaperFitMode {
    var avLayerVideoGravity: AVLayerVideoGravity {
        switch self {
        case .fill:
            return .resizeAspectFill
        case .fit:
            return .resizeAspect
        case .stretch:
            return .resize
        }
    }
}
