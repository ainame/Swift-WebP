import SwiftUI
import WebP
import UIKit

struct ContentView: View {
    @State var converted: UIImage?
    
    var body: some View {
        VStack {
            Button {
                convertImage()
            } label: {
                Text("Convert")
            }
            .buttonStyle(.borderedProminent)
            
            VStack {
                VStack {
                    Text("Original Image")
                    
                    Image(.jiro)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 350)
                }
                .padding()
                
                VStack {
                    Text("Converted Image quality=10%")
                    
                    if let converted {
                        Image(uiImage: converted)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 350)
                    } else {
                        Color
                            .black
                            .opacity(0.2)
                            .frame(width: 350, height: 200)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .containerRelativeFrame([.horizontal, .vertical])
    }
    
    func convertImage() {
        let encoder = WebPEncoder()
        let decoder = WebPDecoder()
        let queue = DispatchQueue(label: "me.ainam.webp")
        let image = UIImage(named: "jiro")!

        queue.async {
            do {
                let data = try! encoder.encode(image, config: .preset(.picture, quality: 10))
                var options = WebPDecoderOptions()
                options.scaledWidth = Int(image.size.width)
                options.scaledHeight = Int(image.size.height)
                let webpImage = try decoder.decode(toUImage: data, options: options)
                
                DispatchQueue.main.async {
                    self.converted = webpImage
                }
            } catch let error {
                print(error)
            }
        }
    }
}

#Preview {
    ContentView()
}
