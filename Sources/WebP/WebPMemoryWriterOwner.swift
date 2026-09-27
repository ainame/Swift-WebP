import Foundation
import libwebp

/// Owns the C allocation until it is freed or transferred to Foundation.
/// Never copy a WebPMemoryWriter that owns memory into another owner.
/// Safety invariant: this is the sole owner; C allocations are cleared or transferred exactly once.
@safe
struct WebPMemoryWriterOwner: ~Copyable {
    var rawValue = unsafe WebPMemoryWriter()

    init() {
        unsafe WebPMemoryWriterInit(&rawValue)
    }

    deinit {
        var writer = unsafe rawValue
        unsafe WebPMemoryWriterClear(&writer)
    }

    consuming func takeData() -> Data {
        guard let pointer = unsafe rawValue.mem else { return Data() }
        let size = unsafe rawValue.size
        // Disarm cleanup before Foundation takes responsibility for the allocation.
        unsafe rawValue.mem = nil
        unsafe rawValue.size = 0
        unsafe rawValue.max_size = 0
        return unsafe Data(bytesNoCopy: pointer, count: size, deallocator: .custom { pointer, _ in
            unsafe WebPFree(pointer)
        })
    }
}
