import Foundation

/// An uninitialized byte allocation kept private until libwebp successfully fills it.
struct WebPDecodedStorage: ~Copyable {
    private var pointer: UnsafeMutableRawPointer?
    private let byteCount: Int

    init(byteCount: Int) {
        self.byteCount = byteCount
        pointer = .allocate(byteCount: byteCount, alignment: MemoryLayout<UInt8>.alignment)
        pointer!.bindMemory(to: UInt8.self, capacity: byteCount)
    }

    var buffer: UnsafeMutableBufferPointer<UInt8> {
        UnsafeMutableBufferPointer(start: pointer!.assumingMemoryBound(to: UInt8.self), count: byteCount)
    }

    deinit {
        pointer?.deallocate()
    }

    consuming func takeData() -> Data {
        let allocation = pointer!
        pointer = nil
        return Data(bytesNoCopy: allocation, count: byteCount, deallocator: .custom { pointer, _ in
            pointer.deallocate()
        })
    }
}
