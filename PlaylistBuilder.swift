import Foundation

enum PlaylistBuilder {
    static func collectMediaFiles(in folderURL: URL, includeSubfolders: Bool) throws -> [URL] {
        let manager = FileManager.default
        if includeSubfolders {
            let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isHiddenKey]
            guard let enumerator = manager.enumerator(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
                return []
            }
            var files: [URL] = []
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: Set(keys))
                if values.isDirectory == true { continue }
                if values.isHidden == true { continue }
                if MediaType.detect(fileURL) != .unsupported {
                    files.append(fileURL)
                }
            }
            return files.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
        }

        let files = try manager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        return files
            .filter { MediaType.detect($0) != .unsupported }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func nextIndex(currentIndex: Int, itemCount: Int, shuffle: Bool, randomIndex: (() -> Int)? = nil) -> Int {
        guard itemCount > 0 else { return 0 }
        if shuffle {
            if itemCount == 1 { return 0 }
            let candidate = randomIndex?() ?? Int.random(in: 0..<itemCount)
            if candidate == currentIndex {
                return (candidate + 1) % itemCount
            }
            return candidate
        }
        return (currentIndex + 1) % itemCount
    }
}
