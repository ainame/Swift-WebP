// Generates Demo/SwiftWebPDemo/bouncing-ball.webp, the animated sample in the Demo app.
//
//     swift Demo/Scripts/make-bouncing-ball.swift Demo/SwiftWebPDemo/bouncing-ball.webp
//
// Requires macOS and `img2webp` (brew install webp).
//
// Frames sample the ball at evenly spaced heights, so each frame's duration carries the
// physics: short near the ground where the ball is fast, long at the top where it hangs.
// Played with uniform durations, the same frames move at a constant, robotic speed.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let width = 240
let height = 300
let radius: CGFloat = 30
let groundY: CGFloat = 40 // Ball bottom at rest, from the bottom edge.
let apexHeight: CGFloat = 190
let period = 1.2 // Seconds for one bounce.
let levels = 8

/// Time at which the rising ball reaches `level / levels` of the apex height.
func riseTime(_ level: Int) -> Double {
    period / 2 * (1 - (1 - Double(level) / Double(levels)).squareRoot())
}

struct FrameState {
    var level: Int
    var start: Double
}

// Rise through levels 0...levels, then fall back through levels-1...1. Level 0 is the bounce.
var states = (0 ... levels).map { FrameState(level: $0, start: riseTime($0)) }
states += (1 ..< levels).reversed().map { FrameState(level: $0, start: period - riseTime($0)) }
let durations = states.indices.map { index in
    let end = index + 1 < states.count ? states[index + 1].start : period
    return Int(((end - states[index].start) * 1000).rounded())
}

func drawFrame(level: Int) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    )!
    let lift = apexHeight * CGFloat(level) / CGFloat(levels)
    let squash = level == 0
    let ballWidth = radius * 2 * (squash ? 1.3 : 1)
    let ballHeight = radius * 2 * (squash ? 0.75 : 1)
    let centerX = CGFloat(width) / 2

    // Semi-transparent shadow that fades and shrinks as the ball rises.
    let closeness = 1 - lift / apexHeight
    let shadowWidth = radius * 2 * (0.6 + 0.6 * closeness)
    context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.12 + 0.28 * closeness))
    context.fillEllipse(in: CGRect(x: centerX - shadowWidth / 2, y: groundY - 7, width: shadowWidth, height: 12))

    // Shaded ball.
    let ball = CGRect(x: centerX - ballWidth / 2, y: groundY + lift, width: ballWidth, height: ballHeight)
    context.saveGState()
    context.addEllipse(in: ball)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            CGColor(srgbRed: 1, green: 0.78, blue: 0.45, alpha: 1),
            CGColor(srgbRed: 0.96, green: 0.36, blue: 0.16, alpha: 1),
            CGColor(srgbRed: 0.62, green: 0.13, blue: 0.08, alpha: 1),
        ] as CFArray,
        locations: [0, 0.55, 1],
    )!
    let highlight = CGPoint(x: ball.midX - ballWidth * 0.18, y: ball.midY + ballHeight * 0.2)
    context.drawRadialGradient(
        gradient,
        startCenter: highlight,
        startRadius: 0,
        endCenter: CGPoint(x: ball.midX, y: ball.midY),
        endRadius: max(ballWidth, ballHeight) * 0.62,
        options: [.drawsAfterEndLocation],
    )
    context.restoreGState()
    return context.makeImage()!
}

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "bouncing-ball.webp")
let workDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("bouncing-ball-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: workDirectory) }

var arguments = ["-loop", "0"]
for (index, state) in states.enumerated() {
    let url = workDirectory.appendingPathComponent(String(format: "frame-%02d.png", index))
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, drawFrame(level: state.level), nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(url.path)") }
    arguments += ["-lossy", "-q", "85", "-d", String(durations[index]), url.path]
}
arguments += ["-o", output.path]

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["img2webp"] + arguments
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("img2webp failed") }
print("Wrote \(states.count) frames to \(output.path). Durations (ms): \(durations)")
