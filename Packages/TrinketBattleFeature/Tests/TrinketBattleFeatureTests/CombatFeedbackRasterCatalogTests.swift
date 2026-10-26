import Foundation
import SwiftUI
import Testing
import TrinketContent
import TrinketCore
import TrinketDesignSystem
@testable import BattleEngine
@testable import TrinketBattleFeature

struct CombatFeedbackRasterCatalogTests {
    @Test @MainActor func `invalidated raster work cannot repopulate the pool`() async {
        let gate = RasterPublicationGate()
        let pool = CombatFeedbackRasterPool { inputs in
            let image = inputs.first.flatMap { CombatFeedbackChipComposer.render($0) }
            await gate.pause()
            return CombatFeedbackRasterPool.PreparedBatch(rasters: inputs.map { _ in image })
        }
        let preparation = Task { await pool.prewarmInfrastructureAndWait(displayScale: 1) }
        await gate.waitForArrival()
        pool.removeAll()
        await gate.resume()
        await preparation.value
        #expect(pool.snapshot().entryCount == 0)
        await pool.prewarmInfrastructureAndWait(displayScale: 1)
        #expect(pool.snapshot().entryCount > 0)
    }

    @Test func `prepared appearances match every live word and reaction in first seen order`() {
        let items = liveVocabulary()
        var seen: Set<CombatFeedbackAppearance> = []
        let expected = items.map(CombatFeedbackAppearance.init).filter { seen.insert($0).inserted }
        let prepared = CombatFeedbackClosedVocabulary.appearances
        #expect(prepared == expected)
        #expect(Set(prepared).count == prepared.count)
    }

    @Test @MainActor func `diagnostics distinguish numeric misses from unexpected vocabulary builds`() async throws {
        let pool = CombatFeedbackRasterPool()
        await pool.prewarmInfrastructureAndWait(displayScale: 1)
        pool.resetDiagnostics()
        let date = Date()
        let word = try #require(liveVocabulary(at: date).first)
        _ = pool.prepare(for: word, displayScale: 1)
        let numeric = CombatFeedbackItem(
            id: 999001, sourceEventIDs: [999001], actionGroupID: 999001, presentationIndex: 0,
            targetID: "test", feedbackClass: .directDamage, keyword: .physical, visualRole: .keyword,
            label: .amount(12345), availableAt: date, expiresAt: date.addingTimeInterval(1),
            reactionKind: .damage,
        )
        _ = pool.prepare(for: numeric, displayScale: 1)
        let snapshot = pool.snapshot()
        #expect(snapshot.numericMissCount == 1)
        #expect(snapshot.unexpectedClosedVocabularyBuildCount == 0)
    }

    @Test @MainActor func `numeric churn cannot evict the prepared vocabulary or exceed capacity`() async throws {
        let items = liveVocabulary()
        let keys = Set(items.map {
            CombatFeedbackRasterKey(item: $0, layoutDirection: .leftToRight, displayScale: 1)
        })
        #expect(keys.count < CombatFeedbackRasterPool.defaultCapacity)
        // One numeric slot exercises the same eviction contract without baking hundreds of amounts.
        let capacity = keys.count + 1
        let pool = CombatFeedbackRasterPool(capacity: capacity)
        await pool.prewarmInfrastructureAndWait(displayScale: 1)
        let before = try items.map { try #require(pool.cachedRaster(for: $0, displayScale: 1)) }
        let now = Date.now
        for amount in [11001, 11002, 11003] {
            let numeric = CombatFeedbackItem(
                id: amount, sourceEventIDs: [amount], actionGroupID: amount, presentationIndex: 0,
                targetID: "hero", feedbackClass: .directDamage, keyword: .physical, visualRole: .keyword,
                label: .amount(amount), availableAt: now, expiresAt: now.addingTimeInterval(1),
                reactionKind: .damage,
            )
            _ = try #require(pool.prepare(for: numeric, displayScale: 1))
            #expect(pool.snapshot().entryCount <= capacity)
        }
        for (item, raster) in zip(items, before) {
            #expect(pool.cachedRaster(for: item, displayScale: 1) === raster)
        }
        #expect(pool.snapshot().unexpectedClosedVocabularyBuildCount == 0)
        #expect(pool.snapshot().evictionCount == 2)
        pool.removeAll()
        #expect(pool.snapshot().entryCount == 0)
        await pool.prewarmInfrastructureAndWait(displayScale: 1)
        for item in items {
            #expect(pool.cachedRaster(for: item, displayScale: 1) != nil)
        }
    }

    @Test @MainActor func `pool evicts the least recently used raster at capacity`() throws {
        let pool = CombatFeedbackRasterPool(capacity: 2)
        let date = Date()
        func numericItem(id: Int, amount: Int) -> CombatFeedbackItem {
            CombatFeedbackItem(
                id: id, sourceEventIDs: [id], actionGroupID: id, presentationIndex: 0,
                targetID: "test", feedbackClass: .directDamage, keyword: .physical, visualRole: .keyword,
                label: .amount(amount), availableAt: date, expiresAt: date.addingTimeInterval(1),
                reactionKind: .damage,
            )
        }
        let first = numericItem(id: 1, amount: 11)
        let second = numericItem(id: 2, amount: 22)
        let third = numericItem(id: 3, amount: 33)
        let firstRaster = try #require(pool.prepare(for: first, displayScale: 1))
        _ = pool.prepare(for: second, displayScale: 1)
        #expect(pool.cachedRaster(for: first, displayScale: 1) === firstRaster)
        _ = pool.prepare(for: third, displayScale: 1)
        #expect(pool.cachedRaster(for: second, displayScale: 1) == nil)
        #expect(pool.cachedRaster(for: first, displayScale: 1) === firstRaster)
        #expect(pool.cachedRaster(for: third, displayScale: 1) != nil)
        let snapshot = pool.snapshot()
        #expect(snapshot.entryCount == 2)
        #expect(snapshot.evictionCount == 1)
    }

    private func liveVocabulary(at date: Date = .now) -> [CombatFeedbackItem] {
        var events: [ActionEvent] = []
        for outcome in ActionEvent.EffectOutcome.allCases {
            for keyword in Keyword.allCases {
                events.append(BattleSessionTestSupport.makeActionEvent(
                    id: events.count + 1, kind: .effect(outcome), amount: 1, keyword: keyword,
                ))
            }
        }
        for reaction in CombatReaction.allCases {
            events.append(BattleSessionTestSupport.makeActionEvent(
                id: events.count + 1, kind: .reaction(reaction), amount: 0, keyword: reaction.damageKeyword,
            ))
        }
        var seen: Set<CombatFeedbackAppearance> = []
        return events.flatMap { CombatFeedbackPresenter.makeItems(from: [$0], at: date) }.filter {
            if case .amount = $0.label {
                return false
            }
            return seen.insert(.init(item: $0)).inserted
        }
    }
}

private actor RasterPublicationGate {
    private var isOpen = false
    private var paused: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?

    func pause() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            paused = continuation
            arrival?.resume()
            arrival = nil
        }
    }

    func waitForArrival() async {
        guard paused == nil else { return }
        await withCheckedContinuation { arrival = $0 }
    }

    func resume() {
        isOpen = true
        paused?.resume()
        paused = nil
    }
}
