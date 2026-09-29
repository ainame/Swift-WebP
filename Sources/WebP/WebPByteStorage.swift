#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A byte allocation with a stable address, owned by Swift and freed exactly once.
/// Decoders use it for output that stays private until libwebp successfully fills it,
/// and for input that libwebp keeps referencing after the call that received it.
@safe
struct WebPByteStorage: ~Copyable {
    private var pointer: UnsafeMutableRawPointer?
    private let byteCount: Int

    /// Allocates uninitialized storage intended for C output.
    init(byteCount: Int) {
        precondition(byteCount > 0)
        self.byteCount = byteCount
        unsafe pointer = .allocate(byteCount: byteCount, alignment: MemoryLayout<UInt8>.alignment)
        unsafe pointer!.bindMemory(to: UInt8.self, capacity: byteCount)
    }

    /// Allocates storage initialized with a copy of `bytes`, which must not be empty.
    init(copying bytes: borrowing Span<UInt8>) {
        self.init(byteCount: bytes.count)
        let destination = unsafe UnsafeMutableRawBufferPointer(buffer)
        bytes.withWebPBytes { source in
            unsafe destination.copyMemory(from: source)
        }
    }

    /// Allocates storage initialized with a copy of `data`, which must not be empty.
    init(copying data: Data) {
        self.init(byteCount: data.count)
        let destination = unsafe UnsafeMutableRawBufferPointer(buffer)
        unsafe data.withUnsafeBytes { source in
            unsafe destination.copyMemory(from: source)
        }
    }

    /// Valid only while this owner is alive. Uninitialized unless created by `init(copying:)`.
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
        return unsafe Data(
            bytesNoCopy: allocation,
            count: byteCount,
            deallocator: .custom { pointer, _ in
                unsafe pointer.deallocate()
            },
        )
    }
}
