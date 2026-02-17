import Foundation
import WebP
import XCTest

class WebPImageInspectorTests: XCTestCase {
    enum WebPImageInspectorTestError: Error {
        case cantReadTestData(String)
    }

    private func makeFixtureWebP() throws -> Data {
        var rgba = [UInt8](
            repeating: 255,
            count: 2 * 2 * 4
        )
        rgba[3] = 0
        let encoder = WebPEncoder()
        return try rgba.withUnsafeMutableBytes { rawPtr in
            guard let base = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPImageInspectorTestError.cantReadTestData("Can't create RGBA fixture")
            }
            return try encoder.encode(
                base,
                format: .rgba,
                config: .preset(.picture, quality: 90),
                originWidth: 2,
                originHeight: 2,
                stride: 8
            )
        }
    }

    func testInspectWebPImageHeightAndWidth() throws {
        let data = try makeFixtureWebP()
        let feature = try WebPImageInspector.inspect(data)
        XCTAssert(feature.width > 0)
        XCTAssert(feature.height > 0)
        XCTAssertTrue(feature.hasAlpha)
        XCTAssertFalse(feature.hasAnimation)
    }

    func testInspectingJpegImageThrowsError() throws {
        guard let path = Bundle.module.url(forResource: "jiro", withExtension: "jpg")?.path,
              let data = FileManager.default.contents(atPath: path) else {
            throw WebPImageInspectorTestError.cantReadTestData("jiro.jpg")
        }
        XCTAssertThrowsError(try WebPImageInspector.inspect(data)) { _error in
            if let error = _error as? WebPError,
                case .unexpectedError = error {
                XCTAssert(true)
            } else {
                XCTFail()
            }
        }
    }

}
