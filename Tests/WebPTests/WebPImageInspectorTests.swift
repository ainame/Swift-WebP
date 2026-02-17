import Foundation
import Testing
import WebP

struct WebPImageInspectorTests {
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

    @Test
    func inspectWebPImageHeightAndWidth() throws {
        let data = try makeFixtureWebP()
        let feature = try WebPImageInspector.inspect(data)
        #expect(feature.width > 0)
        #expect(feature.height > 0)
        #expect(feature.hasAlpha)
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
}
