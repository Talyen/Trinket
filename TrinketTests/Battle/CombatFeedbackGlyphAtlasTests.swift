import CoreGraphics
import Foundation
import SwiftUI
import Testing
import TrinketCore
import TrinketDesignSystem
import UIKit
@testable import BattleEngine
@testable import Trinket

struct CombatFeedbackGlyphAtlasTests {
    @Test @MainActor func glyphAtlasComposesClosedVocabularyAtCommonScales() throws {
        let atlas = CombatFeedbackGlyphAtlas()
        let recipe = TrinketMotion.Battle.chip(for: .directDamage)
        for scale in [2.0, 3.0] as [CGFloat] {
            let face = CombatFeedbackGlyphAtlas.Face(
                feedbackClass: .directDamage,
                dynamicTypeSize: .large,
                displayScaleHundredths: Int((scale * 100).rounded())
            )
            for digit in Array("0123456789+-%") {
                let glyph = try #require(atlas.fragment(String(digit), face: face, recipe: recipe))
                #expect(glyph.width > 0)
                #expect(glyph.height > 0)
            }
            for word in CombatFeedbackChipWord.allAtlasCases {
                let glyph = try #require(
                    atlas.fragment(word.displayString, face: face, recipe: recipe)
                )
                #expect(glyph.width > 0)
                #expect(glyph.height > 0)
            }
            let symbol = try #require(
                atlas.symbol(named: "burst.fill", face: face, recipe: recipe)
            )
            #expect(symbol.width > 0)
        }
    }

    @Test @MainActor func chipComposerWarmPathStaysUnderBudget() throws {
        let items = CombatFeedbackPresenter.makeItems(
            from: [makeEvent(id: 42, kind: .ability, amount: 12, keyword: .burn)],
            at: Date(timeIntervalSince1970: 10)
        )
        let canvasItem = CombatFeedbackOverlayPolicy.canvasItems(
            from: CombatFeedbackOverlayPolicy.visibleActionGroups(from: items)
        )[0]
        let style = canvasItem.item.feedbackVisualStyle

        _ = CombatFeedbackChipComposer.compose(
            label: canvasItem.label,
            style: style,
            feedbackClass: canvasItem.item.feedbackClass,
            dynamicTypeSize: .large,
            displayScale: 3
        )
        let started = ContinuousClock.now
        let composed = try #require(CombatFeedbackChipComposer.compose(
            label: canvasItem.label,
            style: style,
            feedbackClass: canvasItem.item.feedbackClass,
            dynamicTypeSize: .large,
            displayScale: 3
        ))
        let elapsed = started.duration(to: .now)
        #expect(composed.pointSize.width > 0)
        #expect(composed.pointSize.height > 0)
        // CI-friendly bound; local warm compose is expected under 1 ms.
        #expect(elapsed < .milliseconds(2))
    }

    @Test @MainActor func chipComposerMatchesReferenceFullStringBake() throws {
        let samples: [(CombatFeedbackChipLabel, Keyword, CombatFeedbackClass)] = [
            (.amount(-12), .physical, .directDamage),
            (.amount(-12), .physical, .critical),
            (.word(.dodge), .dodge, .dodge),
            (.word(.applied(.block)), .block, .block)
        ]

        for (label, keyword, feedbackClass) in samples {
            let item = CombatFeedbackItem(
                id: 1,
                sourceEventIDs: [1],
                actionGroupID: 1,
                presentationIndex: 0,
                groupResultCount: 1,
                targetID: "t",
                feedbackClass: feedbackClass,
                keyword: keyword,
                label: label,
                secondaryText: nil,
                spawnSeed: 1,
                lifetime: 1,
                availableAt: .now,
                expiresAt: .now.addingTimeInterval(1),
                reactionKind: .none
            )
            let style = item.feedbackVisualStyle
            let composed = try #require(CombatFeedbackChipComposer.compose(
                label: label,
                style: style,
                feedbackClass: feedbackClass,
                dynamicTypeSize: .large,
                displayScale: 2
            ))
            let reference = try #require(CombatFeedbackReferenceBaker.bake(
                text: label.displayString,
                style: style,
                feedbackClass: feedbackClass,
                dynamicTypeSize: .large,
                displayScale: 2
            ))
            #expect(abs(composed.pointSize.width - reference.pointSize.width) <= 2)
            #expect(abs(composed.pointSize.height - reference.pointSize.height) <= 2)
            #expect(
                CombatFeedbackReferenceBaker.meanAbsoluteDifference(
                    composed.image,
                    reference.image
                ) < 12
            )
        }
    }

    private func makeEvent(
        id: Int,
        kind: ActionEvent.Kind,
        effectKind: ActionEvent.EffectKind? = nil,
        amount: Int,
        keyword: Keyword,
        targetID: String = "enemy"
    ) -> ActionEvent {
        ActionEvent(
            id: id,
            kind: kind,
            effectKind: effectKind,
            actorID: "hero",
            actorName: "Hero",
            abilityID: "slash",
            abilityName: "Slash",
            targetID: targetID,
            targetName: targetID.capitalized,
            amount: amount,
            keyword: keyword
        )
    }
}

/// Full-string UIKit bake retained only for visual-parity gating against glyph composition.
@MainActor
private enum CombatFeedbackReferenceBaker {
    private static let horizontalPadding: CGFloat = 4
    private static let verticalPadding: CGFloat = 5
    private static let symbolTextSpacing: CGFloat = 8
    private static let shadowOffsetY: CGFloat = 1.5

    struct BakedRaster {
        let image: CGImage
        let pointSize: CGSize
    }

    static func bake(
        text: String,
        style: Keyword.VisualStyle,
        feedbackClass: CombatFeedbackClass,
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) -> BakedRaster? {
        let recipe = TrinketMotion.Battle.chip(for: feedbackClass)
        let scale = max(1, displayScale)
        let font = CombatFeedbackGlyphMetrics.uiFont(
            recipe: recipe,
            dynamicTypeSize: dynamicTypeSize
        )
        // UIStyleCheck: allow - parity baker bridges semantic SwiftUI roles into UIKit.
        let tint = UIColor(style.color)
        let shadow = UIColor(TrinketDesign.Colors.Overlay.ink.opacity(0.95))
        let symbolConfig = UIImage.SymbolConfiguration(font: font)
        guard let symbol = UIImage(
            systemName: style.symbolName,
            withConfiguration: symbolConfig
        )?.withTintColor(tint, renderingMode: .alwaysOriginal) else {
            return nil
        }

        let nsText = text as NSString
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: tint
        ]
        let textSize = nsText.size(withAttributes: textAttributes)
        let symbolSize = symbol.size
        let contentWidth = symbolSize.width + symbolTextSpacing + textSize.width
        let contentHeight = max(symbolSize.height, textSize.height)
        let pointSize = CGSize(
            width: ceil(contentWidth + horizontalPadding * 2),
            height: ceil(contentHeight + verticalPadding * 2 + shadowOffsetY)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        let image = renderer.image { _ in
            let contentOrigin = CGPoint(x: horizontalPadding, y: verticalPadding)
            let symbolOrigin = CGPoint(
                x: contentOrigin.x,
                y: contentOrigin.y + (contentHeight - symbolSize.height) / 2
            )
            let textOrigin = CGPoint(
                x: contentOrigin.x + symbolSize.width + symbolTextSpacing,
                y: contentOrigin.y + (contentHeight - textSize.height) / 2
            )
            let context = UIGraphicsGetCurrentContext()
            context?.setShadow(
                offset: CGSize(width: 0, height: shadowOffsetY),
                blur: 0,
                color: shadow.cgColor
            )
            symbol.draw(at: symbolOrigin)
            nsText.draw(at: textOrigin, withAttributes: textAttributes)
            context?.setShadow(offset: .zero, blur: 0, color: nil)
        }
        guard let cgImage = image.cgImage else { return nil }
        return BakedRaster(image: cgImage, pointSize: pointSize)
    }

    static func meanAbsoluteDifference(_ lhs: CGImage, _ rhs: CGImage) -> Double {
        let width = min(lhs.width, rhs.width)
        let height = min(lhs.height, rhs.height)
        guard width > 0, height > 0 else { return .greatestFiniteMagnitude }

        var left = [UInt8](repeating: 0, count: width * height * 4)
        var right = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let leftContext = CGContext(
            data: &left,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let rightContext = CGContext(
            data: &right,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return .greatestFiniteMagnitude
        }
        leftContext.draw(lhs, in: CGRect(x: 0, y: 0, width: width, height: height))
        rightContext.draw(rhs, in: CGRect(x: 0, y: 0, width: width, height: height))

        var total = 0.0
        let count = width * height * 4
        for index in 0 ..< count {
            total += Double(abs(Int(left[index]) - Int(right[index])))
        }
        return total / Double(count)
    }
}
