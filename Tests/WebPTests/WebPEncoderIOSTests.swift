#if os(iOS)
import Foundation
import Testing
import UIKit
import WebP

struct WebPEncoderIOSTests {
    @Test
    func example() throws {
        let encoder = WebPEncoder()

        guard let path = Bundle.module.url(forResource: "jiro", withExtension: "jpg") else {
            throw WebPError.unexpectedError(withMessage: "Image couldn't be loaded from test resources")
        }
        guard let uiimage = UIImage(contentsOfFile: path.path) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't create UIImage from test file")
        }
        let data = try encoder.encode(uiimage, config: .preset(.photo, quality: 100))
        #expect(data.count > 0)

        let decoder = WebPDecoder()
        var options = WebPDecoderOptions()
        options.useScaling = true
        options.scaledWidth = Int(uiimage.size.width)
        options.scaledHeight = Int(uiimage.size.height)
        let decodedImage = try decoder.decodeCGImage(from: data, options: options)
        #expect(decodedImage.width == options.scaledWidth)
        #expect(decodedImage.height == options.scaledHeight)
    }
}
#endif
