import Foundation

extension String {
    var localized: String {
        let language = SettingsManager.shared.language
        if language == "system" {
            return NSLocalizedString(self, comment: "")
        }
        
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        return bundle.localizedString(forKey: self, value: nil, table: nil)
    }
    
    func localized(_ args: CVarArg...) -> String {
        String(format: self.localized, arguments: args)
    }
}

enum WallpaperError: LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case playbackFailed
    case permissionDenied
    case screenNotFound
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "error.fileNotFound".localized
        case .unsupportedFormat: return "error.unsupportedFormat".localized
        case .playbackFailed: return "error.playbackFailed".localized
        case .permissionDenied: return "error.permissionDenied".localized
        case .screenNotFound: return "error.screenNotFound".localized
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound: return "error.fileNotFound.message".localized
        case .unsupportedFormat: return "error.unsupportedFormat.message".localized
        case .playbackFailed: return "error.playbackFailed.message".localized
        case .permissionDenied: return "error.permissionDenied.message".localized
        case .screenNotFound: return "error.screenNotFound.message".localized
        }
    }
}
