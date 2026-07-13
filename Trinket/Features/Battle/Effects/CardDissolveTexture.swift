import CoreGraphics
import Foundation
import SwiftUI
import TrinketDesignSystem

struct CardDissolveThresholdMask: View {
    let progress: CGFloat

    var body: some View {
        CardDissolveTexture.noiseImage
            .resizable()
            .interpolation(.none)
            .brightness(0.5 - Double(progress))
            .contrast(100)
            .luminanceToAlpha()
    }
}

struct CardDissolveEdgeMask: View {
    let progress: CGFloat
    let edgeWidth: CGFloat
    let cellScale: CGFloat

    var body: some View {
        ZStack {
            CardDissolveThresholdMask(progress: progress)
            CardDissolveThresholdMask(progress: min(progress + edgeWidth, 1))
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .mask {
            Rectangle().fill(CardDissolveTexture.cellPaint(scale: cellScale))
        }
    }
}

enum CardDissolveTexture {
    private static let width = 192
    private static let height = 256
    private static let cellSize = 4

    static let noiseImage = Image(decorative: makeNoiseImage(), scale: 1)

    static func cellPaint(scale: CGFloat) -> ImagePaint {
        ImagePaint(
            image: Image(decorative: makeCellImage(scale: scale), scale: 1),
            scale: 1
        )
    }

    private static func makeNoiseImage() -> CGImage {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let columns = width / cellSize
        let rows = height / cellSize
        let maximumInset = CGFloat(min(width, height)) / 2

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
                let threshold = min(edgeDepth * 0.86 + noise * 0.18, 1)
                let byte = UInt8(clamping: Int((threshold * 255).rounded()))
                for y in row * cellSize ..< (row + 1) * cellSize {
                    for x in column * cellSize ..< (column + 1) * cellSize {
                        pixels[y * width + x] = byte
                    }
                }
            }
        }
        return makeGrayscaleImage(pixels: pixels, width: width, height: height)
    }

    private static func makeCellImage(scale: CGFloat) -> CGImage {
        let clampedScale = min(max(scale, 0), 1)
        let halfCell = CGFloat(cellSize) * clampedScale / 2 + 0.25
        let center = CGFloat(cellSize) / 2
        var pixels = [UInt8](repeating: 0, count: cellSize * cellSize)
        for y in 0 ..< cellSize {
            for x in 0 ..< cellSize {
                let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                if abs(point.x - center) <= halfCell, abs(point.y - center) <= halfCell {
                    pixels[y * cellSize + x] = 255
                }
            }
        }
        return makeGrayscaleImage(pixels: pixels, width: cellSize, height: cellSize)
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
}
