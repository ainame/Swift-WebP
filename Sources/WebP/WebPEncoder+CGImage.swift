#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

public extension WebPEncoder {
    /// Encodes the image's backing bytes as-is, without copying or converting them.
    /// `format` must describe the image's actual bitmap layout, and color channels must use
    /// straight (non-premultiplied) alpha. Check `bitmapInfo`, `alphaInfo`, and `bitsPerComponent`,
    /// or redraw the image into a matching layout first.
    ///
    /// Whether the default `.rgba` fits depends on where the image came from:
    /// - Decoded files: ImageIO keeps the file's layout. An 8-bit PNG with alpha decodes to
    ///   straight RGBA and an 8-bit JPEG to RGBX, so both work with `.rgba`. 16-bit or grayscale
    ///   files do not.
    /// - Drawn images: Core Graphics bitmap contexts only support premultiplied alpha at 8 bits
    ///   per component. Images from `CGContext.makeImage()`, `UIGraphicsImageRenderer`, `NSImage`
    ///   drawing, or screen capture (as in screenshot apps) are premultiplied and often BGRA or
    ///   16-bit. Encoding them as `.rgba` darkens translucent pixels and can swap red and blue.
    ///   Use the `NSImage`/`UIImage` encoders, which redraw into straight RGBA, for these images.
    func encode(
        _ cgImage: CGImage,
        format: WebPEncodePixelFormat = .rgba,
        config: WebPEncoderConfig,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0
    ) throws -> Data {
        try cgImage.withPixelBytes { bytes in
            try encode(
                bytes,
                format: format,
                config: config,
                originWidth: cgImage.width,
                originHeight: cgImage.height,
                stride: cgImage.bytesPerRow,
                resizeWidth: resizeWidth,
                resizeHeight: resizeHeight
            )
        }
    }
}

#endif
