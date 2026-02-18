import Foundation

public enum WebPError: Error, Sendable {
    case unexpectedPointerError // Something related pointer operation's error
    case unexpectedError(withMessage: String) // Something happened
    case decoderConfigInitializationFailed
    case unsupportedColorspaceMode
    case invalidWebPConfig
    case unsupportedDecodeFormat
    case outputBufferTooSmall(required: Int, actual: Int)
}
