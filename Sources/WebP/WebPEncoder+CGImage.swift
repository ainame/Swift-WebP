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
    ///   Use `encode(normalizing:config:resizeWidth:resizeHeight:)` for these images.
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

    /// Encodes a CGImage of any bitmap layout, converting its pixels only when libwebp cannot read them.
    /// 8-bit straight-alpha or opaque layouts in sRGB-compatible color spaces, such as decoded PNGs and
    /// JPEGs, are encoded from the backing bytes without a copy. Other layouts, such as premultiplied,
    /// BGRA, or 16-bit images from drawing or screen capture, are redrawn into a temporary straight-alpha
    /// RGBA buffer first. Masks applied with `masking(_:)` are ignored for directly encoded layouts.
    ///
    /// Memory: the redraw path costs more than encoding backing bytes directly.
    /// - It allocates `width * height * 4` bytes for the straight-alpha buffer on top of the source
    ///   image and libwebp's own picture: about 32 MiB for 3840 × 2160, up to about 1 GiB at
    ///   libwebp's 16383 × 16383 limit. The buffer lives until encoding finishes.
    /// - Core Graphics may add its own temporary copy while drawing some layouts. Encoding a
    ///   3840 × 2160 premultiplied BGRA image measured about 63 MiB more peak memory than the raw
    ///   path, versus about 32 MiB for premultiplied RGBA.
    /// - The buffer is a Swift array, so if the allocation cannot be satisfied the process traps
    ///   instead of this method throwing. Check dimensions up front if very large images are possible.
    func encode(
        normalizing cgImage: CGImage,
        config: WebPEncoderConfig,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0
    ) throws -> Data {
        if let encoded = try cgImage.withWebPStraightPixels({ bytes, format in
            try encode(
                bytes, format: format, config: config,
                originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.bytesPerRow,
                resizeWidth: resizeWidth, resizeHeight: resizeHeight
            )
        }) {
            return encoded
        }
        return try encode(
            cgImage.webPStraightRGBA(), format: .rgba, config: config,
            originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.width * 4,
            resizeWidth: resizeWidth, resizeHeight: resizeHeight
        )
    }
}

#endif
