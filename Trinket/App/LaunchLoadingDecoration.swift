import ImageIO
import SwiftUI
import TrinketDesignSystem

struct LaunchLoadingArtwork: Sendable {
    let body: CGImage
    let leftEye: CGImage
    let rightEye: CGImage
    let mouth: CGImage
    let goldLeaf: CGImage
    let greenLeaf: CGImage

    static let preparation = Task.detached(priority: .userInitiated) {
        guard let body = decode("slime-body"),
              let leftEye = decode("slime-eye-left"),
              let rightEye = decode("slime-eye-right"),
              let mouth = decode("slime-mouth"),
              let goldLeaf = decode("leaf-gold"),
              let greenLeaf = decode("leaf-green")
        else { return Self?.none }
        return Self(
            body: body,
            leftEye: leftEye,
            rightEye: rightEye,
            mouth: mouth,
            goldLeaf: goldLeaf,
            greenLeaf: greenLeaf,
        )
    }

    private static func decode(_ name: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "LaunchArtwork"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else {
            assertionFailure("Missing launch artwork: \(name)")
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    }
}

struct LaunchLoadingDecoration: View {
    let artwork: LaunchLoadingArtwork
    let elapsed: TimeInterval
    let reduceMotion: Bool

    private static let size: CGFloat = 50
    private static let height: CGFloat = 39
    private static let leafSeeds = [0.08, 0.30, 0.57, 0.81, 0.94]

    private var pose: HopPose {
        reduceMotion ? HopPose.settled : HopPose.at(elapsed)
    }

    var body: some View {
        GeometryReader { geometry in
            let pose = pose
            let position = geometry.size.width / 2 + pose.x

            ZStack(alignment: .topLeading) {
                if !reduceMotion {
                    leaves(width: geometry.size.width)
                }

                Ellipse()
                    .fill(TrinketDesign.Colors.Overlay.ink.opacity(0.12))
                    .frame(width: Self.size * 0.82, height: 3)
                    .blur(radius: 2)
                    .scaleEffect(max(0.48, 1 - pose.jump / 80))
                    .opacity(max(0.30, 1 - pose.jump / 65))
                    .position(x: position, y: 1.5)

                slime(pose: pose)
                    .scaleEffect(x: pose.widthScale, y: pose.heightScale, anchor: .bottom)
                    .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
                    .position(x: position, y: 3 - Self.height / 2 - pose.jump / 2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func slime(pose: HopPose) -> some View {
        ZStack {
            sprite(artwork.body, width: Self.size, height: Self.height)

            ZStack(alignment: .topLeading) {
                sprite(artwork.leftEye, width: 6, height: 8.97)
                    .scaleEffect(y: eyeOpening)
                    .position(x: 21.5, y: 18.135)
                sprite(artwork.rightEye, width: 5.25, height: 8.97)
                    .scaleEffect(y: eyeOpening)
                    .position(x: 34.625, y: 18.135)
                sprite(artwork.mouth, width: 6.5, height: 2.73)
                    .position(x: 29.75, y: 24.765)
            }
            .frame(width: Self.size, height: Self.height)
            .scaleEffect(
                x: 1 + (1 / pose.widthScale - 1) * 0.45,
                y: 1 + (1 / pose.heightScale - 1) * 0.35,
            )
            .offset(x: 1.75, y: -5.5)
        }
        .frame(width: Self.size, height: Self.height)
    }

    private var eyeOpening: Double {
        guard !reduceMotion else { return 1 }
        let blinkTime = elapsed > 2 ? 4.4 : 1.87
        let distance = abs(elapsed - blinkTime)
        guard distance < 0.085 else { return 1 }
        return 0.08 + 0.92 * HopPose.smooth(distance / 0.085)
    }

    private func leaves(width: CGFloat) -> some View {
        ForEach(Self.leafSeeds.indices, id: \.self) { index in
            let phase = (Self.leafSeeds[index] + elapsed * 0.40).truncatingRemainder(dividingBy: 1)
            let flutter = 0.55 + 0.45 * abs(cos(phase * .pi * 3 + Double(index)))
            let leafScale = index.isMultiple(of: 2) ? 1.0 : 0.72

            sprite(index.isMultiple(of: 2) ? artwork.goldLeaf : artwork.greenLeaf, width: 12, height: 16)
                .scaleEffect(x: flutter, y: 1)
                .rotationEffect(.degrees(phase * 360 + Double(index) * 63))
                .scaleEffect(leafScale)
                .opacity(max(0, sin(phase * .pi) * 0.85 * min(1, elapsed / 0.12)))
                .position(
                    x: -70 + phase * (width + 140),
                    y: -90 + Double(index) * 14 + sin(phase * .pi * 2 + Double(index)) * 13,
                )
        }
    }

    private func sprite(_ image: CGImage, width: CGFloat, height: CGFloat) -> some View {
        Image(decorative: image, scale: 3)
            .resizable()
            .frame(width: width, height: height)
    }
}

private struct HopPose {
    var x: Double
    var jump: Double
    var widthScale: Double
    var heightScale: Double
    var tilt: Double

    static let settled = Self(x: 54, jump: 0, widthScale: 1, heightScale: 1, tilt: 0)

    private static let keyframes: [(time: Double, pose: Self)] = [
        (0, Self(x: -54, jump: 0, widthScale: 1, heightScale: 1, tilt: -3)),
        (0.20, Self(x: -54, jump: 0, widthScale: 1.15, heightScale: 0.82, tilt: -6)),
        (0.32, Self(x: -45, jump: 15, widthScale: 0.91, heightScale: 1.10, tilt: 4)),
        (0.49, Self(x: -30, jump: 30, widthScale: 0.96, heightScale: 1.05, tilt: 6)),
        (0.73, Self(x: -6, jump: 0, widthScale: 1.22, heightScale: 0.76, tilt: -3)),
        (0.88, Self(x: -6, jump: 0, widthScale: 0.94, heightScale: 1.07, tilt: 0)),
        (1.03, Self(x: -6, jump: 0, widthScale: 1.14, heightScale: 0.83, tilt: -5)),
        (1.18, Self(x: 11, jump: 25, widthScale: 0.90, heightScale: 1.13, tilt: 4)),
        (1.36, Self(x: 33, jump: 31, widthScale: 0.96, heightScale: 1.04, tilt: 6)),
        (1.58, Self(x: 54, jump: 0, widthScale: 1.24, heightScale: 0.74, tilt: -3)),
        (1.74, Self(x: 54, jump: 0, widthScale: 0.93, heightScale: 1.08, tilt: 2)),
        (1.91, Self(x: 54, jump: 0, widthScale: 1.03, heightScale: 0.97, tilt: 0)),
        (2, settled),
    ]

    static func at(_ elapsed: Double) -> Self {
        guard elapsed < 2 else {
            let idle = sin((elapsed - 2) * .pi * 1.2) * 0.015
            return Self(x: 54, jump: 0, widthScale: 1 + idle, heightScale: 1 - idle, tilt: 0)
        }
        let index = keyframes.indices.dropLast().first { elapsed <= keyframes[$0 + 1].time } ?? 0
        let start = keyframes[index]
        let end = keyframes[index + 1]
        let progress = smooth(max(0, min(1, (elapsed - start.time) / (end.time - start.time))))
        return Self(
            x: start.pose.x + (end.pose.x - start.pose.x) * progress,
            jump: start.pose.jump + (end.pose.jump - start.pose.jump) * progress,
            widthScale: start.pose.widthScale + (end.pose.widthScale - start.pose.widthScale) * progress,
            heightScale: start.pose.heightScale + (end.pose.heightScale - start.pose.heightScale) * progress,
            tilt: start.pose.tilt + (end.pose.tilt - start.pose.tilt) * progress,
        )
    }

    static func smooth(_ progress: Double) -> Double {
        progress * progress * (3 - 2 * progress)
    }
}
