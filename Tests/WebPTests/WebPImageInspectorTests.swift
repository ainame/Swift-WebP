import Foundation
import Testing
import WebP

struct WebPImageInspectorTests {
    enum WebPImageInspectorTestError: Error {
        case cantReadTestData(String)
    }

    @Test
    func inspectWebPImageHeightAndWidth() throws {
        let data = try TestFixtures.makeWebPFixture(width: 2, height: 2)
        let feature = try WebPImageInspector.inspect(data)
        #expect(feature.width > 0)
        #expect(feature.height > 0)
        #expect(!feature.hasAnimation)
    }

    @Test
    func inspectWebP_reportsExactDimensionsAndFormat() throws {
        let data = try TestFixtures.makeWebPFixture(width: 2, height: 2)
        let feature = try WebPImageInspector.inspect(data)
        #expect(feature.width == 2)
        #expect(feature.height == 2)
        #expect(feature.format != .undefined)
        #expect(!feature.hasAnimation)
    }

    @Test
    func inspectingJpegImageThrowsError() throws {
        guard let path = Bundle.module.url(forResource: "jiro", withExtension: "jpg")?.path,
              let data = FileManager.default.contents(atPath: path)
        else {
            throw WebPImageInspectorTestError.cantReadTestData("jiro.jpg")
        }

        var didThrowExpectedError = false
        do {
            _ = try WebPImageInspector.inspect(data)
        } catch let error as WebPError {
            if case .unexpectedError = error {
                didThrowExpectedError = true
            }
        }
        #expect(didThrowExpectedError)
    }

    @Test
    func inspect_randomDataThrowsUnexpectedError() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05])

        var didThrowExpectedError = false
        do {
            _ = try WebPImageInspector.inspect(data)
        } catch let error as WebPError {
            if case .unexpectedError = error {
                didThrowExpectedError = true
            }
        }
        #expect(didThrowExpectedError)
    }
}
