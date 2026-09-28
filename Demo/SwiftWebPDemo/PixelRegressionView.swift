import SwiftUI

struct PixelRegressionView: View {
    @State private var sample: PixelRegressionSample = .alpha
    @State private var comparison: PixelComparison?
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Example", selection: $sample) {
                        ForEach(PixelRegressionSample.allCases) { sample in
                            Text(sample.rawValue).tag(sample)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(sample.explanation)
                    Text("Both results use lossless WebP. The checkerboard shows transparency. Before and after use the same display size; tap an image to inspect it enlarged.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let comparison {
                        RegressionImageCard(title: "Original", image: comparison.original)
                        HStack(alignment: .top, spacing: 12) {
                            RegressionImageCard(
                                title: "Before", image: comparison.before.image,
                                detail: comparison.before.pixelDescription
                            )
                            RegressionImageCard(
                                title: "After", image: comparison.after.image,
                                detail: comparison.after.pixelDescription
                            )
                        }
                    } else if let failure {
                        Text(failure).foregroundStyle(.red)
                    } else {
                        ProgressView("Encoding and decoding…")
                    }

                    DisclosureGroup("Code that reproduces the problem") {
                        Text(sample.legacyCode)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    DisclosureGroup("Fixed platform API") {
                        Text("try WebPEncoder().encode(image, config: config)")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle("Pixel regressions")
            .task(id: sample) {
                comparison = nil
                failure = nil
                do {
                    comparison = try sample.makeComparison()
                } catch {
                    failure = "Could not generate comparison: \(error)"
                }
            }
        }
    }
}

private struct RegressionImageCard: View {
    let title: String
    let image: CGImage
    var detail: String? = nil
    @State private var enlarged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text("\(image.width) × \(image.height) px")
                .font(.caption.monospacedDigit())
            Button {
                enlarged = true
            } label: {
                preview
                    .aspectRatio(360.0 / 160.0, contentMode: .fit)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Enlarge \(title)")
            if let detail {
                Text(detail).font(.caption.monospaced())
            }
        }
        .sheet(isPresented: $enlarged) {
            NavigationStack {
                preview
                    .aspectRatio(360.0 / 160.0, contentMode: .fit)
                    .padding()
                    .navigationTitle(title)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { enlarged = false }
                        }
                    }
            }
        }
    }

    private var preview: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .interpolation(.none)
            .background {
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
            .clipShape(.rect(cornerRadius: 8))
    }
}
