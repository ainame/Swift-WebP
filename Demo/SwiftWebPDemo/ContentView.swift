import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Pixel regressions", systemImage: "square.split.2x2") {
                PixelRegressionView()
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
