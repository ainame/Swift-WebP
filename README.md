# Swift-WebP

[![CI Status](http://img.shields.io/travis/ainame/Swift-WebP.svg?style=flat)](https://travis-ci.org/ainame/Swift-WebP)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

<!-- <a href="https://placehold.it/400?text=Screen+shot"><img width=200 height=200 src="https://placehold.it/400?text=Screen+shot" alt="Screenshot" /></a> -->

Swift Wrapper of libwebp

### Current project status

Currently, this is very experimental project. Please feedback me!

Support Versions:

* libwebp: v1.0.0
* iOS Deployment Target: 8.0
* macOS Deployment Target: 10.11

#### Features.

* [x] Support macOS build
* [x] Support iOS build
* [x] [Advanced Encoder API](https://developers.google.com/speed/webp/docs/api#advanced_encoding_api): WebPEncoder, WebPEncoderConfig
* [x] [Advanced Decoding API](https://developers.google.com/speed/webp/docs/api#advanced_decoding_api): WebPDecoder, WebPDecoderConfig

#### TODO

will implement following features

* [ ] Support Linux build
* [ ] Muxer/Demuxer
* [ ] Animated WebP
* [ ] Progressively encoding/decoding

## Usage

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

## Example

Please check example projects

## Requirements

No need the requirement about libwebp for yourself, this framework contains it.

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
