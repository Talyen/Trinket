import CoreGraphics
import SwiftUI
import Testing
import TrinketCore
import TrinketDesignSystem
import UIKit
@testable import TrinketBattleFeature

struct CombatFeedbackComposerParityTests {
    @Test(arguments: [CGFloat(1), 2, 3])
    @MainActor func `glyph reuse preserves feedback pixels and masks`(scale: CGFloat) async throws {
        let atlas = CombatFeedbackGlyphAtlas()
        let cases: [(CombatFeedbackClass, CombatFeedbackChipLabel, CombatFeedbackVisualRole, Keyword)] = [
            (.directDamage, .amount(1111), .keyword, .physical),
            (.directDamage, .amount(12345), .keyword, .physical),
            (.critical, .amount(1111), .keyword, .holy),
            (.critical, .amount(12345), .keyword, .holy),
            (.heal, .amount(1111), .beneficialStatus, .health),
            (.buff, .word(.cleanse(.poison)), .keyword, .poison),
        ]
        var reusable = CombatFeedbackRasterPool.PreparedBatch(rasters: [])
        var evicting = CombatFeedbackRasterPool.PreparedBatch(
            rasters: [], composition: .init(maximumSources: 1),
        )
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            for (feedbackClass, label, role, keyword) in cases {
                let presentation = CombatFeedbackChipPresentation.resolve(
                    label: label, keyword: keyword, visualRole: role, feedbackClass: feedbackClass,
                )
                for needsMask in [false, true] {
                    let inputs = try #require(CombatFeedbackChipComposer.prepareInputs(
                        presentation: presentation, feedbackClass: feedbackClass,
                        layoutDirection: direction, displayScale: scale, atlas: atlas, needsShineMask: needsMask,
                    ))
                    (reusable, evicting) = try await Self.compare(
                        inputs, reusable: reusable, evicting: evicting,
                    )
                }
            }
        }
    }

    /// Raster work uses the production worker boundary so timer-driven tests can service the main actor.
    @concurrent
    private nonisolated static func compare(
        _ inputs: CombatFeedbackChipComposer.RasterInputs,
        reusable: CombatFeedbackRasterPool.PreparedBatch,
        evicting: CombatFeedbackRasterPool.PreparedBatch,
    ) async throws -> (CombatFeedbackRasterPool.PreparedBatch, CombatFeedbackRasterPool.PreparedBatch) {
        var context = reusable.composition
        var evictingContext = evicting.composition
        let expected = try #require(ReferenceFeedbackComposer.render(inputs))
        let actual = try #require(CombatFeedbackChipComposer.render(inputs, context: &context))
        #expect(actual.pointSize == expected.pointSize)
        #expect(actual.textWidth == expected.textWidth)
        #expect(actual.maximumDigitWidth == expected.maximumDigitWidth)
        try expectEqualPixels(actual.image, expected.image)
        let reused = try #require(CombatFeedbackChipComposer.render(inputs, context: &context))
        try expectEqualPixels(reused.image, expected.image)
        var transferredContext = CombatFeedbackChipComposer.CompositionContext()
        transferredContext.merge(context)
        let transferred = try #require(CombatFeedbackChipComposer.render(inputs, context: &transferredContext))
        try expectEqualPixels(transferred.image, expected.image)
        let evicted = try #require(CombatFeedbackChipComposer.render(inputs, context: &evictingContext))
        try expectEqualPixels(evicted.image, expected.image)
        if inputs.needsShineMask {
            try expectEqualPixels(#require(actual.shineMask), #require(expected.shineMask))
            try expectEqualPixels(#require(reused.shineMask), #require(expected.shineMask))
            try expectEqualPixels(#require(transferred.shineMask), #require(expected.shineMask))
            try expectEqualPixels(#require(evicted.shineMask), #require(expected.shineMask))
        } else {
            #expect(actual.shineMask == nil)
        }
        return (
            .init(rasters: [], composition: context),
            .init(rasters: [], composition: evictingContext),
        )
    }

    private nonisolated static func expectEqualPixels(_ actual: CGImage, _ expected: CGImage) throws {
        #expect(actual.width == expected.width && actual.height == expected.height)
        #expect(actual.bytesPerRow == expected.bytesPerRow)
        #expect(actual.bitmapInfo == expected.bitmapInfo)
        #expect(actual.bitsPerPixel == expected.bitsPerPixel)
        #expect(actual.bitsPerComponent == expected.bitsPerComponent)
        let actualBytes = try #require(actual.dataProvider?.data) as Data
        let expectedBytes = try #require(expected.dataProvider?.data) as Data
        let pixelBytesPerRow = (actual.width * actual.bitsPerPixel + 7) / 8
        for row in 0 ..< actual.height {
            let start = row * actual.bytesPerRow
            let pixels = start ..< (start + pixelBytesPerRow)
            #expect(actualBytes[pixels] == expectedBytes[pixels])
        }
    }
}

/// Frozen pre-optimization renderer: changing this oracle would hide fidelity regressions.
private enum ReferenceFeedbackComposer {
    private static let horizontalPadding: CGFloat = 4
    private static let verticalPadding: CGFloat = 5
    private static let glyphSpacing: CGFloat = 8
    private static let shadowOffsetY: CGFloat = 1.5

    nonisolated static func render(_ inputs: CombatFeedbackChipComposer.RasterInputs) -> CombatFeedbackChipComposer.ComposedRaster? {
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

        guard let cgImage = renderImage(inputs, pointSize: pointSize, contentHeight: contentHeight, maskOnly: false) else { return nil }
        return CombatFeedbackChipComposer.ComposedRaster(
            image: cgImage, pointSize: pointSize,
            shineMask: inputs
                .needsShineMask ? renderImage(inputs, pointSize: pointSize, contentHeight: contentHeight, maskOnly: true) : nil,
            textWidth: textWidth, maximumDigitWidth: inputs.maximumDigitWidth,
        )
    }

    private nonisolated static func renderImage(
        _ inputs: CombatFeedbackChipComposer.RasterInputs, pointSize: CGSize, contentHeight: CGFloat, maskOnly: Bool,
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
        let format = UIGraphicsImageRendererFormat()
        format.scale = inputs.displayScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
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

            if let leading {
                let origin = CGPoint(
                    x: origins.leadingX,
                    y: contentOrigin.y + (contentHeight - leading.0.height) / 2,
                )
                draw(glyph: leading.0, at: origin, tint: leading.1, outline: maskOnly ? nil : shadow, displayScale: displayScale)
            }

            var textX = origins.textX
            for glyph in textGlyphs {
                let origin = CGPoint(
                    x: textX,
                    y: contentOrigin.y + (contentHeight - glyph.height) / 2,
                )
                draw(glyph: glyph, at: origin, tint: textTint, outline: maskOnly ? nil : shadow, displayScale: displayScale)
                textX += glyph.width
            }

            let trailingOrigin = CGPoint(
                x: origins.trailingX,
                y: contentOrigin.y + (contentHeight - trailing.0.height) / 2,
            )
            draw(glyph: trailing.0, at: trailingOrigin, tint: trailing.1, outline: maskOnly ? nil : shadow, displayScale: displayScale)
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

    private nonisolated static func draw(
        glyph: CombatFeedbackGlyphAtlas.Glyph,
        at origin: CGPoint,
        tint: UIColor,
        outline: UIColor?,
        displayScale: CGFloat,
    ) {
        let rect = CGRect(origin: origin, size: CGSize(width: glyph.width, height: glyph.height))
        let tinted = UIImage(cgImage: glyph.image, scale: displayScale, orientation: .up)
            .withTintColor(tint, renderingMode: .alwaysOriginal)
        if let outline {
            let silhouette = tinted.withTintColor(outline, renderingMode: .alwaysOriginal)
            for step in 0 ..< 8 {
                let angle = CGFloat(step) * .pi / 4
                silhouette.draw(in: rect.offsetBy(dx: cos(angle), dy: sin(angle)))
            }
        }
        tinted.draw(in: rect)
    }
}
