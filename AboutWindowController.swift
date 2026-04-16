import Cocoa

class AboutWindowController: NSWindowController {
    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
        return "V\(shortVersion)"
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
        window.title = "about.title".localized
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(calibratedRed: 0.93, green: 0.97, blue: 0.95, alpha: 1)
        setupUI()
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(calibratedRed: 0.93, green: 0.97, blue: 0.95, alpha: 1).cgColor

        let glow = NSView(frame: NSRect(x: -40, y: 360, width: 500, height: 220))
        glow.wantsLayer = true
        glow.layer?.backgroundColor = NSColor(calibratedRed: 0.83, green: 0.95, blue: 0.89, alpha: 0.55).cgColor
        glow.layer?.cornerRadius = 90
        glow.layer?.masksToBounds = true
        contentView.addSubview(glow)

        let card = NSView(frame: NSRect(x: 22, y: 28, width: 376, height: 438))
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.99, blue: 0.98, alpha: 0.97).cgColor
        card.layer?.cornerRadius = 24
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor(calibratedRed: 0.78, green: 0.89, blue: 0.84, alpha: 1).cgColor
        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOpacity = 0.10
        card.layer?.shadowRadius = 16
        card.layer?.shadowOffset = NSSize(width: 0, height: -4)
        contentView.addSubview(card)
        
        let iconLabel = NSTextField(labelWithString: "🌸")
        iconLabel.font = NSFont.systemFont(ofSize: 62)
        iconLabel.alignment = .center
        iconLabel.frame = NSRect(x: 0, y: 334, width: 376, height: 78)
        card.addSubview(iconLabel)
        
        let appName = NSTextField(labelWithString: "app.name".localized)
        appName.font = NSFont(name: "Avenir Next Demi Bold", size: 30) ?? NSFont.systemFont(ofSize: 30, weight: .bold)
        appName.textColor = NSColor(calibratedRed: 0.17, green: 0.28, blue: 0.24, alpha: 1)
        appName.alignment = .center
        appName.frame = NSRect(x: 0, y: 300, width: 376, height: 36)
        card.addSubview(appName)
        
        let version = NSTextField(labelWithString: "about.version".localized(appVersionText))
        version.font = NSFont(name: "Avenir Next Medium", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .medium)
        version.textColor = NSColor(calibratedRed: 0.37, green: 0.53, blue: 0.48, alpha: 1)
        version.alignment = .center
        version.frame = NSRect(x: 0, y: 278, width: 376, height: 20)
        card.addSubview(version)
        
        let separator1 = NSView(frame: NSRect(x: 28, y: 258, width: 320, height: 1))
        separator1.wantsLayer = true
        separator1.layer?.backgroundColor = NSColor(calibratedRed: 0.78, green: 0.89, blue: 0.84, alpha: 1).cgColor
        card.addSubview(separator1)
        
        let descLabel = NSTextField(labelWithString: "about.description".localized)
        descLabel.font = NSFont(name: "Avenir Next Medium", size: 13) ?? NSFont.systemFont(ofSize: 13)
        descLabel.textColor = NSColor(calibratedRed: 0.28, green: 0.40, blue: 0.36, alpha: 1)
        descLabel.alignment = .center
        descLabel.frame = NSRect(x: 0, y: 218, width: 376, height: 38)
        card.addSubview(descLabel)
        
        let formatsTitle = NSTextField(labelWithString: "about.formatsTitle".localized)
        formatsTitle.font = NSFont(name: "Avenir Next Demi Bold", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .semibold)
        formatsTitle.textColor = NSColor(calibratedRed: 0.17, green: 0.32, blue: 0.28, alpha: 1)
        formatsTitle.alignment = .center
        formatsTitle.frame = NSRect(x: 0, y: 188, width: 376, height: 16)
        card.addSubview(formatsTitle)
        
        let formats = NSTextField(labelWithString: "MP4 • MOV • GIF • M4V\nPNG • JPG • HEIC • WebP • BMP • TIFF")
        formats.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        formats.textColor = NSColor(calibratedRed: 0.34, green: 0.48, blue: 0.44, alpha: 1)
        formats.alignment = .center
        formats.frame = NSRect(x: 0, y: 146, width: 376, height: 36)
        card.addSubview(formats)
        
        let featuresTitle = NSTextField(labelWithString: "about.featuresTitle".localized)
        featuresTitle.font = NSFont(name: "Avenir Next Demi Bold", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .semibold)
        featuresTitle.textColor = NSColor(calibratedRed: 0.17, green: 0.32, blue: 0.28, alpha: 1)
        featuresTitle.alignment = .center
        featuresTitle.frame = NSRect(x: 0, y: 120, width: 376, height: 16)
        card.addSubview(featuresTitle)
        
        let features = NSTextField(labelWithString: "about.features".localized)
        features.font = NSFont(name: "Avenir Next Medium", size: 12) ?? NSFont.systemFont(ofSize: 12)
        features.textColor = NSColor(calibratedRed: 0.34, green: 0.48, blue: 0.44, alpha: 1)
        features.alignment = .center
        features.frame = NSRect(x: 0, y: 56, width: 376, height: 62)
        card.addSubview(features)
        
        let separator2 = NSView(frame: NSRect(x: 28, y: 44, width: 320, height: 1))
        separator2.wantsLayer = true
        separator2.layer?.backgroundColor = NSColor(calibratedRed: 0.78, green: 0.89, blue: 0.84, alpha: 1).cgColor
        card.addSubview(separator2)
        
        let author = NSTextField(labelWithString: "ui.madeBy".localized("❤️"))
        author.font = NSFont(name: "Avenir Next Medium", size: 11) ?? NSFont.systemFont(ofSize: 11)
        author.textColor = NSColor(calibratedRed: 0.37, green: 0.53, blue: 0.48, alpha: 1)
        author.alignment = .center
        author.frame = NSRect(x: 0, y: 18, width: 376, height: 18)
        card.addSubview(author)
    }
}
