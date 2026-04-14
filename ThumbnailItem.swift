import Cocoa

class ThumbnailItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("ThumbnailItem")
    
    private let thumbnailImageView = NSImageView()
    private var representedPath: String?
    
    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
        self.view.layer?.cornerRadius = 8
        self.view.layer?.masksToBounds = true
        
        thumbnailImageView.frame = self.view.bounds
        thumbnailImageView.autoresizingMask = [.width, .height]
        thumbnailImageView.imageScaling = .scaleProportionallyUpOrDown
        self.view.addSubview(thumbnailImageView)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedPath = nil
        thumbnailImageView.image = nil
    }
    
    func configure(with url: URL, isActive: Bool) {
        representedPath = url.path
        thumbnailImageView.image = nil
        
        if isActive {
            self.view.layer?.borderWidth = 3
            self.view.layer?.borderColor = NSColor.systemBlue.cgColor
        } else {
            self.view.layer?.borderWidth = 0
        }

        ThumbnailProvider.shared.requestThumbnail(for: url, size: NSSize(width: 80, height: 80)) { [weak self] image in
            guard let self, self.representedPath == url.path else { return }
            self.thumbnailImageView.image = image
        }
    }
}
