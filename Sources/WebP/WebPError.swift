import Foundation

public enum WebPError: Error {
    case unexpectedPointerError // Something related pointer operation's error
    case unexpectedError(withMessage: String) // Something happened
    case decoderConfigInitializationFailed
    case unsupportedColorspaceMode
    case invalidWebPConfig
    case unsupportedDecodeFormat
}
