import Cocoa
import AVFoundation
import ImageIO

final class ThumbnailProvider {
    static let shared = ThumbnailProvider()

    private let cache = NSCache<NSString, NSImage>()
    private let imageQueue = DispatchQueue(label: "com.sakura.wallpaper.thumbnail.image", qos: .userInitiated, attributes: .concurrent)

    private init() {
        cache.countLimit = 400
    }

    func requestThumbnail(for url: URL, size: NSSize, completion: @escaping (NSImage?) -> Void) {
        let key = cacheKey(for: url, size: size)
        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }

        switch MediaType.detect(url) {
        case .image:
            requestImageThumbnail(for: url, size: size, cacheKey: key, completion: completion)
        case .video:
            requestVideoThumbnail(for: url, size: size, cacheKey: key, completion: completion)
        case .unsupported:
            completion(nil)
        }
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    private func requestImageThumbnail(for url: URL, size: NSSize, cacheKey: NSString, completion: @escaping (NSImage?) -> Void) {
        let token = PerformanceMonitor.shared.begin("thumbnail.image")
        imageQueue.async { [weak self] in
            guard let self else { return }

            let maxPixelSize = max(Int(size.width), Int(size.height)) * 2
            let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                           kCGImageSourceCreateThumbnailWithTransform: true,
                           kCGImageSourceThumbnailMaxPixelSize: maxPixelSize] as CFDictionary

            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
                PerformanceMonitor.shared.end(token, extra: "result=failed path=\(url.lastPathComponent)")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let image = NSImage(cgImage: cgImage, size: size)
            self.cache.setObject(image, forKey: cacheKey)
            PerformanceMonitor.shared.end(token, extra: "result=ok path=\(url.lastPathComponent)")
            DispatchQueue.main.async { completion(image) }
        }
    }

    private func requestVideoThumbnail(for url: URL, size: NSSize, cacheKey: NSString, completion: @escaping (NSImage?) -> Void) {
        let token = PerformanceMonitor.shared.begin("thumbnail.video")
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: size.width * 2, height: size.height * 2)

        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: .zero)]) { [weak self] _, cgImage, _, result, _ in
            guard let self else { return }
            guard result == .succeeded, let cgImage else {
                PerformanceMonitor.shared.end(token, extra: "result=failed path=\(url.lastPathComponent)")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let image = NSImage(cgImage: cgImage, size: size)
            self.cache.setObject(image, forKey: cacheKey)
            PerformanceMonitor.shared.end(token, extra: "result=ok path=\(url.lastPathComponent)")
            DispatchQueue.main.async { completion(image) }
        }
    }

    private func cacheKey(for url: URL, size: NSSize) -> NSString {
        "\(url.path)#\(Int(size.width))x\(Int(size.height))" as NSString
    }
}
