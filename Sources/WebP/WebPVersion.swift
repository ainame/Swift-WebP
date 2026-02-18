import Foundation
import libwebp

public struct WebPVersion: Equatable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    init(rawValue: Int32) {
        let value = UInt32(bitPattern: rawValue)
        major = Int((value >> 16) & 0xFF)
        minor = Int((value >> 8) & 0xFF)
        patch = Int(value & 0xFF)
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}

public extension WebPEncoder {
    static var libwebpVersion: WebPVersion {
        WebPVersion(rawValue: WebPGetEncoderVersion())
    }
}

public extension WebPDecoder {
    static var libwebpVersion: WebPVersion {
        WebPVersion(rawValue: WebPGetDecoderVersion())
    }
}
