import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Animated WebP", systemImage: "play.rectangle") {
                AnimatedWebPView()
            }
            Tab("Pixel regressions", systemImage: "square.split.2x2") {
                PixelRegressionView()
            }
            Tab("Decoder alpha", systemImage: "circle.lefthalf.filled") {
                DecoderAlphaView()
            }
            Tab("Photo conversion", systemImage: "photo") {
                PhotoConversionView()
            }
        }
    }
}

#Preview {
    ContentView()
}
