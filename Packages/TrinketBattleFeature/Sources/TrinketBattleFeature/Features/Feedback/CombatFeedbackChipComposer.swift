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
        var textOnly = false
        var secondaryTextTint: CGColor?
    }

    static func prepareInputs(
        appearance: CombatFeedbackAppearance,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat,
        atlas: CombatFeedbackGlyphAtlas = .shared,
        needsShineMask: Bool = false,
    ) -> RasterInputs? {
        let presentation = appearance.presentation
        let scale = max(1, displayScale)
        let face = CombatFeedbackGlyphAtlas.Face(
            typography: appearance.typography,
            displayScaleHundredths: Int((scale * 100).rounded()),
        )

        var leadingGlyph: CombatFeedbackGlyphAtlas.Glyph?
        if let leadingStyle = presentation.leadingStyle {
            guard let glyph = atlas.glyph(
                .icon(leadingStyle.feedbackIcon),
                face: face,
            ) else {
                return nil
            }
            leadingGlyph = glyph
        }

        let trailingStyle = presentation.trailingStyle.visualStyle
        guard let trailingGlyph = atlas.glyph(
            .icon(presentation.trailingStyle.feedbackIcon),
            face: face,
        ) else {
            return nil
        }

        let renderedText: [CombatFeedbackGlyphAtlas.Glyph]
        if let text = presentation.text, !text.isEmpty {
            guard let glyphs = makeTextGlyphs(
                for: text,
                face: face,
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
            maximumDigitWidth: atlas.maximumDigitWidth(face: face),
            textOnly: presentation.reaction != nil,
            // UIStyleCheck: allow - Raster names blend the two existing keyword semantic colors.
            secondaryTextTint: presentation.reaction.map { UIColor($0.preparationKeyword.visualStyle.color).cgColor },
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
        let trailingWidth = inputs.textOnly ? 0 : trailing.0.width
        let symbolCount = inputs.textOnly ? 0 : (leading == nil ? 0 : 1) + 1
        let textPresent = textWidth > 0
        let gapCount = max(0, (symbolCount + (textPresent ? 1 : 0)) - 1)
        let contentWidth = leadingWidth + trailingWidth + textWidth + CGFloat(gapCount) * glyphSpacing
        let contentHeight = inputs.textOnly ? textHeight : max(leading?.0.height ?? 0, trailing.0.height, textHeight)
        let pointSize = CGSize(
            width: ceil(contentWidth + horizontalPadding * 2),
            height: ceil(contentHeight + verticalPadding * 2 + shadowOffsetY),
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = inputs.displayScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        let drawings = prepareDrawings(inputs, contentHeight: contentHeight, textWidth: textWidth, context: &context)

        guard let cgImage = renderImage(
            drawings,
            renderer: renderer,
            shadow: inputs.shadow,
            maskOnly: false,
            textGradient: inputs.textOnly ? [inputs.secondaryTextTint ?? inputs.textTint, inputs.textTint] : nil,
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
        textGradient: [CGColor]? = nil,
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

            if let colors = textGradient, !maskOnly,
               let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 1]) {
                for drawing in drawings {
                    if let silhouette = drawing.images.silhouette {
                        for rect in drawing.frame.outlineRects {
                            silhouette.draw(in: rect)
                        }
                    }
                }
                context?.beginTransparencyLayer(auxiliaryInfo: nil)
                for drawing in drawings {
                    drawing.images.image.draw(in: drawing.frame.rect)
                }
                context?.saveGState()
                context?.setBlendMode(.sourceIn)
                let right = drawings.map(\.frame.rect.maxX).max() ?? 1
                context?.drawLinearGradient(gradient, start: CGPoint(x: horizontalPadding, y: 0), end: CGPoint(x: right, y: 0), options: [])
                context?.restoreGState()
                context?.endTransparencyLayer()
            } else {
                for drawing in drawings {
                    // Preserve the eight source-over outline draws; a flattened bitmap changes blending.
                    if !maskOnly, let silhouette = drawing.images.silhouette {
                        for rect in drawing.frame.outlineRects {
                            silhouette.draw(in: rect)
                        }
                    }
                    drawing.images.image.draw(in: drawing.frame.rect)
                }
            }
            context?.endTransparencyLayer()
            context?.setShadow(offset: .zero, blur: 0, color: nil)
        }.cgImage
    }

    private nonisolated static func prepareDrawings(
        _ inputs: RasterInputs, contentHeight: CGFloat, textWidth: CGFloat, context: inout CompositionContext,
    ) -> [GlyphDrawing] {
        let origins = horizontalOrigins(
            contentX: horizontalPadding, leadingWidth: inputs.leading?.0.width ?? 0,
            textWidth: textWidth,
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
        var textX = inputs.textOnly ? horizontalPadding : origins.textX
        for glyph in inputs.textGlyphs {
            append(glyph, x: textX, tint: textTint)
            textX += glyph.width
        }
        if !inputs.textOnly {
            append(inputs.trailing.0, x: origins.trailingX, tint: resolvedColor(inputs.trailing.1))
        }
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
            guard let glyph = atlas.glyph(.fragment(fragment), face: face) else {
                return nil
            }
            glyphs.append(glyph)
        }
        return glyphs
    }
}
