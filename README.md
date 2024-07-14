# Swift-WebP

Swift-WebP provides libwebp APIs in Swift manner for both encoding and decoding. 

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

Please check example project

## Installation

Swift-WebP supports Swift Package Manager installation.

```
.package(url: "https://github.com/ainame/Swift-WebP.git", from: "0.5.0"),
```


## Author

ainame

## License

Swift-WebP is available under the MIT license. See the LICENSE file for more info.
