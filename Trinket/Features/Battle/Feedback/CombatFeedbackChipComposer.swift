import CoreGraphics
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import UIKit

/// Blits prewarmed glyphs into a single chip raster. Warm path target: under 1 ms.
@MainActor
enum CombatFeedbackChipComposer {
    private static let horizontalPadding: CGFloat = 4
    private static let verticalPadding: CGFloat = 5
    private static let symbolTextSpacing: CGFloat = 8
    private static let shadowOffsetY: CGFloat = 1.5

    struct ComposedRaster {
        let image: CGImage
        let pointSize: CGSize
    }

    static func compose(
        label: CombatFeedbackChipLabel,
        style: Keyword.VisualStyle,
        feedbackClass: CombatFeedbackClass,
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat,
        atlas: CombatFeedbackGlyphAtlas = .shared
    ) -> ComposedRaster? {
        let recipe = TrinketMotion.Battle.chip(for: feedbackClass)
        let scale = max(1, displayScale)
        let face = CombatFeedbackGlyphAtlas.Face(
            feedbackClass: feedbackClass,
            dynamicTypeSize: dynamicTypeSize,
            displayScaleHundredths: Int((scale * 100).rounded())
        )

        guard let symbol = atlas.symbol(
            named: style.symbolName,
            face: face,
            recipe: recipe
        ) else {
            return nil
        }
        guard let textGlyphs = textGlyphs(
            for: label,
            face: face,
            recipe: recipe,
            atlas: atlas
        ) else {
            return nil
        }

        return blit(
            symbol: symbol,
            textGlyphs: textGlyphs,
            layoutDirection: layoutDirection,
            // UIStyleCheck: allow - CoreGraphics compose needs UIKit colors bridged from semantic roles.
            tint: UIColor(style.color),
            displayScale: scale
        )
    }

    private static func blit(
        symbol: CombatFeedbackGlyphAtlas.Glyph,
        textGlyphs: [CombatFeedbackGlyphAtlas.Glyph],
        layoutDirection: LayoutDirection,
        tint: UIColor,
        displayScale: CGFloat
    ) -> ComposedRaster? {
        let textWidth = textGlyphs.reduce(CGFloat(0)) { $0 + $1.width }
        let textHeight = textGlyphs.map(\.height).max() ?? 0
        let contentWidth = symbol.width + symbolTextSpacing + textWidth
        let contentHeight = max(symbol.height, textHeight)
        let pointSize = CGSize(
            width: ceil(contentWidth + horizontalPadding * 2),
            height: ceil(contentHeight + verticalPadding * 2 + shadowOffsetY)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = displayScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        // UIStyleCheck: allow - CoreGraphics compose needs UIKit colors bridged from semantic roles.
        let shadow = UIColor(TrinketDesign.Colors.Overlay.ink.opacity(0.95))
        let image = renderer.image { _ in
            let contentOrigin = CGPoint(x: horizontalPadding, y: verticalPadding)
            let symbolX = switch layoutDirection {
            case .leftToRight:
                contentOrigin.x + textWidth + symbolTextSpacing
            case .rightToLeft:
                contentOrigin.x
            @unknown default:
                contentOrigin.x + textWidth + symbolTextSpacing
            }
            let symbolOrigin = CGPoint(
                x: symbolX,
                y: contentOrigin.y + (contentHeight - symbol.height) / 2
            )
            var textX = switch layoutDirection {
            case .leftToRight:
                contentOrigin.x
            case .rightToLeft:
                contentOrigin.x + symbol.width + symbolTextSpacing
            @unknown default:
                contentOrigin.x
            }

            let context = UIGraphicsGetCurrentContext()
            context?.setShadow(
                offset: CGSize(width: 0, height: shadowOffsetY),
                blur: 0,
                color: shadow.cgColor
            )

            for glyph in textGlyphs {
                let origin = CGPoint(
                    x: textX,
                    y: contentOrigin.y + (contentHeight - glyph.height) / 2
                )
                draw(glyph: glyph, at: origin, tint: tint, displayScale: displayScale)
                textX += glyph.width
            }
            draw(glyph: symbol, at: symbolOrigin, tint: tint, displayScale: displayScale)
            context?.setShadow(offset: .zero, blur: 0, color: nil)
        }

        guard let cgImage = image.cgImage else { return nil }
        return ComposedRaster(image: cgImage, pointSize: pointSize)
    }

    private static func textGlyphs(
        for label: CombatFeedbackChipLabel,
        face: CombatFeedbackGlyphAtlas.Face,
        recipe: CombatFeedbackMotionRecipe,
        atlas: CombatFeedbackGlyphAtlas
    ) -> [CombatFeedbackGlyphAtlas.Glyph]? {
        var glyphs: [CombatFeedbackGlyphAtlas.Glyph] = []
        glyphs.reserveCapacity(label.atlasFragments.count)
        for fragment in label.atlasFragments {
            guard let glyph = atlas.fragment(
                fragment,
                face: face,
                recipe: recipe
            ) else {
                return nil
            }
            glyphs.append(glyph)
        }
        return glyphs
    }

    private static func draw(
        glyph: CombatFeedbackGlyphAtlas.Glyph,
        at origin: CGPoint,
        tint: UIColor,
        displayScale: CGFloat
    ) {
        let rect = CGRect(origin: origin, size: CGSize(width: glyph.width, height: glyph.height))
        let tinted = UIImage(cgImage: glyph.image, scale: displayScale, orientation: .up)
            .withTintColor(tint, renderingMode: .alwaysOriginal)
        tinted.draw(in: rect)
    }
}
