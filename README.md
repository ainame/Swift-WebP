# Swift-WebP

[![CI Status](http://img.shields.io/travis/ainame/Swift-WebP.svg?style=flat)](https://travis-ci.org/ainame/Swift-WebP)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

<!-- <a href="https://placehold.it/400?text=Screen+shot"><img width=200 height=200 src="https://placehold.it/400?text=Screen+shot" alt="Screenshot" /></a> -->

Swift Wrapper of libwebp

### Target

Swift-WebP aims to deal with image processing flexibly for WebP format in Swift unlike an image loading library; such as SDWebImage. So this library allows you to use many features libwebp has without hassles to use C API from Swift. And also you don't need to install libwebp by yourself. This contains it inside the framework.


### Support Versions:

* libwebp: v1.0.0
* iOS Deployment Target: 8.0
* macOS Deployment Target: 10.11

#### Features

* [x] support macOS build
* [x] support iOS build
* [x] [Advanced Encoder API](https://developers.google.com/speed/webp/docs/api#advanced_encoding_api): WebPEncoder, WebPEncoderConfig
* [x] [Advanced Decoding API](https://developers.google.com/speed/webp/docs/api#advanced_decoding_api): WebPDecoder, WebPDecoderConfig

#### TODO

* [ ] Progressively encoding/decoding option
* [ ] Animated WebP
* [ ] support Linux build

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

This library won't support CocoaPods. It's difficult to create and maintain podspec files for static libraries. (But contribution for that is always welcome.)

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate WebP into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "ainame/Swift-WebP"
```

Run `carthage update --use-submodules` to build the framework and drag the built `WebP.framework** into your Xcode project.

**Don't forget to use `--use-submodules` flag!**


## Author

ainame

## License

Swift-WebP is available under the MIT license. See the LICENSE file for more info.
