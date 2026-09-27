#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An uninitialized byte allocation kept private until libwebp successfully fills it.
@safe
struct WebPDecodedStorage: ~Copyable {
    private var pointer: UnsafeMutableRawPointer?
    private let byteCount: Int

    init(byteCount: Int) {
        precondition(byteCount > 0)
        self.byteCount = byteCount
        unsafe pointer = .allocate(byteCount: byteCount, alignment: MemoryLayout<UInt8>.alignment)
        unsafe pointer!.bindMemory(to: UInt8.self, capacity: byteCount)
    }

    /// Valid only while this owner is alive; initially uninitialized and intended for C output.
    var buffer: UnsafeMutableBufferPointer<UInt8> {
        unsafe UnsafeMutableBufferPointer(start: pointer!.assumingMemoryBound(to: UInt8.self), count: byteCount)
    }

    deinit {
        unsafe pointer?.deallocate()
    }

    /// Requires every byte to have been initialized by a successful complete decode.
    @unsafe
    consuming func takeData() -> Data {
        let allocation = unsafe pointer!
        unsafe pointer = nil
        return unsafe Data(bytesNoCopy: allocation, count: byteCount, deallocator: .custom { pointer, _ in
            unsafe pointer.deallocate()
        })
    }
}
