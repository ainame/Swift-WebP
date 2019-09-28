import Foundation
import WebP
import XCTest

class WebPImageInspectorTests: XCTestCase {
    enum WebPImageInspectorTestError: Error {
        case cantReadTestData(String)
    }

    func testInspectWebPImageHeightAndWidth() throws {
        let path = ResourceAccessHelper.getExamplImagePath(of: "jiro.webp")
        guard let data = FileManager.default.contents(atPath: path) else {
            throw WebPImageInspectorTestError.cantReadTestData(path)
        }
        let feature = try WebPImageInspector.inspect(data)
        XCTAssert(feature.width > 0)
        XCTAssert(feature.height > 0)
        XCTAssertFalse(feature.hasAlpha)
        XCTAssertFalse(feature.hasAnimation)
    }

    func testInspectingJpegImageThrowsError() throws {
        let path = ResourceAccessHelper.getExamplImagePath(of: "jiro.jpg")
        guard let data = FileManager.default.contents(atPath: path) else {
            throw WebPImageInspectorTestError.cantReadTestData(path)
        }
        XCTAssertThrowsError(try WebPImageInspector.inspect(data)) { _error in
            if let error = _error as? WebPError,
                case .unexpectedError(let message) = error {
                XCTAssert(true)
            } else {
                XCTFail()
            }
        }
    }

}
