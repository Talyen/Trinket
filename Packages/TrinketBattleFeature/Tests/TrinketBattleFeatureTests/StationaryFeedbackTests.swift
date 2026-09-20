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
        #expect(abs(session.feedback.feedbackLifetime - 1.39) < 0.000001)
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
        lane.record([event(2, amount: 5)], at: start.addingTimeInterval(0.889))
        let merged = try #require(lane.activeItems.first)
        #expect(merged.label == .amount(-9))
        #expect(merged.sourceEventIDs == [1, 2])
        #expect(merged.firstScheduledAt == start)
        #expect(merged.expiresAt == start.addingTimeInterval(1.39))
        #expect(merged.lastUpdatedAt == start.addingTimeInterval(0.889))
        lane.record([event(3, amount: 6)], at: start.addingTimeInterval(0.89))
        #expect(lane.activeItems.map(\.label) == [.amount(-9), .amount(-6)])
        #expect(lane.activeItems.allSatisfy { $0.retiringAt == nil })
        lane.pruneExpired(at: start.addingTimeInterval(1.34))
        #expect(lane.activeItems.map(\.id) == [1, 3])
        lane.pruneExpired(at: start.addingTimeInterval(1.39))
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
        let unmerged = CombatFeedbackMotionSampler.state(for: original, at: mergeAt)
        #expect(abs(pulse.scale - unmerged.scale * 1.10) < 0.000001 && pulse.shineProgress == 0)
        #expect(pulse.riseProgress == unmerged.riseProgress)
        let sweeping = CombatFeedbackMotionSampler.state(for: merged, at: mergeAt.addingTimeInterval(0.3))
        #expect(sweeping.shineProgress > 0 && sweeping.shineProgress < 1)
        let recovered = CombatFeedbackMotionSampler.state(for: merged, at: mergeAt.addingTimeInterval(0.5))
        #expect(recovered == CombatFeedbackMotionSampler.state(for: original, at: mergeAt.addingTimeInterval(0.5)))
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
        #expect(abs(initial.scale - 0.9) < 0.000001 && initial.opacity == 1 && initial.shineProgress == 0)
        let popping = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.07))
        let peak = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.14))
        #expect(popping.scale > initial.scale && popping.scale < peak.scale)
        #expect(abs(peak.scale - 2.28) < 0.000001 && peak.opacity == 1)
        let held = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.28))
        #expect(abs(held.scale - peak.scale) < 0.000001 && held.opacity == 1 && held.riseProgress == 0)
        let earlyShrink = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.4))
        let middleShrink = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.84))
        #expect(popping.riseProgress == 0 && abs(peak.riseProgress) < 0.000001)
        #expect(earlyShrink.riseProgress > 0 && abs(middleShrink.riseProgress - 0.25) < 0.000001)
        #expect(earlyShrink.scale < peak.scale && middleShrink.scale < earlyShrink.scale)
        #expect(abs(middleShrink.scale - 2.10) < 0.000001 && middleShrink.opacity == 1)
        let fadeStart = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(0.89))
        let fading = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(1.14))
        let gone = CombatFeedbackMotionSampler.state(for: item, at: start.addingTimeInterval(1.39))
        #expect(abs(fadeStart.opacity - 1) < 0.000001 && fadeStart.shineProgress == 1)
        #expect(abs(fading.opacity - 0.5) < 0.000001)
        #expect(fadeStart.riseProgress < fading.riseProgress && fading.riseProgress < gone.riseProgress)
        #expect(fadeStart.scale > fading.scale && fading.scale > gone.scale)
        #expect(abs(gone.scale - 1.56) < 0.000001 && abs(gone.opacity) < 0.000001 && abs(gone.riseProgress - 1) < 0.000001)
        let pausedAt = start.addingTimeInterval(0.4)
        lane.setSuspended(true, at: pausedAt)
        let paused = try #require(lane.activeItems.first)
        let before = CombatFeedbackMotionSampler.state(for: item, at: pausedAt)
        #expect(CombatFeedbackMotionSampler.state(for: paused, at: pausedAt.addingTimeInterval(20)) == before)
        lane.setSuspended(false, at: pausedAt.addingTimeInterval(20))
        let resumed = try #require(lane.activeItems.first)
        #expect(CombatFeedbackMotionSampler.state(for: resumed, at: pausedAt.addingTimeInterval(20)) == before)
    }

    @Test func `new lane results push older anchors upward and merges do not push`() throws {
        var layout = StationaryFeedbackLayout()
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 240)
        let size = CGSize(width: 60, height: 30)
        layout.retain(ids: [], in: bounds)
        for id in 1 ... 6 {
            let placement = layout.place(id: id, size: size)
            #expect(try #require(placement).rect.midX == bounds.midX)
            #expect(try #require(placement).rect.midY == bounds.midY)
        }
        #expect(layout.slots.count == 6)
        let original = layout.slots
        #expect(original.map(\.rect.midY) == [-22.5, 6, 34.5, 63, 91.5, 120])
        _ = layout.place(id: 6, size: size)
        #expect(layout.slots == original)
        layout.retain(ids: [2, 3, 4, 5, 6], in: bounds)
        #expect(layout.slots == Array(original.dropFirst()))
        let resizedBounds = CGRect(x: 0, y: 0, width: 160, height: 200)
        layout.retain(ids: [2, 3, 4, 5, 6], in: resizedBounds)
        #expect(layout.slots.isEmpty)
        let resized = layout.place(id: 6, size: size)
        #expect(try #require(resized).rect.midY == resizedBounds.midY)
    }

    @Test func `lane pushes retarget continuously and top edge fades before removal`() {
        var push = StationaryFeedbackPush()
        push.retarget(to: 30, at: 0.2)
        #expect(push.offset(at: 0.2) == 0)
        let halfway = push.offset(at: 0.29)
        #expect(halfway > 0 && halfway < 30)
        push.retarget(to: 60, at: 0.29)
        #expect(push.offset(at: 0.29) == halfway)
        #expect(push.offset(at: 0.38) > halfway && push.offset(at: 0.38) < 60)
        #expect(push.offset(at: 0.5) == 60)
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 240)
        #expect(StationaryFeedbackLayout.edgeOpacity(centerY: 120, in: bounds) == 1)
        #expect(StationaryFeedbackLayout.edgeOpacity(centerY: 28, in: bounds) == 0.5)
        #expect(StationaryFeedbackLayout.edgeOpacity(centerY: 8, in: bounds) == 0)
    }

    @Test func `oversized lane results fit without evicting or affecting other portraits`() throws {
        var layout = StationaryFeedbackLayout()
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        layout.retain(ids: [], in: bounds)
        _ = layout.place(id: 1, size: CGSize(width: 30, height: 20))
        let placement = layout.place(id: 2, size: CGSize(width: 200, height: 200))
        let fitted = try #require(placement)
        #expect(layout.slots.map(\.id) == [1, 2])
        #expect(fitted.rect == bounds.insetBy(dx: 8, dy: 8))
        #expect(fitted.fitScale == 0.42)
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
