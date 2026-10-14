import CoreGraphics
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

@MainActor
enum CombatFeedbackChipComposer {
    private nonisolated static let horizontalPadding: CGFloat = 4
    private nonisolated static let verticalPadding: CGFloat = 5
    private nonisolated static let glyphSpacing: CGFloat = 8
    private nonisolated static let shadowOffsetY: CGFloat = 1.5

    /// Concurrency-Safety: immutable CGImage and dimensions cross from the raster worker to the main-actor pool.
    struct ComposedRaster: @unchecked Sendable {
        let image: CGImage
        let pointSize: CGSize
        var shineMask: CGImage?
        var textWidth: CGFloat = 0
        var maximumDigitWidth: CGFloat = 0
    }

    /// Concurrency-Safety: glyph bitmaps and resolved CGColors are immutable; no atlas or SwiftUI state crosses isolation.
    struct RasterInputs: @unchecked Sendable {
        let leading: (CombatFeedbackGlyphAtlas.Glyph, CGColor)?
        let trailing: (CombatFeedbackGlyphAtlas.Glyph, CGColor)
        let textGlyphs: [CombatFeedbackGlyphAtlas.Glyph]
        let textTint: CGColor
        let shadow: CGColor
        let layoutDirection: LayoutDirection
        let displayScale: CGFloat
        let needsShineMask: Bool
        let maximumDigitWidth: CGFloat
    }

    static func compose(
        presentation: CombatFeedbackChipPresentation,
        feedbackClass: CombatFeedbackClass,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat,
        atlas: CombatFeedbackGlyphAtlas = .shared,
        needsShineMask: Bool = false,
    ) -> ComposedRaster? {
        var context = CompositionContext()
        return compose(
            presentation: presentation, feedbackClass: feedbackClass,
            layoutDirection: layoutDirection, displayScale: displayScale,
            atlas: atlas, needsShineMask: needsShineMask, context: &context,
        )
    }

    static func compose(
        presentation: CombatFeedbackChipPresentation,
        feedbackClass: CombatFeedbackClass,
        layoutDirection: LayoutDirection,
        displayScale: CGFloat,
        atlas: CombatFeedbackGlyphAtlas = .shared,
        needsShineMask: Bool,
        context: inout CompositionContext,
    ) -> ComposedRaster? {
        guard let inputs = prepareInputs(
            presentation: presentation, feedbackClass: feedbackClass,
            layoutDirection: layoutDirection, displayScale: displayScale, atlas: atlas, needsShineMask: needsShineMask,
        ) else { return nil }
        return render(inputs, context: &context)
    }

    static func prepareInputs(
        presentation: CombatFeedbackChipPresentation,
        feedbackClass: CombatFeedbackClass,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat,
        atlas: CombatFeedbackGlyphAtlas = .shared,
        needsShineMask: Bool = false,
    ) -> RasterInputs? {
        let recipe = CombatFeedbackChipStyle.forClass(feedbackClass)
        let scale = max(1, displayScale)
        let face = CombatFeedbackGlyphAtlas.Face(
            feedbackClass: feedbackClass,
            displayScaleHundredths: Int((scale * 100).rounded()),
        )

        var leadingGlyph: CombatFeedbackGlyphAtlas.Glyph?
        if let leadingStyle = presentation.leadingStyle {
            guard let glyph = atlas.icon(
                leadingStyle.feedbackIcon,
                face: face,
                recipe: recipe,
            ) else {
                return nil
            }
            leadingGlyph = glyph
        }

        let trailingStyle = presentation.trailingStyle.visualStyle
        guard let trailingGlyph = atlas.icon(
            presentation.trailingStyle.feedbackIcon,
            face: face,
            recipe: recipe,
        ) else {
            return nil
        }

        let renderedText: [CombatFeedbackGlyphAtlas.Glyph]
        if let text = presentation.text, !text.isEmpty {
            guard let glyphs = makeTextGlyphs(
                for: text,
                face: face,
                recipe: recipe,
                atlas: atlas,
            ) else {
                return nil
            }
            renderedText = glyphs
        } else {
            renderedText = []
        }

        return RasterInputs(
            leading: leadingGlyph.map {
                // UIStyleCheck: allow - CoreGraphics compose needs UIKit colors bridged from semantic roles.
                (
                    $0,
                    UIColor((presentation.leadingStyle ?? presentation.trailingStyle).visualStyle.color).cgColor,
                )
            },
            trailing: (
                trailingGlyph,
                // UIStyleCheck: allow - CoreGraphics compose needs UIKit colors bridged from semantic roles.
                UIColor(trailingStyle.color).cgColor,
            ),
            textGlyphs: renderedText,
            textTint: UIColor(trailingStyle.color).cgColor,
            shadow: UIColor(TrinketDesign.Colors.Overlay.ink.opacity(0.95)).cgColor,
            layoutDirection: layoutDirection,
            displayScale: scale,
            needsShineMask: needsShineMask,
            maximumDigitWidth: atlas.maximumDigitWidth(face: face, recipe: recipe),
        )
    }

    nonisolated static func render(_ inputs: RasterInputs) -> ComposedRaster? {
        var context = CompositionContext()
        return render(inputs, context: &context)
    }

    nonisolated static func render(_ inputs: RasterInputs, context: inout CompositionContext) -> ComposedRaster? {
        let leading = inputs.leading
        let trailing = inputs.trailing
        let textGlyphs = inputs.textGlyphs
        let textWidth = textGlyphs.reduce(CGFloat(0)) { $0 + $1.width }
        let textHeight = textGlyphs.lazy.map(\.height).max() ?? 0
        let leadingWidth = leading?.0.width ?? 0
        let trailingWidth = trailing.0.width
        let symbolCount = (leading == nil ? 0 : 1) + 1
        let textPresent = textWidth > 0
        let gapCount = max(0, (symbolCount + (textPresent ? 1 : 0)) - 1)
        let contentWidth = leadingWidth + trailingWidth + textWidth + CGFloat(gapCount) * glyphSpacing
        let contentHeight = max(leading?.0.height ?? 0, trailing.0.height, textHeight)
        let pointSize = CGSize(
            width: ceil(contentWidth + horizontalPadding * 2),
            height: ceil(contentHeight + verticalPadding * 2 + shadowOffsetY),
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = inputs.displayScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        let drawings = prepareDrawings(inputs, contentHeight: contentHeight, context: &context)

        guard let cgImage = renderImage(
            drawings,
            renderer: renderer,
            shadow: inputs.shadow,
            maskOnly: false,
        ) else { return nil }
        return ComposedRaster(
            image: cgImage, pointSize: pointSize,
            shineMask: inputs
                .needsShineMask ? renderImage(
                    drawings,
                    renderer: renderer,
                    shadow: inputs.shadow,
                    maskOnly: true,
                ) : nil,
            textWidth: textWidth, maximumDigitWidth: inputs.maximumDigitWidth,
        )
    }

    private nonisolated static func renderImage(
        _ drawings: [GlyphDrawing], renderer: UIGraphicsImageRenderer, shadow: CGColor, maskOnly: Bool,
    ) -> CGImage? {
        renderer.image { _ in
            let context = UIGraphicsGetCurrentContext()
            if !maskOnly {
                context?.setShadow(
                    offset: CGSize(width: 0, height: shadowOffsetY),
                    blur: 1.5,
                    color: shadow,
                )
            }
            context?.beginTransparencyLayer(auxiliaryInfo: nil)

            for drawing in drawings {
                // Preserve the eight source-over outline draws; a flattened bitmap changes blending.
                if !maskOnly, let silhouette = drawing.images.silhouette {
                    for rect in drawing.frame.outlineRects {
                        silhouette.draw(in: rect)
                    }
                }
                drawing.images.image.draw(in: drawing.frame.rect)
            }
            context?.endTransparencyLayer()
            context?.setShadow(offset: .zero, blur: 0, color: nil)
        }.cgImage
    }

    private nonisolated static func prepareDrawings(
        _ inputs: RasterInputs, contentHeight: CGFloat, context: inout CompositionContext,
    ) -> [GlyphDrawing] {
        let origins = horizontalOrigins(
            contentX: horizontalPadding, leadingWidth: inputs.leading?.0.width ?? 0,
            textWidth: inputs.textGlyphs.reduce(CGFloat(0)) { $0 + $1.width },
            trailingWidth: inputs.trailing.0.width, layoutDirection: inputs.layoutDirection,
        )
        let shadow = resolvedColor(inputs.shadow)
        let textTint = resolvedColor(inputs.textTint)
        var drawings: [GlyphDrawing] = []
        drawings.reserveCapacity(inputs.textGlyphs.count + 2)
        func append(_ glyph: CombatFeedbackGlyphAtlas.Glyph, x: CGFloat, tint: UIColor) {
            drawings.append(prepareDrawing(
                glyph: glyph, at: CGPoint(x: x, y: verticalPadding + (contentHeight - glyph.height) / 2),
                tint: tint, outline: shadow, displayScale: inputs.displayScale, composition: &context,
            ))
        }
        if let leading = inputs.leading {
            append(leading.0, x: origins.leadingX, tint: resolvedColor(leading.1))
        }
        var textX = origins.textX
        for glyph in inputs.textGlyphs {
            append(glyph, x: textX, tint: textTint)
            textX += glyph.width
        }
        append(inputs.trailing.0, x: origins.trailingX, tint: resolvedColor(inputs.trailing.1))
        return drawings
    }

    private nonisolated static func resolvedColor(_ color: CGColor) -> UIColor {
        // UIStyleCheck: allow - Reconstruct the immutable semantic color resolved before leaving the main actor.
        UIColor(cgColor: color)
    }

    private nonisolated static func horizontalOrigins(
        contentX: CGFloat,
        leadingWidth: CGFloat,
        textWidth: CGFloat,
        trailingWidth: CGFloat,
        layoutDirection: LayoutDirection,
    ) -> (leadingX: CGFloat, textX: CGFloat, trailingX: CGFloat) {
        let leadingPresent = leadingWidth > 0
        let textPresent = textWidth > 0

        func advance(_ x: inout CGFloat, width: CGFloat, present: Bool) {
            if present {
                x += width + glyphSpacing
            }
        }

        if layoutDirection == .rightToLeft {
            var x = contentX
            let trailingX = x
            x += trailingWidth + glyphSpacing
            let textX = x
            advance(&x, width: textWidth, present: textPresent)
            let leadingX = x
            return (leadingX, textX, trailingX)
        }
        var x = contentX
        let leadingX = x
        advance(&x, width: leadingWidth, present: leadingPresent)
        let textX = x
        advance(&x, width: textWidth, present: textPresent)
        let trailingX = x
        return (leadingX, textX, trailingX)
    }

    private static func makeTextGlyphs(
        for text: String,
        face: CombatFeedbackGlyphAtlas.Face,
        recipe: CombatFeedbackChipStyle,
        atlas: CombatFeedbackGlyphAtlas,
    ) -> [CombatFeedbackGlyphAtlas.Glyph]? {
        let fragments: [String] = if text.allSatisfy({ $0.isNumber || $0 == "+" }) {
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
}
