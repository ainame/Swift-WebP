# SwiftWebPDemo

Open `SwiftWebPDemo.xcodeproj` in Xcode and run the `SwiftWebPDemo` scheme on an iOS simulator. The project uses the adjacent Swift-WebP checkout as a local package, so it shows the code on your current branch.

The **Animated WebP** tab decodes the bundled `bouncing-ball.webp` with `WebPAnimatedDecoder` and plays it twice, side by side. The 16 frames are spaced evenly in height, so their durations carry the motion: about 40 ms near the ground and 212 ms at the top. **Frame durations** honors each frame's own duration and the ball slows at the top. **Uniform durations** gives every frame the average 75 ms, as `UIImage.animatedImage(with:duration:)` does, and the ball moves at a constant speed. A chart shows which frame is on screen over time. The frame strip below it shows every decoded canvas. The file stores most frames as small offset sub-frames, so each one is composited by the decoder. The checkerboard shows through transparent pixels, including the semi-transparent shadow. `Scripts/make-bouncing-ball.swift` regenerates the sample.

The **Pixel regressions** tab generates small images in code, encodes them through lossless WebP, decodes the bitstreams, and shows the results beside the original. Choose one of three examples:

- **Translucent colors:** the old platform path feeds premultiplied RGBA bytes to libwebp. The red pixel changes from straight-alpha RGBA `255, 0, 0, 128` to `128, 0, 0, 128`.
- **Red / blue order:** the old macOS `NSImage` path treats BGRA bytes as RGBA, swapping red and blue. The iOS Demo reproduces that old macOS path with a BGRA image; the current `UIImage` API uses the same normalization helper as the fixed macOS API.
- **Retina resolution:** the old `UIImage` path draws a `360 × 160 px` image into a `180 × 80 px` bitmap because its point size is smaller than its pixel size. Fine stripes turn gray. The current API retains `360 × 160 px`.

The **Before** images use the old encoding logic reproduced in `PixelRegressionSample.swift`, not a static illustration. **After** calls the current `WebPEncoder.encode(_:config:)` platform API. Tap a preview to enlarge it or expand the code disclosures to see the relevant calls.

The **Decoder alpha** tab encodes one mid-gray square at 50% opacity (straight RGBA `128, 128, 128, 128`) as lossless WebP and draws the decoded image on white. It should look light gray. **Before** reproduces the old `decodeCGImage`, which decoded straight-alpha `.rgba` bytes but tagged the `CGImage` as premultiplied: the square is drawn too bright, turns white, and disappears. **After** calls the current `WebPDecoder.decodeUIImage(from:options:)` and shows light gray.

The **Photo conversion** tab keeps the previous Jiro example.
