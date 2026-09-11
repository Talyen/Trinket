import Foundation
import Testing
import TrinketCore
import TrinketDesignSystem
@testable import TrinketBattleFeature

@Suite(.serialized)
struct CombatFeedbackChipPresentationTests {
    @Test @MainActor func `icon prewarming preserves provider identity and cache reuse`() async throws {
        let atlas = CombatFeedbackGlyphAtlas()
        await atlas.prepareBattlePresentationAndWait(displayScale: 3)
        let face = CombatFeedbackGlyphAtlas.Face(feedbackClass: .buff, displayScaleHundredths: 300)
        let recipe = CombatFeedbackChipStyle.forClass(.buff)

        for keyword in Keyword.allCases {
            let icon = CombatFeedbackChipPresentation.Style.keyword(keyword).feedbackIcon
            guard case .system = icon else {
                Issue.record("Floating feedback requires system symbols")
                continue
            }
            let key = CombatFeedbackGlyphAtlas.IconKey(face: face, icon: icon)
            let first = try #require(atlas.icons[key])
            let cached = try #require(atlas.icon(icon, face: face, recipe: recipe))
            #expect(first.image === cached.image)
        }

        let lucide = try #require(atlas.icon(.lucide("sparkles"), face: face, recipe: recipe))
        let system = try #require(atlas.icon(.system("sparkles"), face: face, recipe: recipe))
        #expect(lucide.image !== system.image)
        atlas.removeAll()
        let rebuilt = try #require(atlas.icon(.lucide("sparkles"), face: face, recipe: recipe))
        #expect(lucide.image !== rebuilt.image)
    }

    @Test func `cleanse uses cleanse leading icon`() {
        let presentation = CombatFeedbackChipPresentation.resolve(
            label: .word(.cleanse(.poison)),
            keyword: .poison,
            visualRole: .keyword,
            feedbackClass: .buff,
        )

        #expect(presentation.leadingStyle == .keyword(.cleanse))
        #expect(presentation.trailingStyle == .keyword(.poison))
        #expect(presentation.text == nil)
    }

    @Test func `purge uses purge leading icon`() {
        let presentation = CombatFeedbackChipPresentation.resolve(
            label: .word(.purge(.poison)),
            keyword: .poison,
            visualRole: .keyword,
            feedbackClass: .buff,
        )

        #expect(presentation.leadingStyle == .keyword(.purge))
        #expect(presentation.trailingStyle == .keyword(.poison))
        #expect(presentation.text == nil)
    }

    @Test @MainActor func `bridge preserves chip display order when cache misses occur`() {
        CombatFeedbackChipBridge.debugReset()
        defer { CombatFeedbackChipBridge.debugReset() }

        let view = CombatFeedbackRasterUIView()
        CombatFeedbackChipBridge.register(
            view,
            combatantID: "hero",
            layoutDirection: .leftToRight,
            displayScale: 3.0,
        )

        let now = Date()
        let item1 = makeTestItem(id: 1, targetID: "hero", amount: 101, availableAt: now)
        let item2 = makeTestItem(id: 2, targetID: "hero", amount: 102, availableAt: now)
        let item3 = makeTestItem(id: 3, targetID: "hero", amount: 103, availableAt: now)

        _ = CombatFeedbackRasterPool.shared.prepare(for: item1, displayScale: 3.0)
        _ = CombatFeedbackRasterPool.shared.prepare(for: item3, displayScale: 3.0)

        CombatFeedbackChipBridge.publish(.replace([item1, item2, item3]))

        #expect(view.debugLastAppliedChips.map(\.id) == [1, 2, 3])
    }

    @Test @MainActor func `multi target availability timer reschedules when earlier target expires`() {
        CombatFeedbackChipBridge.debugReset()
        defer { CombatFeedbackChipBridge.debugReset() }

        let heroView = CombatFeedbackRasterUIView()
        let enemyView = CombatFeedbackRasterUIView()
        CombatFeedbackChipBridge.register(
            heroView,
            combatantID: "hero",
            layoutDirection: .leftToRight,
            displayScale: 3.0,
        )
        CombatFeedbackChipBridge.register(
            enemyView,
            combatantID: "enemy",
            layoutDirection: .leftToRight,
            displayScale: 3.0,
        )

        let now = Date()
        let heroItem = makeTestItem(id: 10, targetID: "hero", amount: 5, availableAt: now.addingTimeInterval(0.5))
        let enemyItem = makeTestItem(id: 20, targetID: "enemy", amount: 8, availableAt: now.addingTimeInterval(1.2))

        CombatFeedbackChipBridge.publish(.insert([heroItem, enemyItem]))
        #expect(CombatFeedbackChipBridge.debugNextAvailabilityTargetID == "hero")

        CombatFeedbackChipBridge.publish(.remove([heroItem.id]))
        #expect(CombatFeedbackChipBridge.debugNextAvailabilityTargetID == "enemy")
        #expect(CombatFeedbackChipBridge.debugNextAvailabilityDate == enemyItem.availableAt)
    }

    @Test @MainActor func `queued chips appear across consecutive deadlines and reset`() async throws {
        CombatFeedbackChipBridge.debugReset()
        defer { CombatFeedbackChipBridge.debugReset() }
        let view = CombatFeedbackRasterUIView()
        CombatFeedbackChipBridge.register(
            view,
            combatantID: "hero",
            layoutDirection: .leftToRight,
            displayScale: 3.0,
        )

        for burst in 0 ..< 2 {
            let now = Date.now
            let firstID = burst * 10 + 1
            let items = (0 ..< 3).map { index in
                makeTestItem(
                    id: firstID + index,
                    targetID: "hero",
                    amount: index + 1,
                    availableAt: now.addingTimeInterval(Double(index) * 0.1),
                )
            }
            CombatFeedbackChipBridge.publish(.insert(items))
            #expect(try await BattleSessionTestSupport.waitUntil(timeout: .milliseconds(800)) {
                view.debugLastAppliedChips.map(\.id) == items.map(\.id)
            })
            CombatFeedbackChipBridge.publish(.reset)
            #expect(view.debugLastAppliedChips.isEmpty)
        }
    }

    @Test @MainActor func `session trim memory footprint clears glyph atlas and dissolve textures`() {
        let session = BattleSession()
        CardDissolveTexture.prewarm()
        session.trimMemoryFootprint(releaseBattleLog: true)
        session.endBattle()
        #expect(session.lifecyclePhase == .idle)
    }

    private func makeTestItem(
        id: Int,
        targetID: String,
        amount: Int,
        availableAt: Date,
    ) -> CombatFeedbackItem {
        CombatFeedbackItem(
            id: id,
            sourceEventIDs: [id],
            actionGroupID: id,
            presentationIndex: 0,
            groupResultCount: 1,
            presentationRole: .headline,
            targetID: targetID,
            feedbackClass: .directDamage,
            keyword: .physical,
            visualRole: .keyword,
            label: .amount(amount),
            availableAt: availableAt,
            expiresAt: availableAt.addingTimeInterval(1.0),
            reactionKind: .damage,
        )
    }
}
