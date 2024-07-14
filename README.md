# Swift-WebP

[![Build Status](https://travis-ci.org/ainame/Swift-WebP.svg?branch=travis-ci-release)](https://travis-ci.org/ainame/Swift-WebP)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

<!-- <a href="https://placehold.it/400?text=Screen+shot"><img width=200 height=200 src="https://placehold.it/400?text=Screen+shot" alt="Screenshot" /></a> -->

Swift Wrapper of libwebp

### Target

Swift-WebP aims to deal with image processing flexibly for WebP format in Swift unlike an image loading library; such as SDWebImage. So this library allows you to use many features libwebp has without hassles to use C API from Swift. And also you don't need to install libwebp by yourself if you install this via Carthage. This contains it inside the framework.


### Support Versions:

* libwebp: v1.2.0
* iOS Deployment Target: 13.0
* macOS Deployment Target: 11.0

#### Features

* [x] Support mutiplatform; iOS, macOS, and Linux (swift-docker)
* [x] Support SPM
* [x] [Advanced Encoder API](https://developers.google.com/speed/webp/docs/api#advanced_encoding_api) - WebPEncoder, WebPEncoderConfig
* [x] [Advanced Decoding API](https://developers.google.com/speed/webp/docs/api#advanced_decoding_api) - WebPDecoder, WebPDecoderOptions
* [x] Image inspection for WebP files  - WebPImageInspector

#### TODO

* [ ] Progressively encoding/decoding option
* [ ] Animated WebP


## Usage

#### Encoding

```swift
let image = UIImage(named: "demo")
let encoder = WebPEncoder()
let queue =  DispatchQueue(label: "me.ainam.webp")

// should encode in background
queue.async {
    let data = try! encoder.encode(image, config: .preset(.picture, quality: 95))
    // using webp binary data...
}
```

#### Decoding

```swift
let data: Data = loadWebPData()
let encoder = WebPDecoder()
let queue =  DispatchQueue(label: "me.ainam.webp")

// should decode in background
queue.async {
    var options = WebPDecoderOptions()
    options.scaledWidth = Int(originalWidth / 2)
    options.scaledHeight = Int(originalHeight / 2)
    let cgImage = try! decoder.decode(data, options: options)
    let webpImage = UIImage(cgImage: cgImage)

    DispatchQueue.main.async {
        self.imageView.image = webpImage
    }
}
```


## Example

Please check example projects

## Installation

Swift-WebP supports Swift Package Manager installation.

```
.package(url: "https://github.com/ainame/Swift-WebP.git", from: "0.5.0"),
```


## Author

ainame

## License

Swift-WebP is available under the MIT license. See the LICENSE file for more info.
