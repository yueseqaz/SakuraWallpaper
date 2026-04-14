import XCTest
@testable import SakuraWallpaperCore

final class MediaTypeTests: XCTestCase {
    func testDetectVideoFormats() {
        XCTAssertEqual(MediaType.detect(URL(fileURLWithPath: "/tmp/a.mp4")), .video)
        XCTAssertEqual(MediaType.detect(URL(fileURLWithPath: "/tmp/a.mov")), .video)
        XCTAssertEqual(MediaType.detect(URL(fileURLWithPath: "/tmp/a.gif")), .video)
    }

    func testDetectImageFormats() {
        XCTAssertEqual(MediaType.detect(URL(fileURLWithPath: "/tmp/a.jpg")), .image)
        XCTAssertEqual(MediaType.detect(URL(fileURLWithPath: "/tmp/a.heic")), .image)
        XCTAssertEqual(MediaType.detect(URL(fileURLWithPath: "/tmp/a.webp")), .image)
    }

    func testDetectUnsupportedFormat() {
        XCTAssertEqual(MediaType.detect(URL(fileURLWithPath: "/tmp/a.txt")), .unsupported)
    }
}
