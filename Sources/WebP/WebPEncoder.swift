import Foundation
import libwebp

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

public enum WebPEncodePixelFormat {
    case rgb
    case rgba
    case rgbx
    case bgr
    case bgra
    case bgrx
}

public struct WebPEncoder {
    typealias WebPPictureImporter = (UnsafeMutablePointer<WebPPicture>, UnsafeMutablePointer<UInt8>, Int32) -> Int32

    public init() {
    }

    public func encode(
        _ dataPtr: UnsafeMutablePointer<UInt8>,
        format: WebPEncodePixelFormat,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0
    ) throws -> Data {
        let importer = importer(for: format)
        return try encode(
            dataPtr,
            importer: importer,
            config: config,
            originWidth: originWidth,
            originHeight: originHeight,
            stride: stride,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight
        )
    }

    private func importer(for format: WebPEncodePixelFormat) -> WebPPictureImporter {
        switch format {
        case .rgb:
            return { picturePtr, data, stride in
                WebPPictureImportRGB(picturePtr, data, stride)
            }
        case .rgba:
            return { picturePtr, data, stride in
                WebPPictureImportRGBA(picturePtr, data, stride)
            }
        case .rgbx:
            return { picturePtr, data, stride in
                WebPPictureImportRGBX(picturePtr, data, stride)
            }
        case .bgr:
            return { picturePtr, data, stride in
                WebPPictureImportBGR(picturePtr, data, stride)
            }
        case .bgra:
            return { picturePtr, data, stride in
                WebPPictureImportBGRA(picturePtr, data, stride)
            }
        case .bgrx:
            return { picturePtr, data, stride in
                WebPPictureImportBGRX(picturePtr, data, stride)
            }
        }
    }

    private func encode(
        _ dataPtr: UnsafeMutablePointer<UInt8>,
        importer: WebPPictureImporter,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0
    ) throws -> Data {
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
        
        try withUnsafeMutableBytes(of: &buffer) { ptr in
            picture.custom_ptr = ptr.baseAddress

            if WebPEncode(&config, &picture) == 0 {
                WebPPictureFree(&picture)

                let error = WebPEncodeStatusCode(rawValue:  Int(picture.error_code.rawValue))!
                throw error
            }
        }

        WebPPictureFree(&picture)

        return Data(bytesNoCopy: buffer.mem, count: buffer.size, deallocator: .free)
    }
}
