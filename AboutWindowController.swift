import Cocoa

final class AboutWindowController: NSWindowController {
    private let websiteURL = URL(string: "https://github.com/yueseqaz/SakuraWallpaper")!

    private var appVersionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.3"
    }

    private var buildVersionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? appVersionText
    }

    private var systemVersionText: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private var architectureText: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 568, height: 386),
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

        let iconView = NSImageView(image: NSApp.applicationIconImage)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 23
        iconView.layer?.masksToBounds = true
        contentView.addSubview(iconView)

        let appName = makeLabel(
            "app.name".localized,
            font: .systemFont(ofSize: 26, weight: .semibold),
            color: .labelColor
        )
        contentView.addSubview(appName)

        let version = makeLabel(
            "about.versionAndBuild".localized(appVersionText, buildVersionText),
            font: .systemFont(ofSize: 16, weight: .regular),
            color: .labelColor
        )
        contentView.addSubview(version)

        let systemInfo = makeLabel(
            "about.systemInfo".localized(systemVersionText, architectureText),
            font: .systemFont(ofSize: 15, weight: .regular),
            color: .labelColor
        )
        contentView.addSubview(systemInfo)

        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        contentView.addSubview(separator)

        let author = makeLabel(
            "about.footer".localized,
            font: .systemFont(ofSize: 12, weight: .regular),
            color: .secondaryLabelColor
        )
        author.alignment = .left
        contentView.addSubview(author)

        let websiteButton = NSButton(
            title: "about.openGitHub".localized,
            image: NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: nil) ?? NSImage(),
            target: self,
            action: #selector(openOfficialWebsite)
        )
        websiteButton.translatesAutoresizingMaskIntoConstraints = false
        websiteButton.isBordered = false
        websiteButton.font = .systemFont(ofSize: 12, weight: .medium)
        websiteButton.contentTintColor = .linkColor
        websiteButton.imagePosition = .imageTrailing
        websiteButton.imageHugsTitle = true
        contentView.addSubview(websiteButton)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 76),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 108),
            iconView.heightAnchor.constraint(equalToConstant: 108),

            appName.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 18),
            appName.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            appName.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 32),
            appName.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -32),

            version.topAnchor.constraint(equalTo: appName.bottomAnchor, constant: 14),
            version.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            version.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 32),
            version.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -32),

            systemInfo.topAnchor.constraint(equalTo: version.bottomAnchor, constant: 18),
            systemInfo.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            systemInfo.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 32),
            systemInfo.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -32),

            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -58),

            author.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            author.centerYAnchor.constraint(equalTo: websiteButton.centerYAnchor),
            author.trailingAnchor.constraint(lessThanOrEqualTo: websiteButton.leadingAnchor, constant: -16),

            websiteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -27),
            websiteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15),
            websiteButton.heightAnchor.constraint(equalToConstant: 26)
        ])
    }

    private func makeLabel(
        _ text: String,
        font: NSFont,
        color: NSColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = font
        label.textColor = color
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    @objc private func openOfficialWebsite() {
        NSWorkspace.shared.open(websiteURL)
    }
}
