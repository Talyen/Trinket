import CoreGraphics
import Foundation
import Testing
import TrinketCore
import TrinketDesignSystem
@testable import TrinketBattleFeature

/// Pure resolution tests: no shared raster pool/atlas caches, so they
/// run in parallel with the rest of the package.
struct CombatFeedbackChipPresentationTests {
    @Test @MainActor func `icon prewarming preserves shared keyword identity and cache reuse`() async throws {
        let atlas = CombatFeedbackGlyphAtlas()
        await atlas.prepareBattlePresentationAndWait(displayScale: 3)
        let face = CombatFeedbackGlyphAtlas.Face(feedbackClass: .buff, displayScaleHundredths: 300)
        let recipe = CombatFeedbackChipStyle.forClass(.buff)

        for keyword in Keyword.allCases {
            let icon = CombatFeedbackChipPresentation.Style.keyword(keyword).feedbackIcon
            #expect(icon == keyword.visualStyle.icon)
            let key = CombatFeedbackGlyphAtlas.IconKey(face: face, icon: icon)
            let first = try #require(atlas.icons[key])
            let cached = try #require(atlas.icon(icon, face: face, recipe: recipe))
            #expect(first.image === cached.image)
        }

        let system = try #require(atlas.icon(.system("sparkles"), face: face, recipe: recipe))
        atlas.removeAll()
        let rebuilt = try #require(atlas.icon(.system("sparkles"), face: face, recipe: recipe))
        #expect(system.image !== rebuilt.image)
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
}

/// Tests touching shared raster pool/atlas caches stay serialized;
/// the pure resolution tests above run in parallel.
@Suite(.serialized)
struct CombatFeedbackBridgeSerializedTests {
    @Test @MainActor func `live chips survive raster churn remount and updates without stale pixels or retained rasters`() throws {
        let pool = CombatFeedbackRasterPool(capacity: 1)
        let bridge = CombatFeedbackChipBridge(rasterPool: pool)
        let view = CombatFeedbackRasterUIView()
        bridge.register(view, combatantID: "hero", layoutDirection: .leftToRight, displayScale: 1)
        defer {
            bridge.publish(.reset)
            bridge.unregister(view)
        }
        let now = Date.now
        var item = makeTestItem(id: 1, targetID: "hero", amount: 11223, availableAt: now)
        item.expiresAt = now.addingTimeInterval(60)
        item.pausedAt = now
        weak var original = pool.prepare(for: item, displayScale: 1)
        let originalImage = try #require(original?.image)
        bridge.publish(.replace([item]))
        _ = pool.prepare(for: makeTestItem(id: 2, targetID: "hero", amount: 44556, availableAt: now), displayScale: 1)
        #expect(pool.cachedRaster(for: item, displayScale: 1) == nil)
        let builds = pool.snapshot().buildCount
        bridge.unregister(view)
        view.apply(chips: [])
        let fragment = CombatFeedbackRasterUIView()
        defer { bridge.unregister(fragment) }
        bridge.register(fragment, combatantID: "hero", layoutDirection: .leftToRight, displayScale: 1)
        item.sourceEventIDs.insert(3)
        bridge.publish(.replace([item]))
        #expect(pool.snapshot().buildCount == builds)
        #expect(fragment.layer.sublayers?.contains { ($0.contents as? CGImage) === originalImage } == true)
        #expect(fragment.debugLastAppliedChips == [item])

        item.label = .amount(77889)
        bridge.publish(.replace([item]))
        let updatedImage = try #require(pool.cachedRaster(for: item, displayScale: 1)?.image)
        #expect(updatedImage !== originalImage)
        #expect(fragment.layer.sublayers?.contains { ($0.contents as? CGImage) === updatedImage } == true)
        #expect(original == nil)
        weak var updated = pool.cachedRaster(for: item, displayScale: 1)
        pool.removeAll()
        #expect(updated != nil)
        bridge.publish(.reset)
        #expect(updated == nil)
        #expect(fragment.debugLastAppliedChips.isEmpty)
    }

    @Test @MainActor func `replacement refreshes changed targets and shares split host rasters`() throws {
        let bridge = CombatFeedbackChipBridge()
        let hero = CombatFeedbackRasterUIView()
        let enemy = CombatFeedbackRasterUIView()
        let enemyFragment = CombatFeedbackRasterUIView()
        for (view, id) in [(hero, "hero"), (enemy, "enemy"), (enemyFragment, "enemy")] {
            bridge.register(view, combatantID: id, layoutDirection: .leftToRight, displayScale: 1)
        }
        let now = Date.now
        let heroItem = makeTestItem(id: 1, targetID: "hero", amount: 3001, availableAt: now)
        var enemyItem = makeTestItem(id: 2, targetID: "enemy", amount: 3002, availableAt: now)
        bridge.publish(.replace([heroItem, enemyItem]))
        let heroCount = hero.debugApplyCount
        let enemyCount = enemy.debugApplyCount
        bridge.publish(.replace([enemyItem, heroItem]))
        #expect(hero.debugApplyCount == heroCount && enemy.debugApplyCount == enemyCount)

        enemyItem.label = .amount(3003)
        _ = try #require(CombatFeedbackRasterPool.shared.prepare(for: enemyItem, displayScale: 1))
        CombatFeedbackRasterPool.shared.resetDiagnostics()
        bridge.publish(.replace([heroItem, enemyItem]))
        #expect(hero.debugApplyCount == heroCount)
        #expect(enemy.debugApplyCount == enemyCount + 1)
        #expect(enemyFragment.debugLastAppliedChips == [enemyItem])
        #expect(enemy.debugLastAppliedChips == [enemyItem])
        #expect(CombatFeedbackRasterPool.shared.snapshot().hitCount == 1)

        enemyItem.pausedAt = now
        bridge.publish(.replace([heroItem, enemyItem]))
        #expect(enemy.debugLastAppliedChips.first?.pausedAt == now)
        #expect(enemyFragment.debugLastAppliedChips.first?.pausedAt == now)
        #expect(!enemy.debugIsMotionRegistered && !enemyFragment.debugIsMotionRegistered)
        enemyItem.pausedAt = nil
        enemyItem.expiresAt = now.addingTimeInterval(2)
        bridge.publish(.replace([heroItem, enemyItem]))
        #expect(enemy.debugIsMotionRegistered && enemyFragment.debugIsMotionRegistered)
        #expect(hero.debugApplyCount == heroCount)

        let queued = makeTestItem(id: 3, targetID: "enemy", amount: 3004, availableAt: now.addingTimeInterval(10))
        bridge.publish(.replace([heroItem, enemyItem, queued]))
        let queuedCount = enemy.debugApplyCount
        bridge.publish(.replace([heroItem, enemyItem, queued]))
        #expect(enemy.debugApplyCount == queuedCount)
        #expect(bridge.debugNextAvailabilityDate == queued.availableAt)
        bridge.publish(.replace([heroItem]))
        #expect(enemy.debugLastAppliedChips.isEmpty && enemyFragment.debugLastAppliedChips.isEmpty)
        #expect(bridge.debugNextAvailabilityDate == nil)
        bridge.publish(.reset)
    }

    @Test @MainActor func `evicted stationary results cannot reappear after a publication or host remount`() {
        var evicted: Set<Int> = []
        let bridge = CombatFeedbackChipBridge { evicted.formUnion($0) }
        let view = CombatFeedbackRasterUIView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        bridge.register(view, combatantID: "hero", layoutDirection: .leftToRight, displayScale: 1)
        let tallFragment = CombatFeedbackRasterUIView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        bridge.register(tallFragment, combatantID: "hero", layoutDirection: .leftToRight, displayScale: 1)
        let now = Date.now
        let items = (1 ... 3).map { id in
            var item = makeTestItem(id: id, targetID: "hero", amount: 10, availableAt: now)
            item.reservedDigitCount = 3
            item.expiresAt = now.addingTimeInterval(CombatFeedbackMotionSampler.lifetime)
            return item
        }
        bridge.publish(.replace(items))
        #expect(evicted.isEmpty)
        view.debugTickMotion(at: now.addingTimeInterval(0.65))
        #expect(!evicted.isEmpty)
        let survivingIDs = Set(items.map(\.id)).subtracting(evicted)
        #expect(survivingIDs.contains(3))
        #expect(view.debugVisibleChipIDs == survivingIDs)
        bridge.publish(.replace(items))
        #expect(view.debugVisibleChipIDs == survivingIDs)
        #expect(tallFragment.debugVisibleChipIDs == survivingIDs)
        bridge.unregister(view)
        let replacement = CombatFeedbackRasterUIView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        bridge.register(replacement, combatantID: "hero", layoutDirection: .leftToRight, displayScale: 1)
        #expect(replacement.debugVisibleChipIDs == survivingIDs)
        bridge.publish(.reset)
        #expect(replacement.debugVisibleChipIDs.isEmpty && tallFragment.debugVisibleChipIDs.isEmpty)
    }

    @Test @MainActor func `bridge preserves chip display order when cache misses occur`() {
        let bridge = CombatFeedbackChipBridge()

        let view = CombatFeedbackRasterUIView()
        bridge.register(
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

        bridge.publish(.replace([item1, item2, item3]))

        #expect(view.debugLastAppliedChips.map(\.id) == [1, 2, 3])
    }

    @Test @MainActor func `multi target availability timer reschedules when earlier target expires`() {
        let bridge = CombatFeedbackChipBridge()

        let heroView = CombatFeedbackRasterUIView()
        let enemyView = CombatFeedbackRasterUIView()
        bridge.register(
            heroView,
            combatantID: "hero",
            layoutDirection: .leftToRight,
            displayScale: 3.0,
        )
        bridge.register(
            enemyView,
            combatantID: "enemy",
            layoutDirection: .leftToRight,
            displayScale: 3.0,
        )

        let now = Date()
        let heroItem = makeTestItem(id: 10, targetID: "hero", amount: 5, availableAt: now.addingTimeInterval(0.5))
        let enemyItem = makeTestItem(id: 20, targetID: "enemy", amount: 8, availableAt: now.addingTimeInterval(0.65))

        bridge.publish(.replace([heroItem, enemyItem]))
        #expect(bridge.debugNextAvailabilityTargetID == "hero")

        bridge.publish(.remove([heroItem.id]))
        #expect(bridge.debugNextAvailabilityTargetID == "enemy")
        #expect(bridge.debugNextAvailabilityDate == enemyItem.availableAt)
    }

    @Test @MainActor func `queued chips appear across consecutive deadlines and reset`() async throws {
        let bridge = CombatFeedbackChipBridge()
        let view = CombatFeedbackRasterUIView()
        bridge.register(
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
            bridge.publish(.replace(items))
            // 2 s budget: the last chip needs 0.2 s of timer latency and this
            // suite runs parallel with raster-prewarm CPU work.
            #expect(try await BattleSessionTestSupport.waitUntil(timeout: .seconds(2)) {
                view.debugLastAppliedChips.map(\.id) == items.map(\.id)
            })
            bridge.publish(.reset)
            #expect(view.debugLastAppliedChips.isEmpty)
        }
    }

    @Test @MainActor func `session trim memory footprint clears glyph atlas and dissolve textures`() throws {
        let session = BattleSession()
        let atlas = CombatFeedbackGlyphAtlas.shared
        let face = CombatFeedbackGlyphAtlas.Face(feedbackClass: .buff, displayScaleHundredths: 100)
        _ = try #require(atlas.icon(.system("sparkles"), face: face, recipe: .forClass(.buff)))
        let mask = try #require(CardDissolveTexture.thresholdMaskImage(progress: 0.2))
        #expect(!atlas.icons.isEmpty)
        session.trimMemoryFootprint(releaseBattleLog: true)
        #expect(atlas.icons.isEmpty)
        #expect(CardDissolveTexture.thresholdMaskImage(progress: 0.2) !== mask)
    }

    @Test @MainActor func `independent sessions isolate colliding chips eviction deadlines and teardown`() {
        let battle = BattleSession()
        let preview = BattleSession()
        let battleView = CombatFeedbackRasterUIView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        let previewView = CombatFeedbackRasterUIView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        battle.feedback.chipBridge.register(battleView, combatantID: "hero", layoutDirection: .leftToRight, displayScale: 1)
        preview.feedback.chipBridge.register(previewView, combatantID: "hero", layoutDirection: .leftToRight, displayScale: 1)
        let now = Date.now
        battle.feedback.activeItems = (1 ... 3).map {
            var item = makeTestItem(id: $0, targetID: "hero", amount: $0, availableAt: now)
            item.reservedDigitCount = 3
            item.expiresAt = now.addingTimeInterval(CombatFeedbackMotionSampler.lifetime)
            return item
        }
        preview.feedback.activeItems = (1 ... 3).map {
            makeTestItem(id: $0, targetID: "hero", amount: $0 * 10, availableAt: now)
        }
        battle.feedback.noteItemsChanged()
        preview.feedback.noteItemsChanged()
        #expect(battleView.debugLastAppliedChips.map(\.label) == battle.feedback.activeItems.map(\.label))
        #expect(previewView.debugLastAppliedChips.map(\.label) == preview.feedback.activeItems.map(\.label))

        battleView.debugTickMotion(at: now.addingTimeInterval(0.65))
        #expect(!battle.feedback.evictedItemIDs.isEmpty)
        #expect(preview.feedback.evictedItemIDs.isEmpty)
        preview.feedback.noteItemsChanged()
        #expect(previewView.debugVisibleChipIDs == [1, 2, 3])

        let battleQueued = makeTestItem(id: 4, targetID: "hero", amount: 4, availableAt: now.addingTimeInterval(10))
        let previewQueued = makeTestItem(id: 4, targetID: "hero", amount: 40, availableAt: now.addingTimeInterval(20))
        battle.feedback.activeItems.append(battleQueued)
        preview.feedback.activeItems.append(previewQueued)
        battle.feedback.noteItemsChanged()
        preview.feedback.noteItemsChanged()
        #expect(battle.feedback.chipBridge.debugNextAvailabilityDate == battleQueued.availableAt)
        #expect(preview.feedback.chipBridge.debugNextAvailabilityDate == previewQueued.availableAt)

        battle.clearRunState()
        #expect(battleView.debugVisibleChipIDs.isEmpty)
        #expect(previewView.debugVisibleChipIDs == [1, 2, 3])
        #expect(preview.feedback.chipBridge.debugNextAvailabilityDate == previewQueued.availableAt)
        let remountedPreview = CombatFeedbackRasterUIView()
        preview.feedback.chipBridge.register(remountedPreview, combatantID: "hero", layoutDirection: .leftToRight, displayScale: 1)
        #expect(remountedPreview.debugLastAppliedChips.map(\.label) == preview.feedback.activeItems.prefix(3).map(\.label))
        preview.clearRunState()
    }

    @Test @MainActor func `session teardown clears its published chips`() {
        let session = BattleSession()
        let bridge = session.feedback.chipBridge
        session.feedback.record(
            [BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 3, keyword: .physical)],
            at: .now,
        )
        let view = CombatFeedbackRasterUIView()
        bridge.register(
            view,
            combatantID: "enemy",
            layoutDirection: .leftToRight,
            displayScale: 3.0,
        )
        #expect(view.debugLastAppliedChips.map(\.id) == [1])

        session.clearRunState()
        #expect(view.debugLastAppliedChips.isEmpty)
    }
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
