import SwiftUI

struct DecoderAlphaView: View {
    @State private var comparison: DecoderAlphaComparison?
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("We save a see-through white panel, like frosted glass, as a WebP image. Then we load it and place it on top of a photo. You should still see the ramen through the glass.")

                    if let comparison {
                        DecoderAlphaCard(
                            title: "❌ Before the fix",
                            caption: "The glass turns solid white. The ramen behind it is hidden.",
                            image: comparison.before
                        )
                        DecoderAlphaCard(
                            title: "✅ After the fix",
                            caption: "The glass stays see-through. You can see the ramen behind it.",
                            image: comparison.after
                        )
                    } else if let failure {
                        Text(failure).foregroundStyle(.red)
                    } else {
                        ProgressView("Encoding and decoding…")
                    }

                    DisclosureGroup("For developers: old code") {
                        codeText(DecoderAlphaSample.legacyCode)
                    }
                    DisclosureGroup("For developers: fixed API") {
                        codeText(DecoderAlphaSample.fixedCode)
                    }
                }
                .padding()
            }
            .navigationTitle("Decoder alpha")
            .task {
                do {
                    comparison = try DecoderAlphaSample.makeComparison()
                } catch {
                    failure = "Could not generate comparison: \(error)"
                }
            }
        }
    }

    private func codeText(_ code: String) -> some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
}

private struct DecoderAlphaCard: View {
    let title: String
    let caption: String
    let image: CGImage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Image("jiro")
                .resizable()
                .aspectRatio(DecoderAlphaSample.size.width / DecoderAlphaSample.size.height, contentMode: .fill)
                .overlay {
                    Image(decorative: image, scale: 1).resizable()
                }
                .clipShape(.rect(cornerRadius: 8))
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
