import Foundation
import libwebp

/// Owns the C allocation until it is freed or transferred to Foundation.
/// Never copy a WebPMemoryWriter that owns memory into another owner.
struct WebPMemoryWriterOwner: ~Copyable {
    var rawValue = WebPMemoryWriter()

    init() {
        WebPMemoryWriterInit(&rawValue)
    }

    deinit {
        var writer = rawValue
        WebPMemoryWriterClear(&writer)
    }

    consuming func takeData() -> Data {
        guard let pointer = rawValue.mem else { return Data() }
        let size = rawValue.size
        // Disarm cleanup before Foundation takes responsibility for the allocation.
        rawValue.mem = nil
        rawValue.size = 0
        rawValue.max_size = 0
        return Data(bytesNoCopy: pointer, count: size, deallocator: .custom { pointer, _ in
            WebPFree(pointer)
        })
    }
}
