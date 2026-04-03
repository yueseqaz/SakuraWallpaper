import Cocoa
import AVFoundation

class ThumbnailItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("ThumbnailItem")
    
    private let thumbnailImageView = NSImageView()
    
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
    
    func configure(with url: URL) {
        thumbnailImageView.image = nil
        let type = MediaType.detect(url)
        if type == .image {
            DispatchQueue.global(qos: .userInitiated).async {
                if let image = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.thumbnailImageView.image = image
                    }
                }
            }
        } else if type == .video {
            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 200, height: 200)
                do {
                    let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                    let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    DispatchQueue.main.async {
                        self.thumbnailImageView.image = image
                    }
                } catch {
                    print("Failed to generate thumbnail for \(url.lastPathComponent): \(error)")
                }
            }
        }
    }
}
