# Swift-WebP

[![CI Status](http://img.shields.io/travis/ainame/Swift-WebP.svg?style=flat)](https://travis-ci.org/ainame/Swift-WebP)
<!-- [![Version](https://img.shields.io/cocoapods/v/WebP.svg?style=flat)](https://cocoapods.org/pods/WebP) -->
<!-- [![License](https://img.shields.io/cocoapods/l/WebP.svg?style=flat)](https://cocoapods.org/pods/WebP) -->
<!-- [![Platform](https://img.shields.io/cocoapods/p/WebP.svg?style=flat)](https://cocoapods.org/pods/WebP) -->
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

<!-- <a href="https://placehold.it/400?text=Screen+shot"><img width=200 height=200 src="https://placehold.it/400?text=Screen+shot" alt="Screenshot" /></a> -->

Swift Wrapper of libwebp

### Current project status

Currently, this is very experimental project. Please feedback me!
Support libwebp of v0.5.1 and implement following features.

* [x] support macOS build
* [x] support iOS build
* [x] [Advanced Encoder API](https://developers.google.com/speed/webp/docs/api#advanced_encoding_api): WebPEncoder, WebPEncoderConfig
* [x] [Simple Decoding API](https://developers.google.com/speed/webp/docs/api#simple_decoding_api): WebPSimple#decode(...)

#### TODO

will implement following features

* [ ] [Advanced Decoding API](https://developers.google.com/speed/webp/docs/api#advanced_decoding_api): WebPSimple#decode(...)
* [ ] support Linux

## Example

Please check example projects

## Requirements

No need the requirement about libwebp for yourself, this framework contains it.

## Installation

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

Run `carthage update` to build the framework and drag the built `WebP.framework` into your Xcode project.


## Author

ainame

## License

Swift-WebP is available under the MIT license. See the LICENSE file for more info.
