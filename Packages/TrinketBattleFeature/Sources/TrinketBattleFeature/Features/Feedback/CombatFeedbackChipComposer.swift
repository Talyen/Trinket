import CoreGraphics
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

/// Blits prewarmed glyphs into a single chip raster. Warm path target: under 1 ms.
@MainActor
enum CombatFeedbackChipComposer {
    private static let horizontalPadding: CGFloat = 4
    private static let verticalPadding: CGFloat = 5
    private static let glyphSpacing: CGFloat = 8
    private static let shadowOffsetY: CGFloat = 1.5

    struct ComposedRaster {
        let image: CGImage
        let pointSize: CGSize
    }

    static func compose(
        presentation: CombatFeedbackChipPresentation,
        feedbackClass: CombatFeedbackClass,
        presentationRole: CombatFeedbackPresentationRole = .headline,
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat,
        atlas: CombatFeedbackGlyphAtlas = .shared
    ) -> ComposedRaster? {
        let recipe = CombatFeedbackChipRecipes.chip(for: feedbackClass)
        let scale = max(1, displayScale)
        let face = CombatFeedbackGlyphAtlas.Face(
            feedbackClass: feedbackClass,
            presentationRole: presentationRole,
            dynamicTypeSize: dynamicTypeSize,
            displayScaleHundredths: Int((scale * 100).rounded())
        )

        var leadingGlyph: CombatFeedbackGlyphAtlas.Glyph?
        if let leadingName = presentation.leadingSymbolName {
            guard let glyph = atlas.symbol(named: leadingName, face: face, recipe: recipe) else {
                return nil
            }
            leadingGlyph = glyph
        }

        guard let trailingGlyph = atlas.symbol(
            named: presentation.trailingSymbolName,
            face: face,
            recipe: recipe
        ) else {
            return nil
        }

        let renderedText: [CombatFeedbackGlyphAtlas.Glyph]
        if let text = presentation.text, !text.isEmpty {
            guard let glyphs = makeTextGlyphs(
                for: text,
                face: face,
                recipe: recipe,
                atlas: atlas
            ) else {
                return nil
            }
            renderedText = glyphs
        } else {
            renderedText = []
        }

        return blit(
            leading: leadingGlyph.map {
                // UIStyleCheck: allow - CoreGraphics compose needs UIKit colors bridged from semantic roles.
                (
                    $0,
                    UIColor((presentation.leadingTint ?? presentation.trailingTint).color)
                )
            },
            trailing: (
                trailingGlyph,
                // UIStyleCheck: allow - CoreGraphics compose needs UIKit colors bridged from semantic roles.
                UIColor(presentation.trailingTint.color)
            ),
            textGlyphs: renderedText,
            textTint: UIColor(presentation.trailingTint.color),
            layoutDirection: layoutDirection,
            displayScale: scale
        )
    }

    /// Compatibility wrapper used by tests that still pass label + single style.
    static func compose(
        label: CombatFeedbackChipLabel,
        style: Keyword.VisualStyle,
        feedbackClass: CombatFeedbackClass,
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat,
        atlas: CombatFeedbackGlyphAtlas = .shared
    ) -> ComposedRaster? {
        let presentation = CombatFeedbackChipPresentation(
            leadingSymbolName: nil,
            leadingTint: nil,
            trailingSymbolName: style.symbolName,
            trailingTint: style,
            text: {
                switch label {
                case .amount, .percent:
                    label.displayString
                case let .word(word):
                    word.composeText
                }
            }()
        )
        return compose(
            presentation: presentation,
            feedbackClass: feedbackClass,
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
            atlas: atlas
        )
    }

    private static func blit(
        leading: (CombatFeedbackGlyphAtlas.Glyph, UIColor)?,
        trailing: (CombatFeedbackGlyphAtlas.Glyph, UIColor),
        textGlyphs: [CombatFeedbackGlyphAtlas.Glyph],
        textTint: UIColor,
        layoutDirection: LayoutDirection,
        displayScale: CGFloat
    ) -> ComposedRaster? {
        let textWidth = textGlyphs.reduce(CGFloat(0)) { $0 + $1.width }
        let textHeight = textGlyphs.map(\.height).max() ?? 0
        let leadingWidth = leading?.0.width ?? 0
        let trailingWidth = trailing.0.width
        let symbolCount = (leading == nil ? 0 : 1) + 1
        let textPresent = textWidth > 0
        let gapCount = max(0, (symbolCount + (textPresent ? 1 : 0)) - 1)
        let contentWidth = leadingWidth + trailingWidth + textWidth + CGFloat(gapCount) * glyphSpacing
        let contentHeight = max(leading?.0.height ?? 0, trailing.0.height, textHeight)
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
            let origins = horizontalOrigins(
                contentX: contentOrigin.x,
                leadingWidth: leadingWidth,
                textWidth: textWidth,
                trailingWidth: trailingWidth,
                layoutDirection: layoutDirection
            )

            let context = UIGraphicsGetCurrentContext()
            context?.setShadow(
                offset: CGSize(width: 0, height: shadowOffsetY),
                blur: 0,
                color: shadow.cgColor
            )

            if let leading {
                let origin = CGPoint(
                    x: origins.leadingX,
                    y: contentOrigin.y + (contentHeight - leading.0.height) / 2
                )
                draw(glyph: leading.0, at: origin, tint: leading.1, displayScale: displayScale)
            }

            var textX = origins.textX
            for glyph in textGlyphs {
                let origin = CGPoint(
                    x: textX,
                    y: contentOrigin.y + (contentHeight - glyph.height) / 2
                )
                draw(glyph: glyph, at: origin, tint: textTint, displayScale: displayScale)
                textX += glyph.width
            }

            let trailingOrigin = CGPoint(
                x: origins.trailingX,
                y: contentOrigin.y + (contentHeight - trailing.0.height) / 2
            )
            draw(glyph: trailing.0, at: trailingOrigin, tint: trailing.1, displayScale: displayScale)
            context?.setShadow(offset: .zero, blur: 0, color: nil)
        }

        guard let cgImage = image.cgImage else { return nil }
        return ComposedRaster(image: cgImage, pointSize: pointSize)
    }

    /// LTR: leading → text → trailing. RTL mirrors that sequence.
    private static func horizontalOrigins(
        contentX: CGFloat,
        leadingWidth: CGFloat,
        textWidth: CGFloat,
        trailingWidth: CGFloat,
        layoutDirection: LayoutDirection
    ) -> (leadingX: CGFloat, textX: CGFloat, trailingX: CGFloat) {
        let leadingPresent = leadingWidth > 0
        let textPresent = textWidth > 0

        func advance(_ x: inout CGFloat, width: CGFloat, present: Bool) {
            if present {
                x += width + glyphSpacing
            }
        }

        switch layoutDirection {
        case .rightToLeft:
            var x = contentX
            let trailingX = x
            x += trailingWidth + glyphSpacing
            let textX = x
            advance(&x, width: textWidth, present: textPresent)
            let leadingX = x
            return (leadingX, textX, trailingX)
        case .leftToRight:
            fallthrough
        @unknown default:
            var x = contentX
            let leadingX = x
            advance(&x, width: leadingWidth, present: leadingPresent)
            let textX = x
            advance(&x, width: textWidth, present: textPresent)
            let trailingX = x
            return (leadingX, textX, trailingX)
        }
    }

    private static func makeTextGlyphs(
        for text: String,
        face: CombatFeedbackGlyphAtlas.Face,
        recipe: CombatFeedbackChipStyle,
        atlas: CombatFeedbackGlyphAtlas
    ) -> [CombatFeedbackGlyphAtlas.Glyph]? {
        // Numeric chips pass digit characters; word chips pass one whole-word fragment.
        let fragments: [String] = if text.allSatisfy({ $0.isNumber || $0 == "%" || $0 == "+" }) {
            text.map(String.init)
        } else {
            [text]
        }
        var glyphs: [CombatFeedbackGlyphAtlas.Glyph] = []
        glyphs.reserveCapacity(fragments.count)
        for fragment in fragments {
            guard let glyph = atlas.fragment(fragment, face: face, recipe: recipe) else {
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
