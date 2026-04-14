import Foundation

enum MediaType: Equatable {
    case video, image, unsupported

    static func detect(_ url: URL) -> MediaType {
        let ext = url.pathExtension.lowercased()
        if ["mp4", "mov", "gif", "m4v"].contains(ext) { return .video }
        if ["png", "jpg", "jpeg", "heic", "heif", "webp", "bmp", "tiff"].contains(ext) { return .image }
        return .unsupported
    }
}
