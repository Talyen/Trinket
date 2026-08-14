import CoreGraphics
import Foundation
import SwiftUI
import Testing
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
@testable import TrinketBattleFeature

struct CombatFeedbackGlyphAtlasTests {
    @Test @MainActor func glyphAtlasComposesClosedVocabularyAtCommonScales() throws {
        let atlas = CombatFeedbackGlyphAtlas()
        let recipe = CombatFeedbackChipRecipes.chip(for: .directDamage)
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
                "figure.run",
            ] {
                let symbol = try #require(
                    atlas.symbol(named: symbolName, face: face, recipe: recipe)
                )
                #expect(symbol.width > 0)
            }
        }
    }

    @Test @MainActor func concurrentPrewarmsPrepareEachRequestedConfiguration() async {
        let atlas = CombatFeedbackGlyphAtlas()

        async let standard: Void = atlas.prepareBattlePresentationAndWait(
            dynamicTypeSize: .large,
            displayScale: 2
        )
        async let accessible: Void = atlas.prepareBattlePresentationAndWait(
            dynamicTypeSize: .accessibility3,
            displayScale: 3
        )
        _ = await (standard, accessible)

        #expect(atlas.isBattlePresentationPrepared(
            dynamicTypeSize: .large,
            displayScale: 2
        ))
        #expect(atlas.isBattlePresentationPrepared(
            dynamicTypeSize: .accessibility3,
            displayScale: 3
        ))
    }

    @Test @MainActor func clearingAtlasCancelsPendingPreparation() async {
        let atlas = CombatFeedbackGlyphAtlas()
        let warmup = Task { @MainActor in
            await atlas.prepareBattlePresentationAndWait(
                dynamicTypeSize: .accessibility5,
                displayScale: 3
            )
        }
        var spins = 0
        while !atlas.hasPendingBattlePresentationPreparation,
              !atlas.isBattlePresentationPrepared(
                  dynamicTypeSize: .accessibility5,
                  displayScale: 3
              ),
              spins < 10000 {
            await Task.yield()
            spins += 1
        }

        atlas.removeAll()
        await warmup.value

        #expect(!atlas.isBattlePresentationPrepared(
            dynamicTypeSize: .accessibility5,
            displayScale: 3
        ))
    }

    @Test func numericAlphabetComposesHundredsWithoutWholeValueRaster() {
        let label = CombatFeedbackChipLabel.amount(-847)
        #expect(label.atlasFragments == ["8", "4", "7"])
        #expect(Set(label.atlasFragments).isSubset(of: Set(CombatFeedbackChipLabel.numericAtlasFragments)))
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

    @Test @MainActor func chipComposerLayoutsStayStableForTextAndIconChips() throws {
        let samples: [(CombatFeedbackChipLabel, Keyword, CombatFeedbackClass, CGSize)] = [
            (.amount(-12), .physical, .directDamage, CGSize(width: 96, height: 51)),
            (.amount(-12), .physical, .critical, CGSize(width: 117, height: 60)),
            (.word(.applied(.block)), .block, .block, CGSize(width: 119, height: 46)),
            (.word(.triggered(.stun)), .stun, .control, CGSize(width: 107, height: 51)),
        ]

        for (label, keyword, feedbackClass, pinnedSize) in samples {
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
                // Golden layout pinned so a coordinated regression in the composer
                // cannot pass in lockstep with its own metrics.
                #expect(abs(composed.pointSize.width - pinnedSize.width) < 0.01)
                #expect(abs(composed.pointSize.height - pinnedSize.height) < 0.01)
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
}
