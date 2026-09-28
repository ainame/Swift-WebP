import SwiftUI

struct DecoderAlphaView: View {
    enum Backdrop: String, CaseIterable, Identifiable {
        case black = "Black"
        case checkerboard = "Checkerboard"
        case white = "White"

        var id: Self { self }
    }

    @State private var backdrop: Backdrop = .black
    @State private var comparison: DecoderAlphaComparison?
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Each band fades from alpha 0 on the left to 255 on the right. Before: straight-alpha bytes are drawn as if premultiplied, so translucent pixels are too bright and the fade disappears over black.")
                    Picker("Background", selection: $backdrop) {
                        ForEach(Backdrop.allCases) { backdrop in
                            Text(backdrop.rawValue).tag(backdrop)
                        }
                    }
                    .pickerStyle(.segmented)
                    if backdrop == .white {
                        Text("Over white, bright colors clip, so the bug is hard to see for pure red, green, and blue. Switch to black to see it clearly.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let comparison {
                        DecoderAlphaCard(
                            title: "Before", image: comparison.before.image, backdrop: backdrop,
                            overBlack: comparison.before.overBlack, expected: comparison.expectedOverBlack
                        )
                        DecoderAlphaCard(
                            title: "After", image: comparison.after.image, backdrop: backdrop,
                            overBlack: comparison.after.overBlack, expected: comparison.expectedOverBlack
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sample pixel: red band, alpha 128").font(.headline)
                            Text("Stored in WebP (straight): \(format(comparison.sourcePixel))")
                            Text("Expected over black: \(format(comparison.expectedOverBlack))")
                        }
                        .font(.caption.monospaced())
                    } else if let failure {
                        Text(failure).foregroundStyle(.red)
                    } else {
                        ProgressView("Encoding and decoding…")
                    }

                    DisclosureGroup("Code that reproduces the problem") {
                        codeText(DecoderAlphaSample.legacyCode)
                    }
                    DisclosureGroup("Fixed platform API") {
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

private func format(_ pixel: [UInt8]) -> String {
    "RGBA " + pixel.map(String.init).joined(separator: ", ")
}

private struct DecoderAlphaCard: View {
    let title: String
    let image: CGImage
    let backdrop: DecoderAlphaView.Backdrop
    let overBlack: [UInt8]
    let expected: [UInt8]

    private var matches: Bool {
        zip(overBlack, expected).allSatisfy { abs(Int($0) - Int($1)) <= 1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Label(matches ? "Correct" : "Too bright", systemImage: matches ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(matches ? .green : .red)
            }
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.none)
                .aspectRatio(CGFloat(image.width) / CGFloat(image.height), contentMode: .fit)
                .background { background }
                .clipShape(.rect(cornerRadius: 8))
            Text("Over black: \(format(overBlack))")
                .font(.caption.monospaced())
        }
    }

    @ViewBuilder
    private var background: some View {
        switch backdrop {
        case .black:
            Color.black
        case .white:
            Color.white
        case .checkerboard:
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                let tile: CGFloat = 12
                for row in 0 ..< Int(ceil(size.height / tile)) {
                    for column in 0 ..< Int(ceil(size.width / tile)) where (row + column).isMultiple(of: 2) {
                        context.fill(
                            Path(CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)),
                            with: .color(Color(white: 0.8))
                        )
                    }
                }
            }
        }
    }
}
