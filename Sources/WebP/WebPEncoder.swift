import Foundation
import CWebP

// This is customised error that describes the pattern of error causes.
// However, the error is unlikely to happen normally but it's still better to handle with throw-catch than fatal error.
public enum WebPEncoderError: Error {
    case invalidParameter
    case versionMismatched
}

// This is the mapped error codes that CWebP.WebPEncode returns
public enum WebPEncodeStatusCode: Int, Error {
    case ok = 0
    case outOfMemory           // memory error allocating objects
    case bitstreamOutOfMemory  // memory error while flushing bits
    case nullParameter         // a pointer parameter is NULL
    case invalidConfiguration  // configuration is invalid
    case badDimension          // picture has invalid width/height
    case partition0Overflow    // partition is bigger than 512k
    case partitionOverflow     // partition is bigger than 16M
    case badWrite              // error while flushing bytes
    case fileTooBig            // file is bigger than 4G
    case userAbort             // abort request by user
    case last                  // list terminator. always last.
}

public struct WebPEncoder {
    typealias WebPPictureImporter = (UnsafeMutablePointer<WebPPicture>, UnsafeMutablePointer<UInt8>, Int32) -> Int32

    public init() {
    }

    public func encode(RGB: UnsafeMutablePointer<UInt8>, config: WebPEncoderConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportRGB(picturePtr, data, stride)
        }
        return try encode(RGB, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }

    public func encode(RGBA: UnsafeMutablePointer<UInt8>, config: WebPEncoderConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportRGBA(picturePtr, data, stride)
        }
        return try encode(RGBA, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }

    public func encode(RGBX: UnsafeMutablePointer<UInt8>, config: WebPEncoderConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportRGBX(picturePtr, data, stride)
        }
        return try encode(RGBX, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }

    public func encode(BGR: UnsafeMutablePointer<UInt8>, config: WebPEncoderConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportBGR(picturePtr, data, stride)
        }
        return try encode(BGR, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }

    public func encode(BGRA: UnsafeMutablePointer<UInt8>, config: WebPEncoderConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportBGRA(picturePtr, data, stride)
        }
        return try encode(BGRA, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }

    public func encode(BGRX: UnsafeMutablePointer<UInt8>, config: WebPEncoderConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportBGRX(picturePtr, data, stride)
        }
        return try encode(BGRX, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }

    private func encode(_ dataPtr: UnsafeMutablePointer<UInt8>, importer: WebPPictureImporter,
                        config: WebPEncoderConfig, originWidth: Int, originHeight: Int, stride: Int,
                        resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        var config = config.rawValue
        if WebPValidateConfig(&config) == 0 {
            throw WebPEncoderError.invalidParameter
        }

        var picture = WebPPicture()
        if WebPPictureInit(&picture) == 0 {
            throw WebPEncoderError.invalidParameter
        }

        picture.use_argb = config.lossless == 0 ? 0 : 1
        picture.width = Int32(originWidth)
        picture.height = Int32(originHeight)

        let ok = importer(&picture, dataPtr, Int32(stride))
        if ok == 0 {
            WebPPictureFree(&picture)
            throw WebPEncoderError.versionMismatched
        }

        if resizeHeight > 0 && resizeWidth > 0 {
            if (WebPPictureRescale(&picture, Int32(resizeWidth), Int32(resizeHeight)) == 0) {
                throw WebPEncodeStatusCode.outOfMemory
            }
        }

        var buffer = WebPMemoryWriter()
        WebPMemoryWriterInit(&buffer)
        let writeWebP: @convention(c) (UnsafePointer<UInt8>?, Int, UnsafePointer<WebPPicture>?) -> Int32 = { (data, size, picture) -> Int32 in
            return WebPMemoryWrite(data, size, picture)
        }
        picture.writer = writeWebP
        picture.custom_ptr = UnsafeMutableRawPointer(&buffer)

        if WebPEncode(&config, &picture) == 0 {
            WebPPictureFree(&picture)

            let error = WebPEncodeStatusCode(rawValue:  Int(picture.error_code.rawValue))!
            throw error
        }
        WebPPictureFree(&picture)

        return Data(bytesNoCopy: buffer.mem, count: buffer.size, deallocator: .free)
    }
}
