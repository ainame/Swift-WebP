# SwiftWebPDemo

Open `SwiftWebPDemo.xcodeproj` in Xcode and run the `SwiftWebPDemo` scheme on an iOS simulator. The project uses the adjacent Swift-WebP checkout as a local package, so it shows the code on your current branch.

The **Pixel regressions** tab generates small images in code, encodes them through lossless WebP, decodes the bitstreams, and shows the results beside the original. Choose one of three examples:

- **Translucent colors:** the old platform path feeds premultiplied RGBA bytes to libwebp. The red pixel changes from straight-alpha RGBA `255, 0, 0, 128` to `128, 0, 0, 128`.
- **Red / blue order:** the old macOS `NSImage` path treats BGRA bytes as RGBA, swapping red and blue. The iOS Demo reproduces that old macOS path with a BGRA image; the current `UIImage` API uses the same normalization helper as the fixed macOS API.
- **Retina resolution:** the old `UIImage` path draws a `360 × 160 px` image into a `180 × 80 px` bitmap because its point size is smaller than its pixel size. Fine stripes turn gray. The current API retains `360 × 160 px`.

The **Before** images use the old encoding logic reproduced in `PixelRegressionSample.swift`, not a static illustration. **After** calls the current `WebPEncoder.encode(_:config:)` platform API. Tap a preview to enlarge it or expand the code disclosures to see the relevant calls.

The **Decoder alpha** tab round-trips red, green, blue, and white bands whose alpha fades from 0 to 255 through lossless WebP. **Before** reproduces the old `decodeCGImage`, which decoded straight-alpha `.rgba` bytes but tagged the `CGImage` as premultiplied, so translucent pixels drew too bright. Over black, the fade disappears and half-transparent red composites to `255, 0, 0` instead of `128, 0, 0`. **After** calls the current `WebPDecoder.decodeUIImage(from:options:)`. Switch the background to compare; over white, pure primaries clip and hide the bug.

The **Photo conversion** tab keeps the previous Jiro example.
