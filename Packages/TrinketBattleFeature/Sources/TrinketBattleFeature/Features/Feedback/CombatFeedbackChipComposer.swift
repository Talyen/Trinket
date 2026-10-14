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
            maximumDigitWidth: needsShineMask ? atlas.maximumDigitWidth(face: face, recipe: recipe) : 0,
        )
    }

    struct CompositionContext {
        fileprivate var tintedGlyphs: [ObjectIdentifier: [TintedGlyph]] = [:]
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
            }
        }
    }

    fileprivate struct TintedGlyph {
        // Keep identity valid while cached, even after atlas or raster-pool replacement.
        let source: CGImage
        let displayScale: CGFloat
        let color: CGColor
        let outline: CGColor?
        let image: UIImage
        let silhouette: UIImage?
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

        guard let cgImage = renderImage(
            inputs,
            renderer: renderer,
            contentHeight: contentHeight,
            maskOnly: false,
            composition: &context,
        ) else { return nil }
        return ComposedRaster(
            image: cgImage, pointSize: pointSize,
            shineMask: inputs
                .needsShineMask ? renderImage(
                    inputs,
                    renderer: renderer,
                    contentHeight: contentHeight,
                    maskOnly: true,
                    composition: &context,
                ) : nil,
            textWidth: textWidth, maximumDigitWidth: inputs.maximumDigitWidth,
        )
    }

    private nonisolated static func renderImage(
        _ inputs: RasterInputs, renderer: UIGraphicsImageRenderer, contentHeight: CGFloat, maskOnly: Bool,
        composition: inout CompositionContext,
    ) -> CGImage? {
        let leading = inputs.leading.map { ($0.0, resolvedColor($0.1)) }
        let trailing = (inputs.trailing.0, resolvedColor(inputs.trailing.1))
        let textGlyphs = inputs.textGlyphs
        let textTint = resolvedColor(inputs.textTint)
        let shadow = resolvedColor(inputs.shadow)
        let displayScale = inputs.displayScale
        let layoutDirection = inputs.layoutDirection
        let leadingWidth = leading?.0.width ?? 0
        let trailingWidth = trailing.0.width
        let textWidth = textGlyphs.reduce(CGFloat(0)) { $0 + $1.width }
        return renderer.image { _ in
            let contentOrigin = CGPoint(x: horizontalPadding, y: verticalPadding)
            let origins = horizontalOrigins(
                contentX: contentOrigin.x,
                leadingWidth: leadingWidth,
                textWidth: textWidth,
                trailingWidth: trailingWidth,
                layoutDirection: layoutDirection,
            )

            let context = UIGraphicsGetCurrentContext()
            if !maskOnly {
                context?.setShadow(
                    offset: CGSize(width: 0, height: shadowOffsetY),
                    blur: 1.5,
                    color: shadow.cgColor,
                )
            }
            context?.beginTransparencyLayer(auxiliaryInfo: nil)

            func drawContent(_ glyph: CombatFeedbackGlyphAtlas.Glyph, x: CGFloat, tint: UIColor) {
                draw(
                    glyph: glyph,
                    at: CGPoint(x: x, y: contentOrigin.y + (contentHeight - glyph.height) / 2),
                    tint: tint, outline: maskOnly ? nil : shadow, displayScale: displayScale,
                    composition: &composition,
                )
            }
            if let leading {
                drawContent(leading.0, x: origins.leadingX, tint: leading.1)
            }
            var textX = origins.textX
            for glyph in textGlyphs {
                drawContent(glyph, x: textX, tint: textTint)
                textX += glyph.width
            }
            drawContent(trailing.0, x: origins.trailingX, tint: trailing.1)
            context?.endTransparencyLayer()
            context?.setShadow(offset: .zero, blur: 0, color: nil)
        }.cgImage
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

    private nonisolated static func draw(
        glyph: CombatFeedbackGlyphAtlas.Glyph,
        at origin: CGPoint,
        tint: UIColor,
        outline: UIColor?,
        displayScale: CGFloat,
        composition: inout CompositionContext,
    ) {
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
        if outline != nil, let silhouette = images.silhouette {
            for offset in outlineOffsets {
                silhouette.draw(in: rect.offsetBy(dx: offset.x, dy: offset.y))
            }
        }
        images.image.draw(in: rect)
    }
}

private extension CombatFeedbackChipComposer {
    nonisolated static let outlineOffsets: [CGPoint] = (0 ..< 8).map { step in
        let angle = CGFloat(step) * .pi / 4
        return CGPoint(x: cos(angle), y: sin(angle))
    }
}
