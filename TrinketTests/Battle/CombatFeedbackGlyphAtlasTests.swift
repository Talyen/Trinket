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
            for digit in Array("0123456789%") {
                let glyph = try #require(atlas.fragment(String(digit), face: face, recipe: recipe))
                #expect(glyph.width > 0)
                #expect(glyph.height > 0)
            }
            for word in CombatFeedbackChipWord.textAtlasCases {
                let text = try #require(word.composeText)
                let glyph = try #require(
                    atlas.fragment(text, face: face, recipe: recipe)
                )
                #expect(glyph.width > 0)
                #expect(glyph.height > 0)
            }
            for symbolName in [
                "burst.fill",
                "arrowshape.up.fill",
                "arrowshape.down.fill",
                "sparkles",
                "hourglass.bottomhalf.filled",
                "figure.run"
            ] {
                let symbol = try #require(
                    atlas.symbol(named: symbolName, face: face, recipe: recipe)
                )
                #expect(symbol.width > 0)
            }
        }
    }

    @Test @MainActor func chipComposerWarmPathStaysUnderBudget() throws {
        let items = CombatFeedbackPresenter.makeItems(
            from: [makeEvent(id: 42, kind: .abilityDamage, amount: 12, keyword: .burn)],
            at: Date(timeIntervalSince1970: 10)
        )
        let canvasItem = try #require(CombatFeedbackOverlayPolicy.canvasItems(
            from: CombatFeedbackOverlayPolicy.visibleActionGroups(from: items)
        ).first)
        let presentation = canvasItem.item.chipPresentation

        _ = CombatFeedbackChipComposer.compose(
            presentation: presentation,
            feedbackClass: canvasItem.item.feedbackClass,
            dynamicTypeSize: .large,
            displayScale: 3
        )
        var samples: [Duration] = []
        samples.reserveCapacity(20)
        for _ in 0 ..< 20 {
            let started = ContinuousClock.now
            let composed = try #require(CombatFeedbackChipComposer.compose(
                presentation: presentation,
                feedbackClass: canvasItem.item.feedbackClass,
                dynamicTypeSize: .large,
                displayScale: 3
            ))
            samples.append(started.duration(to: .now))
            #expect(composed.pointSize.width > 0)
            #expect(composed.pointSize.height > 0)
        }

        let sortedSamples = samples.sorted()
        let upperMedian = sortedSamples[sortedSamples.count / 2]
        let worst = try #require(sortedSamples.last)
        // CI-tolerant ceilings (composer warm-path product target remains ~1 ms).
        #expect(upperMedian < .milliseconds(5))
        #expect(worst < .milliseconds(15))
    }

    @Test @MainActor func numericAlphabetComposesHundredsWithoutWholeValueRaster() throws {
        let label = CombatFeedbackChipLabel.amount(-847)
        #expect(label.atlasFragments == ["8", "4", "7"])
        #expect(Set(label.atlasFragments).isSubset(of: Set(CombatFeedbackChipLabel.numericAtlasFragments)))

        let composed = try #require(CombatFeedbackChipComposer.compose(
            presentation: CombatFeedbackChipPresentation.resolve(
                label: label,
                keyword: .physical,
                visualRole: .keyword,
                feedbackClass: .directDamage
            ),
            feedbackClass: .directDamage,
            dynamicTypeSize: .large,
            displayScale: 3
        ))
        #expect(composed.pointSize.width > 0)
        #expect(composed.pointSize.height > 0)
    }

    @Test func atlasWordVocabularyMatchesIconFirstFaces() {
        #expect(CombatFeedbackGlyphAtlas.wordAtlasCases(for: .emphasis).isEmpty)
        #expect(CombatFeedbackGlyphAtlas.wordAtlasCases(for: .normal).contains(.triggered(.stun)))
        #expect(CombatFeedbackGlyphAtlas.wordAtlasCases(for: .normal).contains(.applied(.block)))
        #expect(!CombatFeedbackGlyphAtlas.wordAtlasCases(for: .normal).contains(.dodge))
        #expect(!CombatFeedbackGlyphAtlas.wordAtlasCases(for: .normal).contains(.cleanse(.bleed)))
        #expect(!CombatFeedbackGlyphAtlas.wordAtlasCases(for: .normal).contains(.halve(.block)))
        #expect(!CombatFeedbackGlyphAtlas.wordAtlasCases(for: .normal).contains(.status(.criticalUp)))
        #expect(!CombatFeedbackGlyphAtlas.wordAtlasCases(for: .normal).contains(.critical))
        #expect(!CombatFeedbackGlyphAtlas.wordAtlasCases(for: .normal).contains(.plain(.deathsDoor)))
    }

    @Test @MainActor func chipComposerMatchesReferenceBakeForTextAndIconChips() throws {
        let samples: [(CombatFeedbackChipLabel, Keyword, CombatFeedbackClass)] = [
            (.amount(-12), .physical, .directDamage),
            (.amount(-12), .physical, .critical),
            (.word(.applied(.block)), .block, .block),
            (.word(.triggered(.stun)), .stun, .control)
        ]

        for (label, keyword, feedbackClass) in samples {
            let presentation = CombatFeedbackChipPresentation.resolve(
                label: label,
                keyword: keyword,
                visualRole: .keyword,
                feedbackClass: feedbackClass
            )
            for layoutDirection in [LayoutDirection.leftToRight, .rightToLeft] {
                let composed = try #require(CombatFeedbackChipComposer.compose(
                    presentation: presentation,
                    feedbackClass: feedbackClass,
                    dynamicTypeSize: .large,
                    layoutDirection: layoutDirection,
                    displayScale: 2
                ))
                let reference = try #require(CombatFeedbackReferenceBaker.bake(
                    presentation: presentation,
                    feedbackClass: feedbackClass,
                    dynamicTypeSize: .large,
                    layoutDirection: layoutDirection,
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
    }

    @Test @MainActor func dualTintCleanseAndIconOnlyDodgeCompose() throws {
        let cleanse = try #require(CombatFeedbackChipComposer.compose(
            presentation: CombatFeedbackChipPresentation.resolve(
                label: .word(.cleanse(.bleed)),
                keyword: .bleed,
                visualRole: .keyword,
                feedbackClass: .buff
            ),
            feedbackClass: .buff,
            dynamicTypeSize: .large,
            displayScale: 2
        ))
        #expect(cleanse.pointSize.width > 0)

        let dodge = try #require(CombatFeedbackChipComposer.compose(
            presentation: CombatFeedbackChipPresentation.resolve(
                label: .word(.dodge),
                keyword: .dodge,
                visualRole: .keyword,
                feedbackClass: .dodge
            ),
            feedbackClass: .dodge,
            dynamicTypeSize: .large,
            displayScale: 2
        ))
        #expect(dodge.pointSize.width > 0)

        let deathsDoor = try #require(CombatFeedbackChipComposer.compose(
            presentation: CombatFeedbackChipPresentation.resolve(
                label: .word(.plain(.deathsDoor)),
                keyword: .deathsDoor,
                visualRole: .keyword,
                feedbackClass: .deathsDoor
            ),
            feedbackClass: .deathsDoor,
            dynamicTypeSize: .large,
            displayScale: 2
        ))
        #expect(deathsDoor.pointSize.width > 0)
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
    private static let glyphSpacing: CGFloat = 8
    private static let shadowOffsetY: CGFloat = 1.5

    struct BakedRaster {
        let image: CGImage
        let pointSize: CGSize
    }

    static func bake(
        presentation: CombatFeedbackChipPresentation,
        feedbackClass: CombatFeedbackClass,
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat
    ) -> BakedRaster? {
        let recipe = TrinketMotion.Battle.chip(for: feedbackClass)
        let scale = max(1, displayScale)
        let font = CombatFeedbackGlyphMetrics.uiFont(
            recipe: recipe,
            dynamicTypeSize: dynamicTypeSize
        )
        guard let symbols = loadSymbols(presentation: presentation, font: font) else {
            return nil
        }
        // UIStyleCheck: allow - parity baker bridges semantic SwiftUI roles into UIKit.
        let trailingTint = UIColor(presentation.trailingTint.color)
        let text = presentation.text ?? ""
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: trailingTint
        ]
        let nsText = text as NSString
        let textSize = text.isEmpty ? CGSize.zero : nsText.size(withAttributes: textAttributes)
        let leadingSize = symbols.leading?.size ?? .zero
        let trailingSize = symbols.trailing.size
        let symbolCount = (symbols.leading == nil ? 0 : 1) + 1
        let gapCount = max(0, (symbolCount + (textSize.width > 0 ? 1 : 0)) - 1)
        let contentWidth = leadingSize.width + trailingSize.width + textSize.width
            + CGFloat(gapCount) * glyphSpacing
        let contentHeight = max(leadingSize.height, trailingSize.height, textSize.height)
        let pointSize = CGSize(
            width: ceil(contentWidth + horizontalPadding * 2),
            height: ceil(contentHeight + verticalPadding * 2 + shadowOffsetY)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        let image = renderer.image { _ in
            drawChip(
                symbols: symbols,
                nsText: nsText,
                textAttributes: textAttributes,
                textSize: textSize,
                contentHeight: contentHeight,
                layoutDirection: layoutDirection
            )
        }
        guard let cgImage = image.cgImage else { return nil }
        return BakedRaster(image: cgImage, pointSize: pointSize)
    }

    private static func loadSymbols(
        presentation: CombatFeedbackChipPresentation,
        font: UIFont
    ) -> (leading: UIImage?, trailing: UIImage)? {
        // UIStyleCheck: allow - parity baker bridges semantic SwiftUI roles into UIKit.
        let trailingTint = UIColor(presentation.trailingTint.color)
        let leadingTint = UIColor((presentation.leadingTint ?? presentation.trailingTint).color)
        let symbolConfig = UIImage.SymbolConfiguration(font: font)
        var leadingImage: UIImage?
        if let leadingName = presentation.leadingSymbolName {
            guard let image = UIImage(
                systemName: leadingName,
                withConfiguration: symbolConfig
            )?.withTintColor(leadingTint, renderingMode: .alwaysOriginal) else {
                return nil
            }
            leadingImage = image
        }
        guard let trailingImage = UIImage(
            systemName: presentation.trailingSymbolName,
            withConfiguration: symbolConfig
        )?.withTintColor(trailingTint, renderingMode: .alwaysOriginal) else {
            return nil
        }
        return (leadingImage, trailingImage)
    }

    private static func drawChip(
        symbols: (leading: UIImage?, trailing: UIImage),
        nsText: NSString,
        textAttributes: [NSAttributedString.Key: Any],
        textSize: CGSize,
        contentHeight: CGFloat,
        layoutDirection: LayoutDirection
    ) {
        let contentOrigin = CGPoint(x: horizontalPadding, y: verticalPadding)
        let leadingSize = symbols.leading?.size ?? .zero
        let trailingSize = symbols.trailing.size
        let origins = horizontalOrigins(
            contentX: contentOrigin.x,
            leadingWidth: leadingSize.width,
            textWidth: textSize.width,
            trailingWidth: trailingSize.width,
            layoutDirection: layoutDirection
        )
        // UIStyleCheck: allow - parity baker bridges semantic SwiftUI roles into UIKit.
        let shadow = UIColor(TrinketDesign.Colors.Overlay.ink.opacity(0.95))
        let context = UIGraphicsGetCurrentContext()
        context?.setShadow(
            offset: CGSize(width: 0, height: shadowOffsetY),
            blur: 0,
            color: shadow.cgColor
        )
        if let leadingImage = symbols.leading {
            leadingImage.draw(at: CGPoint(
                x: origins.leadingX,
                y: contentOrigin.y + (contentHeight - leadingSize.height) / 2
            ))
        }
        if textSize.width > 0 {
            nsText.draw(
                at: CGPoint(
                    x: origins.textX,
                    y: contentOrigin.y + (contentHeight - textSize.height) / 2
                ),
                withAttributes: textAttributes
            )
        }
        symbols.trailing.draw(at: CGPoint(
            x: origins.trailingX,
            y: contentOrigin.y + (contentHeight - trailingSize.height) / 2
        ))
        context?.setShadow(offset: .zero, blur: 0, color: nil)
    }

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
