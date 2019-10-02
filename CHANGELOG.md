# Change Log

All notable changes to this project will be documented in this file.
`WebP` adheres to [Semantic Versioning](http://semver.org/).

## v0.1.1 (incomming)

### Enhanced

* Make WebPImageInspector publicly exposed
* Added `WebPDecoder.decode(toUIImage:, options:)` and `WebPDecoder.decode(toNSImage:, options:)`
* Bump embeded libwebp version to v1.0.3 (was v1.0.0)

## v0.1.0

### Changed

* Add WebPImageInspector internally

### Bug fix

* Fixed a memory issue in WebPDecoder+Platform.swift


## v0.0.10

### Changed

* Support swift-tools-version 5.0 to build with swift package manager

## v0.0.9

### Changed

* Support Xcode 10.2's build and Swift 5

## v0.0.8

### Bug fix

Fixed wrong file paths of WebPDecoder

## v0.0.7

### Changed

* Added WebPDecoder

### Removed

* WebPSimple.decode

## v0.0.7

### Changed

Support Xcode10 and Swift4.2 (nothing changed at all)

## v0.0.5

### Changed

* Update libwebp v0.60 -> v1.0.0
* Now WebPEncoder supports iOS platform

### Bug fix

* Handle use_argb flag properly

### Removed

* WebPSimple.encode
