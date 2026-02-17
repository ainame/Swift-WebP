import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

internal struct WebPMemoryOwner: ~Copyable {
    private var pointer: UnsafeMutablePointer<UInt8>?
    private var count: Int

    init(pointer: UnsafeMutablePointer<UInt8>?, count: Int) {
        self.pointer = pointer
        self.count = count
    }

    deinit {
        if let pointer {
            free(pointer)
        }
    }

    borrowing func withSpan<T>(_ body: (Span<UInt8>) throws -> T) rethrows -> T? {
        guard let pointer else {
            return nil
        }
        return try body(Span(_unsafeStart: pointer, count: count))
    }

    consuming func takeData() -> Data {
        guard let pointer else {
            return Data()
        }

        let count = self.count
        self.pointer = nil
        self.count = 0
        return Data(bytesNoCopy: pointer, count: count, deallocator: .free)
    }
}
