import Foundation
import SwiftUI
import Testing
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
            return inputs.map { _ in image }
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

    @Test func `every closed vocabulary live presentation maps to A warmed key`() {
        let date = Date(timeIntervalSince1970: 1)
        let layoutDirection = LayoutDirection.leftToRight
        let displayScale: CGFloat = 3
        let warmed = Set(
            CombatFeedbackClosedVocabulary.enumerateItems(at: date).map {
                CombatFeedbackRasterKey(
                    item: $0,
                    layoutDirection: layoutDirection,
                    displayScale: displayScale,
                )
            },
        )

        for item in CombatFeedbackClosedVocabulary.enumerateWordChips(at: date) {
            let key = CombatFeedbackRasterKey(
                item: item,
                layoutDirection: layoutDirection,
                displayScale: displayScale,
            )
            #expect(
                warmed.contains(key),
                "missing warmup for \(item.feedbackClass) \(item.label) \(item.keyword)",
            )
        }
    }

    @Test func `closed vocabulary static sources are strictly unique by appearance`() {
        let sources = CombatFeedbackClosedVocabulary.enumerateSources()
        let appearances = sources.map {
            CombatFeedbackRasterKey(
                item: CombatFeedbackItem(
                    id: 1,
                    sourceEventIDs: [1],
                    actionGroupID: 1,
                    presentationIndex: 0,
                    targetID: "test",
                    feedbackClass: $0.feedbackClass,
                    keyword: $0.keyword,
                    visualRole: $0.visualRole,
                    label: $0.label,
                    availableAt: .distantPast,
                    expiresAt: .distantFuture,
                    reactionKind: .none,
                ),
                layoutDirection: .leftToRight,
                displayScale: 3,
            )
        }
        #expect(Set(appearances).count == sources.count)
    }

    @Test @MainActor func `diagnostics distinguish numeric misses from unexpected vocabulary builds`() async throws {
        let pool = CombatFeedbackRasterPool()
        await pool.prewarmInfrastructureAndWait(displayScale: 1)
        pool.resetDiagnostics()
        let date = Date()
        let word = try #require(CombatFeedbackClosedVocabulary.enumerateWordChips(at: date).first)
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

    @Test @MainActor func `pool evicts the least recently used raster at capacity`() {
        let pool = CombatFeedbackRasterPool(capacity: 1)
        let date = Date()
        func numericItem(id: Int, amount: Int) -> CombatFeedbackItem {
            CombatFeedbackItem(
                id: id, sourceEventIDs: [id], actionGroupID: id, presentationIndex: 0,
                targetID: "test", feedbackClass: .directDamage, keyword: .physical, visualRole: .keyword,
                label: .amount(amount), availableAt: date, expiresAt: date.addingTimeInterval(1),
                reactionKind: .damage,
            )
        }
        _ = pool.prepare(for: numericItem(id: 1, amount: 11), displayScale: 1)
        _ = pool.prepare(for: numericItem(id: 2, amount: 22), displayScale: 1)
        let snapshot = pool.snapshot()
        #expect(snapshot.entryCount == 1)
        #expect(snapshot.evictionCount == 1)
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
