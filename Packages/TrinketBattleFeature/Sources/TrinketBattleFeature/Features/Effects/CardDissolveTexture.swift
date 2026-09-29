import CoreGraphics
import Foundation
import SwiftUI
import Synchronization

struct CardDissolveThresholdMask: View {
    let progress: CGFloat
    var cutAngleDegrees: CGFloat?

    var body: some View {
        let step = CardDissolveTexture.progressStep(for: progress)
        StableCardDissolveThresholdMask(step: step, cutAngleDegrees: cutAngleDegrees)
            .equatable()
    }
}

private struct StableCardDissolveThresholdMask: View, Equatable {
    let step: Int
    let cutAngleDegrees: CGFloat?

    var body: some View {
        if let image = CardDissolveTexture.thresholdMaskImage(
            progress: CGFloat(step) / CGFloat(CardDissolveTexture.progressStepCount),
            cutAngleDegrees: cutAngleDegrees,
        ) {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.none)
        } else {
            Rectangle()
        }
    }
}

enum CardDissolveTexture {
    private static let width = 192
    private static let height = 256
    private static let progressSteps = 40

    // Baked texture constants. The cache used to quantize six parameters,
    // but every caller passes these same values — only the cut angle varies
    // (nil for card dissolve, -30° for combatant slice) — so the cache keys
    // just that variant. Retune here if the dissolve look ever needs options.
    private static let edgeDepthWeight: CGFloat = 0.86
    private static let noiseWeight: CGFloat = 0.18
    private static let thresholdMidpoint: CGFloat = 0.46
    private static let thresholdContrast: CGFloat = 100

    static var progressStepCount: Int {
        progressSteps
    }

    private static var cache: TextureCache {
        prewarmState.withLock { $0.cache }
    }

    private static let prewarmState = Mutex(PrewarmState())

    static func progressStep(for progress: CGFloat) -> Int {
        min(
            progressSteps,
            max(0, Int((min(max(progress, 0), 1) * CGFloat(progressSteps)).rounded())),
        )
    }

    /// The only texture input that varies between callers.
    private struct CutVariant: Hashable {
        let cutAngleDegrees: Int?
    }

    private struct ThresholdKey: Hashable {
        let cut: CutVariant
        let progressStep: Int
    }

    private struct PrewarmState {
        var cache = TextureCache()
        var tasks: [CutVariant: Task<Void, Never>] = [:]
        var prepared: Set<CutVariant> = []
    }

    private final class TextureCache: Sendable {
        private let noiseCache = Mutex<[CutVariant: [UInt8]]>([:])
        private let thresholdCache = Mutex<[ThresholdKey: CGImage]>([:])

        func noiseBytes(for cut: CutVariant, make: () -> [UInt8]) -> [UInt8] {
            if let cached = noiseCache.withLock({ $0[cut] }) {
                return cached
            }
            let bytes = make()
            return noiseCache.withLock { cache in
                if let cached = cache[cut] {
                    return cached
                }
                cache[cut] = bytes
                return bytes
            }
        }

        func thresholdImage(for key: ThresholdKey, make: () -> CGImage?) -> CGImage? {
            if let cached = thresholdCache.withLock({ $0[key] }) {
                return cached
            }
            guard let image = make() else {
                return nil
            }
            return thresholdCache.withLock { cache in
                if let cached = cache[key] {
                    return cached
                }
                cache[key] = image
                return image
            }
        }
    }

    static func isPrepared(cutAngleDegrees: CGFloat? = nil) -> Bool {
        prewarmState.withLock { $0.prepared.contains(CutVariant(cutAngleDegrees: roundedAngle(cutAngleDegrees))) }
    }

    static func clearCache() {
        prewarmState.withLock { state in
            for task in state.tasks.values {
                task.cancel()
            }
            state.tasks.removeAll()
            state.prepared.removeAll()
            state.cache = TextureCache()
        }
    }

    static func thresholdMaskImage(progress: CGFloat, cutAngleDegrees: CGFloat? = nil) -> CGImage? {
        let cut = CutVariant(cutAngleDegrees: roundedAngle(cutAngleDegrees))
        return thresholdMaskImage(cache: cache, cut: cut, step: progressStep(for: progress))
    }

    private static func thresholdMaskImage(cache: TextureCache, cut: CutVariant, step: Int) -> CGImage? {
        let noise = noiseBytes(for: cut, cache: cache)
        let steppedProgress = CGFloat(step) / CGFloat(progressSteps)
        return cache.thresholdImage(for: ThresholdKey(cut: cut, progressStep: step)) {
            makeThresholdImage(noise: noise, progress: steppedProgress)
        }
    }

    static func prewarm(cutAngleDegrees: CGFloat? = nil) {
        _ = prewarmTask(cutAngleDegrees: cutAngleDegrees)
    }

    static func prepare(cutAngleDegrees: CGFloat? = nil) async {
        while !Task.isCancelled {
            let preparingCache = cache
            guard let task = prewarmTask(cutAngleDegrees: cutAngleDegrees) else { return }
            await task.value
            if prewarmState.withLock({ $0.cache === preparingCache }) {
                return
            }
        }
    }

    private static func prewarmTask(cutAngleDegrees: CGFloat?) -> Task<Void, Never>? {
        let cut = CutVariant(cutAngleDegrees: roundedAngle(cutAngleDegrees))
        return prewarmState.withLock { state in
            if state.prepared.contains(cut) {
                return nil
            }
            if let task = state.tasks[cut] {
                return task
            }
            let cache = state.cache
            let task = Task.detached(priority: .userInitiated) {
                _ = noiseBytes(for: cut, cache: cache)
                var preparedAllSteps = true
                for step in 0 ... progressSteps {
                    guard !Task.isCancelled else { return }
                    if thresholdMaskImage(cache: cache, cut: cut, step: step) == nil {
                        preparedAllSteps = false
                    }
                }
                prewarmState.withLock { state in
                    guard state.cache === cache else { return }
                    state.tasks.removeValue(forKey: cut)
                    if preparedAllSteps {
                        state.prepared.insert(cut)
                    }
                }
            }
            state.tasks[cut] = task
            return task
        }
    }
}

extension CardDissolveTexture {
    private static func roundedAngle(_ degrees: CGFloat?) -> Int? {
        degrees.map { Int($0.rounded()) }
    }

    private static func noiseBytes(for cut: CutVariant, cache: TextureCache) -> [UInt8] {
        cache.noiseBytes(for: cut) {
            makeNoiseBytes(cutAngleDegrees: cut.cutAngleDegrees.map(CGFloat.init))
        }
    }

    private static func makeNoiseBytes(cutAngleDegrees: CGFloat?) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let maximumInset = CGFloat(min(width, height)) / 2
        let depthWeight = max(edgeDepthWeight, 0)
        let noiseAmount = max(noiseWeight, 0)
        let center = CGPoint(x: CGFloat(width) * 0.5, y: CGFloat(height) * 0.5)
        let cutNormal: CGVector? = cutAngleDegrees.map { degrees in
            let radians = degrees * .pi / 180
            return CGVector(dx: cos(radians), dy: -sin(radians))
        }

        for y in 0 ..< height {
            for x in 0 ..< width {
                let midpoint = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                let inset = min(
                    min(midpoint.x, CGFloat(width) - midpoint.x),
                    min(midpoint.y, CGFloat(height) - midpoint.y),
                )
                let edgeInset: CGFloat
                if let cutNormal {
                    let cutDistance = abs(
                        (midpoint.x - center.x) * cutNormal.dx
                            + (midpoint.y - center.y) * cutNormal.dy,
                    )
                    edgeInset = min(inset, cutDistance)
                } else {
                    edgeInset = inset
                }
                let edgeDepth = max(0, edgeInset / maximumInset)
                let noise = CombatFeedbackLayout.unitNoise(
                    seed: x &* 12989 &+ y &* 78233,
                )
                let threshold = min(edgeDepth * depthWeight + noise * noiseAmount, 1)
                pixels[y * width + x] = UInt8(clamping: Int((threshold * 255).rounded()))
            }
        }
        return pixels
    }

    private static func makeThresholdImage(noise: [UInt8], progress: CGFloat) -> CGImage? {
        var grayAlpha = [UInt8](repeating: 255, count: width * height * 2)
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
            grayAlpha[index * 2 + 1] = alpha
        }
        return makeGrayAlphaImage(pixels: grayAlpha, width: width, height: height)
    }

    private static func makeGrayAlphaImage(pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else {
            return nil
        }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 16,
            bytesPerRow: width * 2,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent,
        )
    }
}
