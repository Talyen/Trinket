import BattleEngine
import CoreGraphics
import Foundation
import Testing
@testable import TrinketBattleFeature

struct StationaryFeedbackTests {
    @Test @MainActor func `mode changes are captured at battle activation`() throws {
        var enabled = false
        let dependencies = BattleRuntimeDependencies(
            playSFX: { _ in }, warmSFX: { _, _ in }, hapticsEnabled: { false }, effectsVolume: { 0 },
            shouldAutoSkipUltimateCinematic: { _, _ in false },
            stationaryFeedbackExperimentEnabled: { enabled },
        )
        let session = BattleSessionTestSupport.makeConfiguredSession(presentationEnvironment: dependencies)
        defer { session.endBattle() }
        #expect(!session.feedback.usesStationaryExperiment)
        enabled = true
        #expect(!session.feedback.usesStationaryExperiment)
        let configuration = try #require(session.activeBattle)
        #expect(session.restart(configuration))
        #expect(session.feedback.usesStationaryExperiment)
        #expect(session.feedback.feedbackLifetime == 1.26)
    }

    @Test @MainActor func `critical contributions retain emphasis without restarting and targets stay independent`() throws {
        let lane = BattleFeedbackLane()
        lane.usesStationaryExperiment = true
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([event(1, amount: 4)], at: start)
        lane.record([
            BattleSessionTestSupport.makeActionEvent(id: 2, kind: .abilityDamage, amount: 5, keyword: .physical, isCritical: true),
            BattleSessionTestSupport.makeActionEvent(id: 3, kind: .abilityDamage, amount: 5, keyword: .physical, targetID: "hero"),
        ], at: start.addingTimeInterval(0.1))
        let first = try #require(lane.activeItems.first)
        #expect(first.isCritical && first.firstScheduledAt == start)
        #expect(first.criticalAt == start.addingTimeInterval(0.1))
        #expect(first.label == .amount(-9))
        #expect(lane.activeItems.count == 2)
    }

    @Test @MainActor func `cross attack merges keep the entrance clock and stop at fade`() throws {
        let lane = BattleFeedbackLane()
        lane.usesStationaryExperiment = true
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([event(1, amount: 4)], at: start)
        lane.record([event(2, amount: 5)], at: start.addingTimeInterval(1.009))
        let merged = try #require(lane.activeItems.first)
        #expect(merged.label == .amount(-9))
        #expect(merged.sourceEventIDs == [1, 2])
        #expect(merged.firstScheduledAt == start)
        #expect(merged.expiresAt == start.addingTimeInterval(1.26))
        #expect(merged.lastUpdatedAt == start.addingTimeInterval(1.009))
        lane.record([event(3, amount: 6)], at: start.addingTimeInterval(1.01))
        #expect(lane.activeItems.map(\.label) == [.amount(-9), .amount(-6)])
        #expect(lane.activeItems.allSatisfy { $0.retiringAt == nil })
        lane.pruneExpired(at: start.addingTimeInterval(1.26))
        #expect(lane.activeItems.map(\.id) == [3])
    }

    @Test @MainActor func `merged damage pulses and glints without extending or restarting its lifetime`() throws {
        let lane = BattleFeedbackLane()
        lane.usesStationaryExperiment = true
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([event(1, amount: 4)], at: start)
        let original = try #require(lane.activeItems.first)
        let mergeAt = start.addingTimeInterval(0.4)
        lane.record([event(2, amount: 5)], at: mergeAt)
        let merged = try #require(lane.activeItems.first)
        let pulse = CombatFeedbackMotionSampler.state(for: merged, at: mergeAt)
        #expect(merged.label == .amount(-9))
        #expect(merged.firstScheduledAt == original.firstScheduledAt && merged.expiresAt == original.expiresAt)
        #expect(abs(pulse.scale - 2.64) < 0.000001 && pulse.shineProgress == 0 && pulse.riseProgress == 0)
        let recovered = CombatFeedbackMotionSampler.state(for: merged, at: mergeAt.addingTimeInterval(0.3))
        #expect(recovered == CombatFeedbackMotionSampler.state(for: original, at: mergeAt.addingTimeInterval(0.3)))
        let pausedAt = mergeAt.addingTimeInterval(0.05)
        let beforePause = CombatFeedbackMotionSampler.state(for: merged, at: pausedAt)
        lane.setSuspended(true, at: pausedAt)
        lane.setSuspended(false, at: pausedAt.addingTimeInterval(20))
        let resumed = try #require(lane.activeItems.first)
        #expect(CombatFeedbackMotionSampler.state(for: resumed, at: pausedAt.addingTimeInterval(20)) == beforePause)
    }

    @Test @MainActor func `reserved digit overflow and visual eviction emit a new amount`() {
        let lane = BattleFeedbackLane()
        lane.usesStationaryExperiment = true
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([event(1, amount: 9)], at: start)
        lane.record([event(2, amount: 90)], at: start.addingTimeInterval(0.05))
        #expect(lane.activeItems.map(\.label) == [.amount(-99)])
        lane.record([event(3, amount: 1)], at: start.addingTimeInterval(0.1))
        #expect(lane.activeItems.map(\.label) == [.amount(-99), .amount(-1)])
        lane.evictedItemIDs = [1, 3]
        lane.record([event(4, amount: 2)], at: start.addingTimeInterval(0.15))
        #expect(lane.activeItems.map(\.label) == [.amount(-99), .amount(-1), .amount(-2)])
        #expect(lane.activeItems.flatMap(\.sourceEventIDs) == [1, 2, 3, 4])
    }

    @Test @MainActor func `stationary motion has exact boundaries and survives suspension`() throws {
        let lane = BattleFeedbackLane()
        lane.usesStationaryExperiment = true
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([event(1, amount: 4)], at: start)
        let item = try #require(lane.activeItems.first)
        let initial = CombatFeedbackMotionSampler.state(for: item, at: start)
        #expect(initial.scale == 1.2 && initial.opacity == 1 && initial.shineProgress == 0)
        let popping = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.035))
        let peak = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.07))
        let settling = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.115))
        #expect(popping.scale > initial.scale && popping.scale < peak.scale)
        #expect(abs(peak.scale - 2.76) < 0.000001 && peak.opacity == 1)
        #expect(settling.scale < peak.scale && settling.scale > 2.4)
        let endOfHold = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.65))
        #expect(endOfHold.scale == 2.4 && endOfHold.opacity == 1 && endOfHold.riseProgress == 0)
        let held = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.19))
        #expect(held.scale == 2.4 && held.opacity == 1 && held.riseProgress == 0)
        let shrinking = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.835))
        #expect(abs(shrinking.scale - 1.35) < 0.000001)
        #expect(shrinking.opacity == 1 && shrinking.shineProgress == 1)
        let fading = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(1.135))
        #expect(fading.scale == 1.2 && abs(fading.opacity - 0.5) < 0.000001)
        let settled = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(1.01))
        #expect(settled.scale == 1.2 && abs(settled.opacity - 1) < 0.000001 && settled.shineProgress == 1)
        let gone = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(1.26))
        #expect(gone.scale == 1.2 && abs(gone.opacity) < 0.000001 && gone.riseProgress == 0)
        let pausedAt = start.addingTimeInterval(0.1)
        lane.setSuspended(true, at: pausedAt)
        let paused = try #require(lane.activeItems.first)
        let before = CombatFeedbackMotionSampler.state(for: item, at: pausedAt)
        #expect(CombatFeedbackMotionSampler.state(for: paused, at: pausedAt.addingTimeInterval(20)) == before)
        lane.setSuspended(false, at: pausedAt.addingTimeInterval(20))
        let resumed = try #require(lane.activeItems.first)
        #expect(CombatFeedbackMotionSampler.state(for: resumed, at: pausedAt.addingTimeInterval(20)) == before)
    }

    @Test func `placement clusters overlapping labels without rearranging survivors`() throws {
        var layout = StationaryFeedbackLayout()
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 240)
        layout.retain(ids: [], in: bounds)
        let firstPlacement = layout.place(id: 1, size: CGSize(width: 60, height: 30))
        let first = try #require(firstPlacement)
        #expect(first.slot.rect.midX == 100 && first.slot.rect.midY == 120)
        let secondPlacement = layout.place(id: 2, size: CGSize(width: 60, height: 30))
        let second = try #require(secondPlacement)
        #expect(second.slot.rect.midX == 82 && second.slot.rect.midY == 93)
        #expect(first.slot.rect.intersects(second.slot.rect))
        layout.retain(ids: [2], in: bounds)
        let thirdPlacement = layout.place(id: 3, size: CGSize(width: 60, height: 30))
        let third = try #require(thirdPlacement)
        #expect(third.slot.rect == first.slot.rect)
        #expect(layout.slots.first == second.slot)
    }

    @Test func `crowded clusters replace only the oldest and reuse freed positions`() throws {
        var layout = StationaryFeedbackLayout()
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 240)
        let size = CGSize(width: 60, height: 30)
        layout.retain(ids: [], in: bounds)
        for id in 1 ... 5 {
            let placement = layout.place(id: id, size: size)
            #expect(try #require(placement).evicted.isEmpty)
        }
        let original = layout.slots
        #expect(original.map(\.rect.midX) == [100, 82, 118, 118, 82])
        #expect(original.map(\.rect.midY) == [120, 93, 147, 93, 147])
        let replacement = layout.place(id: 6, size: size)
        #expect(try #require(replacement).evicted == [1])
        #expect(layout.slots.last?.rect == original.first?.rect)
        #expect(Array(layout.slots.prefix(4)) == Array(original.dropFirst()))
        layout.retain(ids: [3, 4, 5, 6], in: bounds)
        let reused = layout.place(id: 7, size: size)
        #expect(try #require(reused).slot.rect == original[1].rect)
        let resizedBounds = CGRect(x: 0, y: 0, width: 160, height: 200)
        layout.retain(ids: [3, 4, 5, 6, 7], in: resizedBounds)
        #expect(layout.slots.isEmpty)
        let resized = layout.place(id: 3, size: size)
        #expect(try #require(resized).slot.rect.midX == resizedBounds.midX)
    }

    @Test func `full portraits evict oldest and oversized results fit without affecting other portraits`() throws {
        var layout = StationaryFeedbackLayout()
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        layout.retain(ids: [], in: bounds)
        _ = layout.place(id: 1, size: CGSize(width: 30, height: 20))
        _ = layout.place(id: 2, size: CGSize(width: 30, height: 20))
        let replacementPlacement = layout.place(id: 3, size: CGSize(width: 200, height: 200))
        let replacement = try #require(replacementPlacement)
        #expect(replacement.evicted == [1])
        #expect(layout.slots.first?.id == 2)
        #expect(replacement.slot.rect == bounds.insetBy(dx: 8, dy: 8))
        #expect(replacement.slot.fitScale == 0.42)
        var otherPortrait = StationaryFeedbackLayout()
        otherPortrait.retain(ids: [], in: bounds)
        #expect(otherPortrait.slots.isEmpty)
        layout.retain(ids: [], in: bounds)
        #expect(layout.slots.isEmpty)
    }

    @Test @MainActor func `experimental rasters cache glyph masks and account for their storage`() throws {
        let lane = BattleFeedbackLane()
        lane.usesStationaryExperiment = true
        defer { lane.release() }
        lane.record([event(1, amount: 9)])
        let item = try #require(lane.activeItems.first)
        let pool = CombatFeedbackRasterPool()
        let raster = try #require(pool.prepare(for: item, displayScale: 1))
        let mask = try #require(raster.shineMask)
        #expect(mask.width == raster.image.width && mask.height == raster.image.height)
        #expect(raster.maximumDigitWidth > 0)
        #expect(pool.snapshot().estimatedByteCount == raster.image.bytesPerRow * raster.image.height + mask.bytesPerRow * mask.height)
        #expect(pool.prepare(for: item, displayScale: 1) === raster)
        #expect(pool.snapshot().buildCount == 1)
        var original = item
        original.usesStationaryExperiment = false
        #expect(pool.prepare(for: original, displayScale: 1)?.shineMask == nil)
    }

    private func event(_ id: Int, amount: Int) -> BattleEngine.ActionEvent {
        BattleSessionTestSupport.makeActionEvent(id: id, kind: .abilityDamage, amount: amount, keyword: .physical, actionID: id)
    }
}
