import CoreGraphics
import Foundation
import SwiftUI
import TrinketDesignSystem

struct CardDissolveThresholdMask: View {
    let progress: CGFloat
    var edgeDepthWeight: CGFloat = 0.86
    var noiseWeight: CGFloat = 0.18
    var cellSize: Int = 1
    var thresholdMidpoint: CGFloat = 0.46
    var thresholdContrast: CGFloat = 100

    var body: some View {
        // CPU-baked alpha masks avoid per-frame brightness/contrast/luminanceToAlpha.
        Image(
            decorative: CardDissolveTexture.thresholdMaskImage(
                progress: progress,
                edgeDepthWeight: edgeDepthWeight,
                noiseWeight: noiseWeight,
                cellSize: cellSize,
                thresholdMidpoint: thresholdMidpoint,
                thresholdContrast: thresholdContrast
            ),
            scale: 1
        )
        .resizable()
        .interpolation(.none)
    }
}

enum CardDissolveTexture {
    private static let width = 192
    private static let height = 256
    /// Discrete dissolve steps — enough for a smooth wipe without unique masks per frame.
    private static let progressSteps = 40
    private static let cache = TextureCache()

    private struct NoiseCacheKey: Hashable {
        let edgeDepthWeight: Int
        let noiseWeight: Int
        let cellSize: Int
    }

    private struct ThresholdCacheKey: Hashable {
        let noise: NoiseCacheKey
        let progressStep: Int
        let thresholdMidpoint: Int
        let thresholdContrast: Int
    }

    private final class TextureCache: @unchecked Sendable {
        private let lock = NSLock()
        private var noiseCache: [NoiseCacheKey: [UInt8]] = [:]
        private var thresholdCache: [ThresholdCacheKey: CGImage] = [:]

        func noiseBytes(
            key: NoiseCacheKey,
            make: () -> [UInt8]
        ) -> [UInt8] {
            lock.lock()
            defer { lock.unlock() }
            if let cached = noiseCache[key] {
                return cached
            }
            let bytes = make()
            noiseCache[key] = bytes
            return bytes
        }

        func thresholdImage(
            key: ThresholdCacheKey,
            make: () -> CGImage
        ) -> CGImage {
            lock.lock()
            defer { lock.unlock() }
            if let cached = thresholdCache[key] {
                return cached
            }
            let image = make()
            thresholdCache[key] = image
            return image
        }
    }

    static func noiseImage(
        edgeDepthWeight: CGFloat = 0.86,
        noiseWeight: CGFloat = 0.18,
        cellSize: Int = 1
    ) -> CGImage {
        let bytes = noiseBytes(
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: cellSize
        )
        return makeGrayscaleImage(pixels: bytes, width: width, height: height)
    }

    /// Baked alpha mask for a quantized dissolve progress (no SwiftUI filter chain).
    static func thresholdMaskImage(
        progress: CGFloat,
        edgeDepthWeight: CGFloat = 0.86,
        noiseWeight: CGFloat = 0.18,
        cellSize: Int = 1,
        thresholdMidpoint: CGFloat = 0.46,
        thresholdContrast: CGFloat = 100
    ) -> CGImage {
        let clampedCell = max(1, min(cellSize, 16))
        let noiseKey = NoiseCacheKey(
            edgeDepthWeight: quantize(edgeDepthWeight),
            noiseWeight: quantize(noiseWeight),
            cellSize: clampedCell
        )
        let step = min(
            progressSteps,
            max(0, Int((min(max(progress, 0), 1) * CGFloat(progressSteps)).rounded()))
        )
        let key = ThresholdCacheKey(
            noise: noiseKey,
            progressStep: step,
            thresholdMidpoint: quantize(thresholdMidpoint),
            thresholdContrast: Int(thresholdContrast.rounded())
        )
        // Resolve noise outside `thresholdImage`'s lock — NSLock is not recursive, and
        // baking under the lock while calling `noiseBytes` deadlocks the UI on first cast.
        let noise = noiseBytes(
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: clampedCell
        )
        let steppedProgress = CGFloat(step) / CGFloat(progressSteps)
        return cache.thresholdImage(key: key) {
            makeThresholdImage(
                noise: noise,
                progress: steppedProgress,
                thresholdMidpoint: thresholdMidpoint,
                thresholdContrast: thresholdContrast
            )
        }
    }

    /// Ensures default noise + quantized threshold masks are resident before first cast.
    /// Work runs off the main queue so battle chrome can appear without a hitch.
    static func prewarm(
        edgeDepthWeight: CGFloat = 0.86,
        noiseWeight: CGFloat = 0.18,
        cellSize: Int = 1
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = noiseImage(
                edgeDepthWeight: edgeDepthWeight,
                noiseWeight: noiseWeight,
                cellSize: cellSize
            )
            for step in 0 ... progressSteps {
                let progress = CGFloat(step) / CGFloat(progressSteps)
                _ = thresholdMaskImage(
                    progress: progress,
                    edgeDepthWeight: edgeDepthWeight,
                    noiseWeight: noiseWeight,
                    cellSize: cellSize
                )
            }
        }
    }

    private static func noiseBytes(
        edgeDepthWeight: CGFloat,
        noiseWeight: CGFloat,
        cellSize: Int
    ) -> [UInt8] {
        let clampedCell = max(1, min(cellSize, 16))
        let key = NoiseCacheKey(
            edgeDepthWeight: quantize(edgeDepthWeight),
            noiseWeight: quantize(noiseWeight),
            cellSize: clampedCell
        )
        return cache.noiseBytes(key: key) {
            makeNoiseBytes(
                edgeDepthWeight: edgeDepthWeight,
                noiseWeight: noiseWeight,
                cellSize: clampedCell
            )
        }
    }

    private static func quantize(_ value: CGFloat) -> Int {
        Int((value * 1000).rounded())
    }

    private static func makeNoiseBytes(
        edgeDepthWeight: CGFloat,
        noiseWeight: CGFloat,
        cellSize: Int
    ) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let columns = max(1, width / cellSize)
        let rows = max(1, height / cellSize)
        let maximumInset = CGFloat(min(width, height)) / 2
        let depthWeight = max(edgeDepthWeight, 0)
        let noiseAmount = max(noiseWeight, 0)

        for row in 0 ..< rows {
            for column in 0 ..< columns {
                let midpoint = CGPoint(
                    x: (CGFloat(column) + 0.5) * CGFloat(cellSize),
                    y: (CGFloat(row) + 0.5) * CGFloat(cellSize)
                )
                let inset = min(
                    min(midpoint.x, CGFloat(width) - midpoint.x),
                    min(midpoint.y, CGFloat(height) - midpoint.y)
                )
                let edgeDepth = max(0, inset / maximumInset)
                let noise = CombatFeedbackLayout.unitNoise(
                    seed: column &* 12989 &+ row &* 78233
                )
                let threshold = min(edgeDepth * depthWeight + noise * noiseAmount, 1)
                let byte = UInt8(clamping: Int((threshold * 255).rounded()))
                let maxY = min((row + 1) * cellSize, height)
                let maxX = min((column + 1) * cellSize, width)
                for y in row * cellSize ..< maxY {
                    for x in column * cellSize ..< maxX {
                        pixels[y * width + x] = byte
                    }
                }
            }
        }
        return pixels
    }

    /// Mirrors SwiftUI brightness → contrast → luminanceToAlpha for the dissolve wipe.
    private static func makeThresholdImage(
        noise: [UInt8],
        progress: CGFloat,
        thresholdMidpoint: CGFloat,
        thresholdContrast: CGFloat
    ) -> CGImage {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let brightness = Double(thresholdMidpoint) - Double(progress)
        let contrast = max(Double(thresholdContrast), 1)
        for index in 0 ..< (width * height) {
            let normalized = Double(noise[index]) / 255.0
            let brightened = normalized + brightness
            let contrasted = (brightened - 0.5) * contrast + 0.5
            let alpha = UInt8(clamping: Int((min(max(contrasted, 0), 1) * 255).rounded()))
            let offset = index * 4
            rgba[offset] = 255
            rgba[offset + 1] = 255
            rgba[offset + 2] = 255
            rgba[offset + 3] = alpha
        }
        return makeRGBAImage(pixels: rgba, width: width, height: height)
    }

    private static func makeGrayscaleImage(pixels: [UInt8], width: Int, height: Int) -> CGImage {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else {
            preconditionFailure("Unable to create dissolve texture data provider")
        }
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            preconditionFailure("Unable to create dissolve texture image")
        }
        return image
    }

    private static func makeRGBAImage(pixels: [UInt8], width: Int, height: Int) -> CGImage {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else {
            preconditionFailure("Unable to create dissolve threshold data provider")
        }
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            preconditionFailure("Unable to create dissolve threshold image")
        }
        return image
    }
}
