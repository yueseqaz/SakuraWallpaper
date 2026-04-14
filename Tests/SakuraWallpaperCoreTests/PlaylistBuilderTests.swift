import XCTest
@testable import SakuraWallpaperCore

final class PlaylistBuilderTests: XCTestCase {
    func testNextIndexSequentialWrapsAround() {
        XCTAssertEqual(PlaylistBuilder.nextIndex(currentIndex: 0, itemCount: 3, shuffle: false), 1)
        XCTAssertEqual(PlaylistBuilder.nextIndex(currentIndex: 2, itemCount: 3, shuffle: false), 0)
    }

    func testNextIndexShuffleAvoidsImmediateRepeat() {
        let next = PlaylistBuilder.nextIndex(currentIndex: 1, itemCount: 3, shuffle: true, randomIndex: { 1 })
        XCTAssertEqual(next, 2)
    }

    func testCollectMediaFilesHonorsIncludeSubfolders() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SakuraWallpaperPlaylistTests-\(UUID().uuidString)", isDirectory: true)
        let nested = root.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let topFile = root.appendingPathComponent("a.jpg")
        let nestedFile = nested.appendingPathComponent("b.mp4")
        let txtFile = nested.appendingPathComponent("ignore.txt")
        FileManager.default.createFile(atPath: topFile.path, contents: Data())
        FileManager.default.createFile(atPath: nestedFile.path, contents: Data())
        FileManager.default.createFile(atPath: txtFile.path, contents: Data())

        let nonRecursive = try PlaylistBuilder.collectMediaFiles(in: root, includeSubfolders: false)
        let recursive = try PlaylistBuilder.collectMediaFiles(in: root, includeSubfolders: true)

        XCTAssertEqual(nonRecursive.count, 1)
        XCTAssertEqual(recursive.count, 2)
    }
}
