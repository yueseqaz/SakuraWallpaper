import Cocoa

class AboutWindowController: NSWindowController {
    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
        return "V\(shortVersion)"
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
        window.title = "about.title".localized
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor.windowBackgroundColor
        setupUI()
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        
        let iconLabel = NSTextField(labelWithString: "🌸")
        iconLabel.font = NSFont.systemFont(ofSize: 64)
        iconLabel.alignment = .center
        iconLabel.frame = NSRect(x: 0, y: 290, width: 320, height: 80)
        contentView.addSubview(iconLabel)
        
        let appName = NSTextField(labelWithString: "app.name".localized)
        appName.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        appName.textColor = .labelColor
        appName.alignment = .center
        appName.frame = NSRect(x: 0, y: 260, width: 320, height: 28)
        contentView.addSubview(appName)
        
        let version = NSTextField(labelWithString: "about.version".localized(appVersionText))
        version.font = NSFont.systemFont(ofSize: 12)
        version.textColor = .secondaryLabelColor
        version.alignment = .center
        version.frame = NSRect(x: 0, y: 238, width: 320, height: 18)
        contentView.addSubview(version)
        
        let separator1 = NSView(frame: NSRect(x: 40, y: 220, width: 240, height: 1))
        separator1.wantsLayer = true
        separator1.layer?.backgroundColor = NSColor.separatorColor.cgColor
        contentView.addSubview(separator1)
        
        let descLabel = NSTextField(labelWithString: "about.description".localized)
        descLabel.font = NSFont.systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.frame = NSRect(x: 0, y: 185, width: 320, height: 36)
        contentView.addSubview(descLabel)
        
        let formatsTitle = NSTextField(labelWithString: "about.formatsTitle".localized)
        formatsTitle.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        formatsTitle.textColor = .labelColor
        formatsTitle.alignment = .center
        formatsTitle.frame = NSRect(x: 0, y: 158, width: 320, height: 16)
        contentView.addSubview(formatsTitle)
        
        let formats = NSTextField(labelWithString: "MP4 • MOV • GIF • M4V\nPNG • JPG • HEIC • WebP • BMP • TIFF")
        formats.font = NSFont.systemFont(ofSize: 11)
        formats.textColor = .secondaryLabelColor
        formats.alignment = .center
        formats.frame = NSRect(x: 0, y: 125, width: 320, height: 32)
        contentView.addSubview(formats)
        
        let featuresTitle = NSTextField(labelWithString: "about.featuresTitle".localized)
        featuresTitle.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        featuresTitle.textColor = .labelColor
        featuresTitle.alignment = .center
        featuresTitle.frame = NSRect(x: 0, y: 98, width: 320, height: 16)
        contentView.addSubview(featuresTitle)
        
        let features = NSTextField(labelWithString: "about.features".localized)
        features.font = NSFont.systemFont(ofSize: 11)
        features.textColor = .secondaryLabelColor
        features.alignment = .center
        features.frame = NSRect(x: 0, y: 48, width: 320, height: 52)
        contentView.addSubview(features)
        
        let separator2 = NSView(frame: NSRect(x: 40, y: 35, width: 240, height: 1))
        separator2.wantsLayer = true
        separator2.layer?.backgroundColor = NSColor.separatorColor.cgColor
        contentView.addSubview(separator2)
        
        let author = NSTextField(labelWithString: "ui.madeBy".localized("❤️"))
        author.font = NSFont.systemFont(ofSize: 11)
        author.textColor = .secondaryLabelColor
        author.alignment = .center
        author.frame = NSRect(x: 0, y: 12, width: 320, height: 16)
        contentView.addSubview(author)

        let websiteButton = NSButton(title: "github.com/yueseqaz/SakuraWallpaper", target: self, action: #selector(openOfficialWebsite))
        websiteButton.bezelStyle = .inline
        websiteButton.isBordered = false
        websiteButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        websiteButton.contentTintColor = .systemBlue
        websiteButton.frame = NSRect(x: 0, y: 0, width: 320, height: 16)
        contentView.addSubview(websiteButton)
    }

    @objc private func openOfficialWebsite() {
        guard let url = URL(string: "https://github.com/yueseqaz/SakuraWallpaper") else { return }
        NSWorkspace.shared.open(url)
    }
}
