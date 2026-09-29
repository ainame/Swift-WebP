// Scoped standard-library access preserves the collection lifetime and exclusive mutation.
// Swift 6.2/6.3 lack safety annotations on these methods; newer compilers diagnose
// their unsafe acknowledgements as redundant. Keep that compatibility detail here.

extension Span where Element == UInt8 {
    @safe
    func withWebPBytes<Result>(_ body: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
        #if compiler(<6.4)
        return unsafe try withUnsafeBytes(body)
        #else
        return try withUnsafeBytes(body)
        #endif
    }
}

extension Span where Element == UInt8 {
    @safe
    func withWebPPixels<Result>(_ body: (UnsafeBufferPointer<UInt8>) throws -> Result) rethrows -> Result {
        #if compiler(<6.4)
        return unsafe try withUnsafeBufferPointer(body)
        #else
        return try withUnsafeBufferPointer(body)
        #endif
    }
}

extension [UInt8] {
    @safe
    func withWebPPixels<Result>(_ body: (UnsafeBufferPointer<UInt8>) throws -> Result) rethrows -> Result {
        #if compiler(<6.4)
        return unsafe try withUnsafeBufferPointer(body)
        #else
        return try withUnsafeBufferPointer(body)
        #endif
    }
}

extension [UInt8] {
    @safe
    mutating func withWebPMutablePixels<Result>(_ body: (inout UnsafeMutableBufferPointer<UInt8>) throws -> Result) rethrows -> Result {
        #if compiler(<6.4)
        return unsafe try withUnsafeMutableBufferPointer(body)
        #else
        return try withUnsafeMutableBufferPointer(body)
        #endif
    }
}

@safe
func withWebPMutablePixels<Result>(
    _ pixels: inout MutableSpan<UInt8>,
    _ body: (UnsafeMutableBufferPointer<UInt8>) throws -> Result,
) rethrows -> Result {
    #if compiler(<6.4)
    return unsafe try pixels.withUnsafeMutableBufferPointer(body)
    #else
    return try pixels.withUnsafeMutableBufferPointer(body)
    #endif
}
