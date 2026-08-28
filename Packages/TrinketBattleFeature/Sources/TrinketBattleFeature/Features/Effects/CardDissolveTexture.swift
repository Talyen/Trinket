import CoreGraphics
import Foundation
import SwiftUI
import Synchronization
import TrinketDesignSystem
import TrinketFeatureSupport

struct CardDissolveThresholdMask: View {
    let progress: CGFloat
    var edgeDepthWeight: CGFloat = 0.86
    var noiseWeight: CGFloat = 0.18
    var cellSize: Int = 1
    var thresholdMidpoint: CGFloat = 0.46
    var thresholdContrast: CGFloat = 100
    var cutAngleDegrees: CGFloat?

    var body: some View {
        let step = CardDissolveTexture.progressStep(for: progress)
        StableCardDissolveThresholdMask(
            step: step,
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: cellSize,
            thresholdMidpoint: thresholdMidpoint,
            thresholdContrast: thresholdContrast,
            cutAngleDegrees: cutAngleDegrees
        )
        .equatable()
    }
}

private struct StableCardDissolveThresholdMask: View, Equatable {
    let step: Int
    let edgeDepthWeight: CGFloat
    let noiseWeight: CGFloat
    let cellSize: Int
    let thresholdMidpoint: CGFloat
    let thresholdContrast: CGFloat
    let cutAngleDegrees: CGFloat?

    var body: some View {
        if let image = CardDissolveTexture.thresholdMaskImage(
            progress: CGFloat(step) / CGFloat(CardDissolveTexture.progressStepCount),
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: cellSize,
            thresholdMidpoint: thresholdMidpoint,
            thresholdContrast: thresholdContrast,
            cutAngleDegrees: cutAngleDegrees
        ) {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.none)
        }
    }
}

enum CardDissolveTexture {
    private static let width = 192
    private static let height = 256
    private static let progressSteps = 40
    static var progressStepCount: Int {
        progressSteps
    }

    private static let cache = TextureCache()
    private static let prewarmState = Mutex(PrewarmState())

    static func progressStep(for progress: CGFloat) -> Int {
        min(
            progressSteps,
            max(0, Int((min(max(progress, 0), 1) * CGFloat(progressSteps)).rounded()))
        )
    }

    private struct PrewarmState {
        var tasks: [NoiseCacheKey: Task<Void, Never>] = [:]
        var prepared: Set<NoiseCacheKey> = []
    }

    private struct NoiseCacheKey: Hashable {
        let edgeDepthWeight: Int
        let noiseWeight: Int
        let cellSize: Int
        let cutAngleDegrees: Int?
    }

    private struct ThresholdCacheKey: Hashable {
        let noise: NoiseCacheKey
        let progressStep: Int
        let thresholdMidpoint: Int
        let thresholdContrast: Int
    }

    private final class TextureCache: Sendable {
        private let noiseCache = Mutex<[NoiseCacheKey: [UInt8]]>([:])
        private let thresholdCache = Mutex<[ThresholdCacheKey: CGImage]>([:])
        private let provisionalCache = Mutex<[Int: CGImage]>([:])

        func noiseBytes(
            key: NoiseCacheKey,
            make: () -> [UInt8]
        ) -> [UInt8] {
            noiseCache.withLock { cache in
                if let cached = cache[key] {
                    return cached
                }
                let bytes = make()
                cache[key] = bytes
                return bytes
            }
        }

        func cachedThresholdImage(key: ThresholdCacheKey) -> CGImage? {
            thresholdCache.withLock { $0[key] }
        }

        func thresholdImage(
            key: ThresholdCacheKey,
            make: () -> CGImage?
        ) -> CGImage? {
            thresholdCache.withLock { cache in
                if let cached = cache[key] {
                    return cached
                }
                guard let image = make() else {
                    return nil
                }
                cache[key] = image
                return image
            }
        }

        func provisionalThresholdImage(progressStep: Int) -> CGImage? {
            provisionalCache.withLock { cache in
                if let cached = cache[progressStep] {
                    return cached
                }
                let alpha = UInt8(
                    clamping: Int(
                        ((1 - Double(progressStep) / Double(progressSteps)) * 255).rounded()
                    )
                )
                var rgba = [UInt8](repeating: 255, count: width * height * 4)
                for index in 0 ..< (width * height) {
                    rgba[index * 4 + 3] = alpha
                }
                guard let image = makeRGBAImage(pixels: rgba, width: width, height: height) else {
                    return nil
                }
                cache[progressStep] = image
                return image
            }
        }
    }

    static func noiseImage(
        edgeDepthWeight: CGFloat = 0.86,
        noiseWeight: CGFloat = 0.18,
        cellSize: Int = 1,
        cutAngleDegrees: CGFloat? = nil
    ) -> CGImage? {
        let bytes = noiseBytes(
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: cellSize,
            cutAngleDegrees: cutAngleDegrees
        )
        return makeGrayscaleImage(pixels: bytes, width: width, height: height)
    }

    static func thresholdMaskImage(
        progress: CGFloat,
        edgeDepthWeight: CGFloat = 0.86,
        noiseWeight: CGFloat = 0.18,
        cellSize: Int = 1,
        thresholdMidpoint: CGFloat = 0.46,
        thresholdContrast: CGFloat = 100,
        cutAngleDegrees: CGFloat? = nil
    ) -> CGImage? {
        let clampedCell = max(1, min(cellSize, 16))
        let noiseKey = noiseCacheKey(
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: clampedCell,
            cutAngleDegrees: cutAngleDegrees
        )
        let step = progressStep(for: progress)
        let key = ThresholdCacheKey(
            noise: noiseKey,
            progressStep: step,
            thresholdMidpoint: quantize(thresholdMidpoint),
            thresholdContrast: Int(thresholdContrast.rounded())
        )
        if let cached = cache.cachedThresholdImage(key: key) {
            return cached
        }
        return bakeThresholdMaskImage(
            progress: progress,
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: clampedCell,
            thresholdMidpoint: thresholdMidpoint,
            thresholdContrast: thresholdContrast,
            cutAngleDegrees: cutAngleDegrees
        )
    }

    fileprivate static func bakeThresholdMaskImage(
        progress: CGFloat,
        edgeDepthWeight: CGFloat = 0.86,
        noiseWeight: CGFloat = 0.18,
        cellSize: Int = 1,
        thresholdMidpoint: CGFloat = 0.46,
        thresholdContrast: CGFloat = 100,
        cutAngleDegrees: CGFloat? = nil
    ) -> CGImage? {
        let clampedCell = max(1, min(cellSize, 16))
        let noiseKey = noiseCacheKey(
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: clampedCell,
            cutAngleDegrees: cutAngleDegrees
        )
        let step = progressStep(for: progress)
        let key = ThresholdCacheKey(
            noise: noiseKey,
            progressStep: step,
            thresholdMidpoint: quantize(thresholdMidpoint),
            thresholdContrast: Int(thresholdContrast.rounded())
        )
        let noise = noiseBytes(
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: clampedCell,
            cutAngleDegrees: cutAngleDegrees
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

    static func prewarm(
        edgeDepthWeight: CGFloat = 0.86,
        noiseWeight: CGFloat = 0.18,
        cellSize: Int = 1,
        cutAngleDegrees: CGFloat? = nil
    ) {
        _ = prewarmTask(
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: cellSize,
            cutAngleDegrees: cutAngleDegrees
        )
    }

    static func prepare(
        edgeDepthWeight: CGFloat = 0.86,
        noiseWeight: CGFloat = 0.18,
        cellSize: Int = 1,
        cutAngleDegrees: CGFloat? = nil
    ) async {
        guard let task = prewarmTask(
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: cellSize,
            cutAngleDegrees: cutAngleDegrees
        ) else { return }
        await task.value
    }

    private static func prewarmTask(
        edgeDepthWeight: CGFloat,
        noiseWeight: CGFloat,
        cellSize: Int,
        cutAngleDegrees: CGFloat?
    ) -> Task<Void, Never>? {
        let key = noiseCacheKey(
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: max(1, min(cellSize, 16)),
            cutAngleDegrees: cutAngleDegrees
        )
        return prewarmState.withLock { state in
            if state.prepared.contains(key) {
                return nil
            }
            if let task = state.tasks[key] {
                return task
            }
            // Concurrency-Safety: detached CPU baking cannot block the caller's
            let task = Task.detached(priority: .userInitiated) {
                _ = noiseImage(
                    edgeDepthWeight: edgeDepthWeight,
                    noiseWeight: noiseWeight,
                    cellSize: cellSize,
                    cutAngleDegrees: cutAngleDegrees
                )
                for step in 0 ... progressSteps {
                    let progress = CGFloat(step) / CGFloat(progressSteps)
                    _ = bakeThresholdMaskImage(
                        progress: progress,
                        edgeDepthWeight: edgeDepthWeight,
                        noiseWeight: noiseWeight,
                        cellSize: cellSize,
                        cutAngleDegrees: cutAngleDegrees
                    )
                }
                prewarmState.withLock { state in
                    state.tasks.removeValue(forKey: key)
                    state.prepared.insert(key)
                }
            }
            state.tasks[key] = task
            return task
        }
    }
}

extension CardDissolveTexture {
    private static func noiseCacheKey(
        edgeDepthWeight: CGFloat,
        noiseWeight: CGFloat,
        cellSize: Int,
        cutAngleDegrees: CGFloat?
    ) -> NoiseCacheKey {
        NoiseCacheKey(
            edgeDepthWeight: quantize(edgeDepthWeight),
            noiseWeight: quantize(noiseWeight),
            cellSize: cellSize,
            cutAngleDegrees: cutAngleDegrees.map { Int($0.rounded()) }
        )
    }

    private static func noiseBytes(
        edgeDepthWeight: CGFloat,
        noiseWeight: CGFloat,
        cellSize: Int,
        cutAngleDegrees: CGFloat?
    ) -> [UInt8] {
        let clampedCell = max(1, min(cellSize, 16))
        let key = noiseCacheKey(
            edgeDepthWeight: edgeDepthWeight,
            noiseWeight: noiseWeight,
            cellSize: clampedCell,
            cutAngleDegrees: cutAngleDegrees
        )
        return cache.noiseBytes(key: key) {
            makeNoiseBytes(
                edgeDepthWeight: edgeDepthWeight,
                noiseWeight: noiseWeight,
                cellSize: clampedCell,
                cutAngleDegrees: cutAngleDegrees
            )
        }
    }

    private static func quantize(_ value: CGFloat) -> Int {
        Int((value * 1000).rounded())
    }

    private static func makeNoiseBytes(
        edgeDepthWeight: CGFloat,
        noiseWeight: CGFloat,
        cellSize: Int,
        cutAngleDegrees: CGFloat?
    ) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let columns = max(1, width / cellSize)
        let rows = max(1, height / cellSize)
        let maximumInset = CGFloat(min(width, height)) / 2
        let depthWeight = max(edgeDepthWeight, 0)
        let noiseAmount = max(noiseWeight, 0)
        let center = CGPoint(x: CGFloat(width) * 0.5, y: CGFloat(height) * 0.5)
        let cutNormal: CGVector? = cutAngleDegrees.map { degrees in
            let radians = degrees * .pi / 180
            return CGVector(dx: cos(radians), dy: -sin(radians))
        }

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
                let edgeInset: CGFloat
                if let cutNormal {
                    let cutDistance = abs(
                        (midpoint.x - center.x) * cutNormal.dx
                            + (midpoint.y - center.y) * cutNormal.dy
                    )
                    edgeInset = min(inset, cutDistance)
                } else {
                    edgeInset = inset
                }
                let edgeDepth = max(0, edgeInset / maximumInset)
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

    private static func makeThresholdImage(
        noise: [UInt8],
        progress: CGFloat,
        thresholdMidpoint: CGFloat,
        thresholdContrast: CGFloat
    ) -> CGImage? {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let brightness = Double(thresholdMidpoint) - Double(progress)
        let contrast = max(Double(thresholdContrast), 1)
        let alphaByNoise = (0 ... 255).map { byte -> UInt8 in
            let normalized = Double(byte) / 255.0
            let brightened = normalized + brightness
            let contrasted = (brightened - 0.5) * contrast + 0.5
            return UInt8(clamping: Int((min(max(contrasted, 0), 1) * 255).rounded()))
        }
        for index in 0 ..< (width * height) {
            let alpha = alphaByNoise[Int(noise[index])]
            let offset = index * 4
            rgba[offset] = 255
            rgba[offset + 1] = 255
            rgba[offset + 2] = 255
            rgba[offset + 3] = alpha
        }
        return makeRGBAImage(pixels: rgba, width: width, height: height)
    }

    private static func makeGrayscaleImage(pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else {
            return nil
        }
        return CGImage(
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
        )
    }

    private static func makeRGBAImage(pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else {
            return nil
        }
        return CGImage(
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
        )
    }
}
