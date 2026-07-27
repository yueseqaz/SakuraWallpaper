import Cocoa

final class AboutWindowController: NSWindowController {
    private let websiteURL = URL(string: "https://github.com/yueseqaz/SakuraWallpaper")!

    private var appVersionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.2"
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)

        window.title = "about.title".localized
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()

        switch SettingsManager.shared.appearanceMode {
        case .system:
            window.appearance = nil
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        }

        setupUI()
    }

    private func setupUI() {
        guard let window else { return }

        let contentView = NSVisualEffectView()
        contentView.material = .windowBackground
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        window.contentView = contentView

        let hero = NSVisualEffectView()
        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.material = .underWindowBackground
        hero.blendingMode = .withinWindow
        hero.state = .active
        contentView.addSubview(hero)

        let iconView = NSImageView(image: NSApp.applicationIconImage)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 18
        iconView.layer?.masksToBounds = true
        hero.addSubview(iconView)

        let appName = makeLabel(
            "app.name".localized,
            font: .systemFont(ofSize: 27, weight: .semibold),
            color: .labelColor
        )
        hero.addSubview(appName)

        let version = makeLabel(
            "about.version".localized(appVersionText),
            font: .monospacedSystemFont(ofSize: 11, weight: .medium),
            color: .secondaryLabelColor
        )
        hero.addSubview(version)

        let description = makeLabel(
            "about.description".localized,
            font: .systemFont(ofSize: 13, weight: .regular),
            color: .secondaryLabelColor
        )
        description.maximumNumberOfLines = 2
        hero.addSubview(description)

        let accent = NSView()
        accent.translatesAutoresizingMaskIntoConstraints = false
        accent.wantsLayer = true
        accent.layer?.backgroundColor = NSColor.systemPink.cgColor
        accent.layer?.cornerRadius = 1.5
        hero.addSubview(accent)

        let sectionTitle = makeLabel(
            "about.capabilitiesTitle".localized,
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: .labelColor,
            alignment: .left
        )
        contentView.addSubview(sectionTitle)

        let featureGrid = makeFeatureGrid()
        contentView.addSubview(featureGrid)

        let formatsView = AboutFormatsView(
            title: "about.formatsTitle".localized,
            formats: "MP4  MOV  GIF  M4V   /   PNG  JPG  HEIC  WebP  BMP  TIFF"
        )
        formatsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(formatsView)

        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        contentView.addSubview(separator)

        let author = makeLabel(
            "about.footer".localized,
            font: .systemFont(ofSize: 11),
            color: .secondaryLabelColor,
            alignment: .left
        )
        contentView.addSubview(author)

        let websiteButton = NSButton(
            title: "about.openGitHub".localized,
            image: NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: nil) ?? NSImage(),
            target: self,
            action: #selector(openOfficialWebsite)
        )
        websiteButton.translatesAutoresizingMaskIntoConstraints = false
        websiteButton.bezelStyle = .rounded
        websiteButton.controlSize = .regular
        websiteButton.font = .systemFont(ofSize: 12, weight: .medium)
        websiteButton.imagePosition = .imageLeading
        websiteButton.imageHugsTitle = true
        contentView.addSubview(websiteButton)

        NSLayoutConstraint.activate([
            hero.topAnchor.constraint(equalTo: contentView.topAnchor),
            hero.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hero.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hero.heightAnchor.constraint(equalToConstant: 216),

            iconView.topAnchor.constraint(equalTo: hero.topAnchor, constant: 38),
            iconView.centerXAnchor.constraint(equalTo: hero.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 82),
            iconView.heightAnchor.constraint(equalToConstant: 82),

            appName.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            appName.centerXAnchor.constraint(equalTo: hero.centerXAnchor),

            version.topAnchor.constraint(equalTo: appName.bottomAnchor, constant: 3),
            version.centerXAnchor.constraint(equalTo: hero.centerXAnchor),

            description.topAnchor.constraint(equalTo: version.bottomAnchor, constant: 8),
            description.centerXAnchor.constraint(equalTo: hero.centerXAnchor),
            description.widthAnchor.constraint(lessThanOrEqualToConstant: 360),

            accent.topAnchor.constraint(equalTo: description.bottomAnchor, constant: 11),
            accent.centerXAnchor.constraint(equalTo: hero.centerXAnchor),
            accent.widthAnchor.constraint(equalToConstant: 42),
            accent.heightAnchor.constraint(equalToConstant: 3),

            sectionTitle.topAnchor.constraint(equalTo: hero.bottomAnchor, constant: 20),
            sectionTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            sectionTitle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),

            featureGrid.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 10),
            featureGrid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            featureGrid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            featureGrid.heightAnchor.constraint(equalToConstant: 132),

            formatsView.topAnchor.constraint(equalTo: featureGrid.bottomAnchor, constant: 14),
            formatsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            formatsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            formatsView.heightAnchor.constraint(equalToConstant: 58),

            separator.topAnchor.constraint(equalTo: formatsView.bottomAnchor, constant: 18),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),

            author.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            author.centerYAnchor.constraint(equalTo: websiteButton.centerYAnchor),

            websiteButton.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            websiteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            websiteButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 132),
            websiteButton.heightAnchor.constraint(equalToConstant: 30),
            websiteButton.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    private func makeFeatureGrid() -> NSStackView {
        let features = [
            AboutFeatureView(
                symbol: "rectangle.split.2x1",
                title: "about.feature.displays.title".localized,
                detail: "about.feature.displays.detail".localized
            ),
            AboutFeatureView(
                symbol: "arrow.triangle.2.circlepath",
                title: "about.feature.rotation.title".localized,
                detail: "about.feature.rotation.detail".localized
            ),
            AboutFeatureView(
                symbol: "desktopcomputer",
                title: "about.feature.sync.title".localized,
                detail: "about.feature.sync.detail".localized
            ),
            AboutFeatureView(
                symbol: "battery.75",
                title: "about.feature.battery.title".localized,
                detail: "about.feature.battery.detail".localized
            )
        ]

        let topRow = makeFeatureRow(Array(features[0...1]))
        let bottomRow = makeFeatureRow(Array(features[2...3]))
        let grid = NSStackView(views: [topRow, bottomRow])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.orientation = .vertical
        grid.spacing = 8
        grid.distribution = .fillEqually
        return grid
    }

    private func makeFeatureRow(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        return row
    }

    private func makeLabel(
        _ text: String,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment = .center
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = font
        label.textColor = color
        label.alignment = alignment
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    @objc private func openOfficialWebsite() {
        NSWorkspace.shared.open(websiteURL)
    }
}

private final class AboutFeatureView: NSView {
    init(symbol: String, title: String, detail: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        icon.contentTintColor = .systemPink
        addSubview(icon)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 10.5)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        addSubview(detailLabel)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 13),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3)
        ])

        updateColors()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.cornerRadius = 8
            layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72).cgColor
            layer?.borderWidth = 0.5
            layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.65).cgColor
        }
    }
}

private final class AboutFormatsView: NSView {
    init(title: String, formats: String) {
        super.init(frame: .zero)
        wantsLayer = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .labelColor
        addSubview(titleLabel)

        let formatsLabel = NSTextField(labelWithString: formats)
        formatsLabel.translatesAutoresizingMaskIntoConstraints = false
        formatsLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        formatsLabel.textColor = .secondaryLabelColor
        formatsLabel.lineBreakMode = .byTruncatingTail
        addSubview(formatsLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            formatsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            formatsLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            formatsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5)
        ])

        updateColors()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.cornerRadius = 8
            layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.52).cgColor
            layer?.borderWidth = 0.5
            layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        }
    }
}
