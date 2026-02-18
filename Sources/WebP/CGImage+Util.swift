import Foundation

#if canImport(CoreGraphics)
import CoreGraphics

extension CGImage {
    func getBaseAddress() throws -> UnsafeMutablePointer<UInt8> {
        guard let dataProvider,
              let data = dataProvider.data
        else {
            throw WebPError.unexpectedPointerError
        }
        guard let dataPtr = CFDataGetBytePtr(data) else {
            throw WebPError.unexpectedPointerError
        }
        return UnsafeMutablePointer(mutating: dataPtr)
    }
}
#endif
