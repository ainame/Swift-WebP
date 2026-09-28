import SwiftUI

struct DecoderAlphaView: View {
    @State private var comparison: DecoderAlphaComparison?
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("This WebP image is one gray square that is 50% see-through. On a white background it should look light gray.")
                    Text("Every pixel: RGBA \(DecoderAlphaSample.pixel.map(String.init).joined(separator: ", "))")
                        .font(.callout.monospaced())
                    Text("R, G, B = 128 is mid gray. A = 128 is about 50% opaque.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let comparison {
                        HStack(alignment: .top, spacing: 16) {
                            DecoderAlphaCard(
                                title: "❌ Before the fix",
                                caption: "Too bright. The square turns white and disappears.",
                                image: comparison.before
                            )
                            DecoderAlphaCard(
                                title: "✅ After the fix",
                                caption: "Light gray, as expected.",
                                image: comparison.after
                            )
                        }
                    } else if let failure {
                        Text(failure).foregroundStyle(.red)
                    } else {
                        ProgressView("Encoding and decoding…")
                    }

                    Text("The dashed line only marks where the square is drawn.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.white, in: .rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary)
                }
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
