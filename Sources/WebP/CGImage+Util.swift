import Foundation

#if canImport(CoreGraphics)
import CoreGraphics

extension CGImage {
    func withPixelBytes<Result>(_ body: (borrowing Span<UInt8>) throws -> Result) throws -> Result {
        guard let data = dataProvider?.data, let pointer = unsafe CFDataGetBytePtr(data) else {
            throw WebPError.unexpectedPointerError
        }
        // Retain the actual CFData owner, not only the image/provider, through the entire borrow.
        return try withExtendedLifetime(data) {
            let buffer = unsafe UnsafeBufferPointer(start: pointer, count: CFDataGetLength(data))
            return unsafe try body(Span(_unsafeElements: buffer))
        }
    }
}
#endif
