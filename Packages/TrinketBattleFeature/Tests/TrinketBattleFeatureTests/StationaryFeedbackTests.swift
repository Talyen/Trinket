import BattleEngine
import CoreGraphics
import Foundation
import Testing
@testable import TrinketBattleFeature

struct StationaryFeedbackTests {
    @Test @MainActor func `critical contributions retain emphasis without restarting and targets stay independent`() throws {
        let lane = BattleFeedbackLane()
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

    @Test @MainActor func `reserved digit overflow and visual eviction emit a new amount`() {
        let lane = BattleFeedbackLane()
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

    @Test func `new arrivals push preceding labels upward while merges do not push`() throws {
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
        #expect(push.offset(at: 0.6) == 60)
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
        let peak = StationaryFeedbackLayout.peakScale * StationaryFeedbackLayout.mergePulseScale
        #expect(abs(fitted.rect.width * peak - 84) < 0.000001)
        #expect(abs(fitted.rect.height * peak - 84) < 0.000001)
        #expect(fitted.rect.midX == bounds.midX && fitted.rect.midY == bounds.midY)
        var otherPortrait = StationaryFeedbackLayout()
        otherPortrait.retain(ids: [], in: bounds)
        #expect(otherPortrait.slots.isEmpty)
        layout.retain(ids: [], in: bounds)
        #expect(layout.slots.isEmpty)
    }

    @Test @MainActor func `production rasters cache glyph masks and account for their storage`() throws {
        let lane = BattleFeedbackLane()
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
    }

    @Test
    @MainActor func `feedback retains merge fade boundaries and suspension clocks`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([event(1, amount: 4)], at: start)
        lane.record(
            [event(2, amount: 5)],
            at: start.addingTimeInterval((CombatFeedbackMotionSampler.lifetime - CombatFeedbackMotionSampler.fadeDuration) - 0.01),
        )
        let merged = try #require(lane.activeItems.first)
        #expect(merged.label == .amount(-9))
        #expect(merged.firstScheduledAt == start)
        let extensionDuration = 0.12
        #expect(abs(merged.expiresAt.timeIntervalSince(start) - CombatFeedbackMotionSampler.lifetime - extensionDuration) < 0.000001)
        #expect(lane.feedbackLifetime == CombatFeedbackMotionSampler.lifetime)
        let fadeAt = merged.expiresAt.addingTimeInterval(-CombatFeedbackMotionSampler.fadeDuration)
        lane.record([event(3, amount: 6)], at: fadeAt)
        #expect(lane.activeItems.count == 2)
        let pausedAt = fadeAt.addingTimeInterval(0.05)
        let before = CombatFeedbackMotionSampler.state(for: merged, at: pausedAt)
        lane.setSuspended(true, at: pausedAt)
        lane.setSuspended(false, at: pausedAt.addingTimeInterval(20))
        let resumed = try #require(lane.activeItems.first)
        #expect(CombatFeedbackMotionSampler.state(for: resumed, at: pausedAt.addingTimeInterval(20)) == before)
        let gone = CombatFeedbackMotionSampler.state(for: resumed, at: resumed.expiresAt)
        #expect(abs(gone.opacity) < 0.000001)
    }

    @Test @MainActor func `merged values extend visibility without restarting travel and cannot live indefinitely`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([event(1, amount: 4)], at: start)
        let original = try #require(lane.activeItems.first)
        let mergeAt = start.addingTimeInterval(0.25)
        lane.record([event(2, amount: 5)], at: mergeAt)
        let merged = try #require(lane.activeItems.first)
        let before = CombatFeedbackMotionSampler.state(for: original, at: mergeAt)
        let after = CombatFeedbackMotionSampler.state(for: merged, at: mergeAt)
        #expect(after.riseProgress == before.riseProgress)
        #expect(abs(after.scale - before.scale * 1.10) < 0.000001)
        #expect(after.shineProgress == 0)
        for id in 3 ... 8 {
            lane.record([event(id, amount: 1)], at: start.addingTimeInterval(0.25 + Double(id) * 0.03))
        }
        let extended = try #require(lane.activeItems.first)
        #expect(lane.activeItems.count == 1)
        #expect(abs(extended.expiresAt.timeIntervalSince(original.expiresAt) - 0.30) < 0.000001)
        let originalEnd = CombatFeedbackMotionSampler.state(for: original, at: original.expiresAt)
        let extendedEnd = CombatFeedbackMotionSampler.state(for: extended, at: original.expiresAt)
        #expect(extendedEnd.opacity > originalEnd.opacity)
        lane.pruneExpired(at: extended.expiresAt)
        #expect(lane.activeItems.isEmpty)
    }

    @Test func `status lanes fit their corners and never push the damage lane or each other`() throws {
        var layout = StationaryFeedbackLayout()
        let bounds = CGRect(x: 0, y: 0, width: 160, height: 220)
        layout.retain(ids: [], in: bounds)
        let hitPlacement = layout.place(id: 1, size: CGSize(width: 60, height: 30))
        let hit = try #require(hitPlacement)
        let benefitPlacement = layout.place(id: 2, size: CGSize(width: 40, height: 24), region: .benefit)
        let benefit = try #require(benefitPlacement)
        let setbackPlacement = layout.place(id: 3, size: CGSize(width: 40, height: 24), region: .setback)
        let setback = try #require(setbackPlacement)
        for id in 4 ... 10 {
            _ = layout.place(id: id, size: CGSize(width: 30, height: 24), region: .setback)
        }
        #expect(layout.slots.first { $0.id == 1 } == hit)
        #expect(layout.slots.first { $0.id == 2 } == benefit)
        #expect(benefit.rect.midX < bounds.midX && setback.rect.midX > bounds.midX)
        #expect(benefit.rect.midY > bounds.midY && setback.rect.midY > bounds.midY)
        #expect(!benefit.rect.intersects(setback.rect))
        #expect(benefit.fitScale == 1 && setback.fitScale == 1)
        let wider = layout.place(id: 11, size: CGSize(width: 90, height: 24), region: .benefit)
        let wideSlot = try #require(wider)
        #expect(wideSlot.fitScale > 0.5)
        #expect(wideSlot.rect.width * StationaryFeedbackLayout.peakScale * StationaryFeedbackLayout.mergePulseScale <= bounds.width - 16)
    }

    @Test @MainActor func `corner rasters stay edge anchored through pop fade and numeric growth`() throws {
        let start = Date.now.addingTimeInterval(10)
        let pool = CombatFeedbackRasterPool()
        for benefit in [true, false] {
            let labels: [CombatFeedbackChipLabel] = [
                .word(.plain(.poison)), .amount(9),
                benefit ? .word(.cleanse(.poison)) : .word(.purge(.poison)),
            ]
            for label in labels {
                let view = CombatFeedbackRasterUIView(frame: CGRect(x: 0, y: 0, width: 160, height: 220))
                view.bottomInset = 6
                defer { view.apply(chips: []) }
                var item = CombatFeedbackItem(
                    id: 1, sourceEventIDs: [1], actionGroupID: 1, presentationIndex: 0,
                    targetID: "test", feedbackClass: .buff, keyword: .poison,
                    visualRole: benefit ? .beneficialStatus : .negativeStatus,
                    label: label, availableAt: start,
                    expiresAt: start.addingTimeInterval(CombatFeedbackMotionSampler.lifetime),
                    reactionKind: .none,
                )
                if case .amount = label {
                    item.reservedDigitCount = 2
                }
                let raster = try #require(pool.prepare(for: item, displayScale: 1))
                view.apply(chips: [(item, raster)])
                let layer = try #require(view.layer.sublayers?.first { !$0.isHidden && $0.contents != nil })
                for elapsed in [0.0, 0.05, 0.16, 0.4, 0.8] {
                    view.debugTickMotion(at: start.addingTimeInterval(elapsed))
                    #expect(abs(layer.frame.maxY - 206) < 0.000001)
                    #expect(abs((benefit ? layer.frame.minX : 160 - layer.frame.maxX) - 8) < 0.000001)
                    #expect(view.bounds.contains(layer.frame))
                }
                if case .amount = label {
                    item.label = .amount(99)
                    item.lastUpdatedAt = start.addingTimeInterval(0.05)
                    let merged = try #require(pool.prepare(for: item, displayScale: 1))
                    view.apply(chips: [(item, merged)])
                    view.debugTickMotion(at: start.addingTimeInterval(0.05))
                    #expect(abs(layer.frame.maxY - 206) < 0.000001)
                    #expect(abs((benefit ? layer.frame.minX : 160 - layer.frame.maxX) - 8) < 0.000001)
                    #expect(view.bounds.contains(layer.frame))
                }
            }
        }
    }

    @Test @MainActor func `status routing separates applications from actual damage and respects recipient polarity`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let events = [
            BattleSessionTestSupport.makeActionEvent(id: 1, kind: .effect, effectKind: .cleanseApplied, amount: 1, keyword: .poison),
            BattleSessionTestSupport.makeActionEvent(id: 2, kind: .effect, effectKind: .purgeApplied, amount: 1, keyword: .block),
            BattleSessionTestSupport.makeActionEvent(id: 3, kind: .effect, effectKind: .markedApplied, amount: 1, keyword: .physical),
            BattleSessionTestSupport.makeActionEvent(id: 4, kind: .effect, effectKind: .wardApplied, amount: 1, keyword: .holy),
            BattleSessionTestSupport.makeActionEvent(id: 5, kind: .status, amount: 3, keyword: .poison),
            BattleSessionTestSupport.makeActionEvent(id: 6, kind: .effect, effectKind: .instantHeal, amount: 4, keyword: .health),
        ]
        lane.record(events)
        for (id, region) in [(1, CombatFeedbackRegion.benefit), (2, .setback), (3, .setback), (4, .benefit), (5, .impact), (6, .impact)] {
            #expect(try #require(lane.activeItems.first { $0.sourceEventIDs.contains(id) }).region == region)
        }
    }

    @Test @MainActor func `status consolidation repeats the shared pulse and glint without restarting motion`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        let first = BattleSessionTestSupport.makeActionEvent(
            id: 1, kind: .effect, effectKind: .cleanseApplied, amount: 1, keyword: .poison,
        )
        let second = BattleSessionTestSupport.makeActionEvent(
            id: 2, kind: .effect, effectKind: .cleanseApplied, amount: 1, keyword: .poison,
        )
        lane.record([first], at: start)
        let original = try #require(lane.activeItems.first)
        let date = start.addingTimeInterval(0.3)
        lane.record([second], at: date)
        #expect(lane.activeItems.count == 1)
        let merged = try #require(lane.activeItems.first)
        let before = CombatFeedbackMotionSampler.state(for: original, at: date)
        let after = CombatFeedbackMotionSampler.state(for: merged, at: date)
        #expect(after.riseProgress == before.riseProgress && after.shineProgress == 0)
        #expect(abs(after.scale - before.scale * 1.10) < 0.000001)
        #expect(merged.expiresAt > original.expiresAt && merged.firstScheduledAt == original.firstScheduledAt)
    }

    private func event(_ id: Int, amount: Int) -> BattleEngine.ActionEvent {
        BattleSessionTestSupport.makeActionEvent(id: id, kind: .abilityDamage, amount: amount, keyword: .physical, actionID: id)
    }
}
