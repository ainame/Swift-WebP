import Charts
import SwiftUI
import WebP

struct AnimatedWebPView: View {
    @State private var playback: AnimatedWebPPlayback?
    @State private var failure: String?
    @State private var isPlaying = true
    /// Playback position when paused, or at the moment playback last resumed.
    @State private var pausedMilliseconds = 0
    @State private var resumedAt = Date.now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(
                        "A ball bounces in 16 frames. Frames are spaced evenly in height, so their durations carry the motion: about 40 ms near the ground and 212 ms at the top."
                    )

                    if let playback {
                        TimelineView(.animation(paused: !isPlaying)) { context in
                            let elapsed = elapsedMilliseconds(at: context.date)
                            let current = playback.frameIndex(atMilliseconds: elapsed)
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(alignment: .top, spacing: 16) {
                                    AnimatedFrameCard(
                                        title: "✅ Frame durations",
                                        caption: "Each frame's own duration. The ball slows at the top.",
                                        frame: playback.frames[current],
                                    )
                                    AnimatedFrameCard(
                                        title: "Uniform durations",
                                        caption:
                                            "Every frame \(playback.totalMilliseconds / playback.frames.count) ms, like UIImage.animatedImage. Constant speed.",
                                        frame: playback.frames[playback.uniformFrameIndex(atMilliseconds: elapsed)],
                                    )
                                }
                                controls(playback: playback, elapsed: elapsed)
                                FrameTimeline(playback: playback, elapsed: elapsed % max(playback.totalMilliseconds, 1))
                                FrameStrip(playback: playback, current: current) { index in
                                    isPlaying = false
                                    pausedMilliseconds = playback.frames[index].timing.startTimeMilliseconds
                                }
                            }
                        }
                        AnimationInfoGrid(playback: playback)
                    } else if let failure {
                        Text(failure).foregroundStyle(.red)
                    } else {
                        ProgressView("Decoding…")
                    }

                    Text("The checkerboard shows through transparent pixels. The shadow is semi-transparent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    DisclosureGroup("For developers: API used") {
                        Text(AnimatedWebPSample.code)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle("Animated WebP")
            .task {
                do {
                    playback = try AnimatedWebPSample.load()
                    resumedAt = .now
                } catch {
                    failure = "Could not decode animation: \(error)"
                }
            }
        }
    }

    private func elapsedMilliseconds(at date: Date) -> Int {
        guard isPlaying else { return pausedMilliseconds }
        return pausedMilliseconds + Int(date.timeIntervalSince(resumedAt) * 1000)
    }

    private func controls(playback: AnimatedWebPPlayback, elapsed: Int) -> some View {
        HStack {
            Button {
                if isPlaying {
                    pausedMilliseconds = elapsed % max(playback.totalMilliseconds, 1)
                } else {
                    resumedAt = .now
                }
                isPlaying.toggle()
            } label: {
                Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.bordered)
            Spacer()
            Text("\(elapsed % max(playback.totalMilliseconds, 1)) / \(playback.totalMilliseconds) ms")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

private struct AnimatedFrameCard: View {
    let title: String
    let caption: String
    let frame: AnimatedWebPPlayback.Frame

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Image(decorative: frame.image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .background(Checkerboard())
                .clipShape(.rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary)
                }
            Text("Frame \(frame.timing.index + 1)")
                .font(.callout.monospacedDigit())
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Which frame is on screen over one loop, for both timing modes.
private struct FrameTimeline: View {
    let playback: AnimatedWebPPlayback
    let elapsed: Int

    private struct Step: Identifiable {
        let mode: String
        let time: Int
        let frame: Int
        var id: String { "\(mode)-\(time)" }
    }

    private var steps: [Step] {
        let frames = playback.frames
        let uniform = playback.totalMilliseconds / max(frames.count, 1)
        // Uniform first, so the frame-duration line draws on top where the two share a step.
        let uniformSteps = frames.map { Step(mode: "Uniform", time: $0.timing.index * uniform, frame: $0.timing.index + 1) }
        let durationSteps = frames.map {
            Step(mode: "Frame durations", time: $0.timing.startTimeMilliseconds, frame: $0.timing.index + 1)
        }
        return uniformSteps + [Step(mode: "Uniform", time: playback.totalMilliseconds, frame: frames.count)]
            + durationSteps + [Step(mode: "Frame durations", time: playback.totalMilliseconds, frame: frames.count)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frame on screen").font(.headline)
            Chart {
                ForEach(steps) { step in
                    LineMark(x: .value("Time (ms)", step.time), y: .value("Frame", step.frame))
                        .foregroundStyle(by: .value("Timing", step.mode))
                        .interpolationMethod(.stepEnd)
                        .lineStyle(step.mode == "Uniform" ? StrokeStyle(lineWidth: 2, dash: [5, 3]) : StrokeStyle(lineWidth: 3))
                }
                RuleMark(x: .value("Now", elapsed))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
            }
            .chartForegroundStyleScale(["Frame durations": Color.green, "Uniform": Color.orange])
            .chartXScale(domain: 0 ... playback.totalMilliseconds)
            .chartYScale(domain: 1 ... playback.frames.count)
            .chartXAxisLabel("ms")
            .frame(height: 170)
            Text("The flat steps at frames 8 and 9 are the ball hanging at the top for 212 ms each.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FrameStrip: View {
    let playback: AnimatedWebPPlayback
    let current: Int
    let select: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frames").font(.headline)
            Text("Each frame is a full composited canvas. Tap one to pause on it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(playback.frames) { frame in
                            Button {
                                select(frame.timing.index)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(decorative: frame.image, scale: 1)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 72)
                                        .background(Checkerboard())
                                        .clipShape(.rect(cornerRadius: 4))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 4)
                                                .strokeBorder(frame.id == current ? Color.accentColor : .clear, lineWidth: 3)
                                        }
                                    Text("\(frame.timing.durationMilliseconds) ms")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(frame.id == current ? .primary : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .id(frame.id)
                        }
                    }
                }
                .onChange(of: current) { _, index in
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }
}

private struct AnimationInfoGrid: View {
    let playback: AnimatedWebPPlayback

    var body: some View {
        let info = playback.info
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            row("Canvas", "\(info.canvasWidth) × \(info.canvasHeight) px")
            row("Frames", "\(info.frameCount)")
            row("Loop", info.loopCount == 0 ? "Forever" : "\(info.loopCount) times")
            row("Length", "\(playback.totalMilliseconds.formatted()) ms")
            row("File", ByteCountFormatter.string(fromByteCount: Int64(playback.fileSize), countStyle: .file))
            row("Decode", playback.decodeTime.formatted(.units(allowed: [.milliseconds], fractionalPart: .show(length: 1))))
        }
        .font(.callout)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let side: CGFloat = 12
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            for row in 0 ..< Int((size.height / side).rounded(.up)) {
                for column in 0 ..< Int((size.width / side).rounded(.up)) where (row + column).isMultiple(of: 2) {
                    let square = CGRect(x: CGFloat(column) * side, y: CGFloat(row) * side, width: side, height: side)
                    context.fill(Path(square), with: .color(Color(white: 0.88)))
                }
            }
        }
    }
}
