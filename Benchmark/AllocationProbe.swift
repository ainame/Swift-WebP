import Darwin
import Foundation

// Diagnostic only: reports allocator capacity, not RSS or throughput. Run outside timed benchmarks.
for count in [1920 * 1080 * 4, 3840 * 2160 * 4] {
    var initialized = Data(count: count)
    let initializedAllocation = initialized.withUnsafeMutableBytes { bytes in
        malloc_size(bytes.baseAddress!)
    }
    let pointer = UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 1)
    pointer.initializeMemory(as: UInt8.self, repeating: 0, count: count)
    let transferred = Data(bytesNoCopy: pointer, count: count, deallocator: .custom { pointer, _ in
        pointer.deallocate()
    })
    let transferredAllocation = transferred.withUnsafeBytes { bytes in
        malloc_size(bytes.baseAddress!)
    }
    print("bytes=\(count) data_count_allocation=\(initializedAllocation) transferred_allocation=\(transferredAllocation)")
}
