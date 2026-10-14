import CoreGraphics
import UIKit

extension CombatFeedbackChipComposer {
    struct CompositionContext {
        fileprivate var tintedGlyphs: [ObjectIdentifier: [TintedGlyph]] = [:]
        fileprivate var framesBySource: [ObjectIdentifier: [GlyphFrame]] = [:]
        private var sourceOrder: [ObjectIdentifier] = []
        private var nextSourceSlot = 0
        private let maximumSources: Int

        init(maximumSources: Int = 128) {
            self.maximumSources = max(1, maximumSources)
        }

        fileprivate mutating func insert(_ glyph: TintedGlyph, for key: ObjectIdentifier) {
            // Retain source identities, but bound old scales, colors, and atlas generations.
            if tintedGlyphs[key] == nil {
                if sourceOrder.count == maximumSources {
                    framesBySource.removeValue(forKey: sourceOrder[nextSourceSlot])
                    tintedGlyphs.removeValue(forKey: sourceOrder[nextSourceSlot])
                    sourceOrder[nextSourceSlot] = key
                    nextSourceSlot = (nextSourceSlot + 1) % sourceOrder.count
                } else {
                    sourceOrder.append(key)
                }
            }
            if tintedGlyphs[key]?.count == 8 {
                tintedGlyphs[key]?.removeFirst()
            }
            tintedGlyphs[key, default: []].append(glyph)
        }

        mutating func merge(_ prepared: Self) {
            for key in prepared.sourceOrder {
                for glyph in prepared.tintedGlyphs[key] ?? [] {
                    guard tintedGlyphs[key]?.contains(where: {
                        $0.displayScale == glyph.displayScale && $0.color == glyph.color && $0.outline == glyph.outline
                    }) != true else { continue }
                    insert(glyph, for: key)
                }
                for frame in prepared.framesBySource[key] ?? []
                    where framesBySource[key]?.contains(where: { $0.rect == frame.rect }) != true {
                    if framesBySource[key]?.count == 8 {
                        framesBySource[key]?.removeFirst()
                    }
                    framesBySource[key, default: []].append(frame)
                }
            }
        }
    }

    struct TintedGlyph {
        // Keep identity valid while cached, even after atlas or raster-pool replacement.
        let source: CGImage
        let displayScale: CGFloat
        let color: CGColor
        let outline: CGColor?
        let image: UIImage
        let silhouette: UIImage?
    }

    struct GlyphFrame {
        let source: CGImage
        let rect: CGRect
        let outlineRects: [CGRect]
    }

    struct GlyphDrawing {
        let images: TintedGlyph
        let frame: GlyphFrame
    }

    nonisolated static func prepareDrawing(
        glyph: CombatFeedbackGlyphAtlas.Glyph,
        at origin: CGPoint,
        tint: UIColor,
        outline: UIColor?,
        displayScale: CGFloat,
        composition: inout CompositionContext,
    ) -> GlyphDrawing {
        let rect = CGRect(origin: origin, size: CGSize(width: glyph.width, height: glyph.height))
        let key = ObjectIdentifier(glyph.image)
        let images: TintedGlyph
        if let cached = composition.tintedGlyphs[key]?
            .first(where: { $0.displayScale == displayScale && $0.color == tint.cgColor && $0.outline == outline?.cgColor }) {
            images = cached
        } else {
            let tinted = composition.tintedGlyphs[key]?.first(where: {
                $0.displayScale == displayScale && $0.color == tint.cgColor
            })?.image ?? UIImage(cgImage: glyph.image, scale: displayScale, orientation: .up)
                .withTintColor(tint, renderingMode: .alwaysOriginal)
            images = TintedGlyph(
                source: glyph.image, displayScale: displayScale,
                color: tint.cgColor, outline: outline?.cgColor,
                image: tinted,
                silhouette: outline.map { tinted.withTintColor($0, renderingMode: .alwaysOriginal) },
            )
            composition.insert(images, for: key)
        }
        let frame: GlyphFrame
        if let cached = composition.framesBySource[key]?.first(where: { $0.rect == rect }) {
            frame = cached
        } else {
            frame = GlyphFrame(source: glyph.image, rect: rect, outlineRects: outlineOffsets.map {
                rect.offsetBy(dx: $0.x, dy: $0.y)
            })
            if composition.framesBySource[key]?.count == 8 {
                composition.framesBySource[key]?.removeFirst()
            }
            composition.framesBySource[key, default: []].append(frame)
        }
        return GlyphDrawing(images: images, frame: frame)
    }
}

private extension CombatFeedbackChipComposer {
    nonisolated static let outlineOffsets: [CGPoint] = (0 ..< 8).map { step in
        let angle = CGFloat(step) * .pi / 4
        return CGPoint(x: cos(angle), y: sin(angle))
    }
}
