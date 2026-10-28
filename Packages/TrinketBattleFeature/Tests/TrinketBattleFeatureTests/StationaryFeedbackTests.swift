import BattleEngine
import CoreGraphics
import Foundation
import QuartzCore
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

    @Test @MainActor func `reserved digit overflow emits a new amount`() {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([event(1, amount: 9)], at: start)
        lane.record([event(2, amount: 90)], at: start.addingTimeInterval(0.05))
        #expect(lane.activeItems.map(\.label) == [.amount(-99)])
        lane.record([event(3, amount: 1)], at: start.addingTimeInterval(0.1))
        #expect(lane.activeItems.map(\.label) == [.amount(-99), .amount(-1)])
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

    @Test @MainActor func `corner rasters keep their centers through pop fade and numeric growth`() throws {
        let start = Date.now.addingTimeInterval(10)
        let pool = CombatFeedbackRasterPool()
        for benefit in [true, false] {
            let labels: [CombatFeedbackChipLabel] = [
                .word(.plain(.poison)), .amount(9),
                .word(.triggered(.freeze)), .word(.triggered(.stun)),
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
                let center = layer.position
                for elapsed in [0.0, 0.05, 0.16, 0.4, 0.8] {
                    view.debugTickMotion(at: start.addingTimeInterval(elapsed))
                    #expect(layer.position == center)
                    #expect(view.bounds.contains(layer.frame))
                    #expect(
                        benefit ? layer.frame.maxX <= view.bounds.midX - 4 + 0.000001 : layer.frame.minX >= view.bounds.midX + 4 - 0.000001,
                        "Corner \(benefit), label \(label), rendered frame \(layer.frame)",
                    )
                }
                if case .amount = label {
                    let layoutCount = view.debugLayoutCount
                    item.label = .amount(99)
                    let merged = try #require(pool.prepare(for: item, displayScale: 1))
                    view.apply(chips: [(item, merged)])
                    view.debugTickMotion(at: start.addingTimeInterval(0.05))
                    #expect(view.debugLayoutCount == layoutCount)
                    #expect(layer.position == center)
                    #expect(view.bounds.contains(layer.frame))
                    #expect(
                        benefit ? layer.frame.maxX <= view.bounds.midX - 4 + 0.000001 : layer.frame.minX >= view.bounds.midX + 4 - 0.000001,
                        "Corner \(benefit), label \(label), rendered frame \(layer.frame)",
                    )
                }
            }
        }
    }

    @Test @MainActor func `status routing separates applications from actual damage and respects recipient polarity`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let events = [
            BattleSessionTestSupport.makeActionEvent(id: 1, kind: .effect(.cleanseApplied), amount: 1, keyword: .poison),
            BattleSessionTestSupport.makeActionEvent(id: 2, kind: .effect(.purgeApplied), amount: 1, keyword: .block),
            BattleSessionTestSupport.makeActionEvent(id: 3, kind: .effect(.markedApplied), amount: 1, keyword: .physical),
            BattleSessionTestSupport.makeActionEvent(id: 4, kind: .effect(.wardApplied), amount: 1, keyword: .holy),
            BattleSessionTestSupport.makeActionEvent(id: 5, kind: .status, amount: 3, keyword: .poison),
            BattleSessionTestSupport.makeActionEvent(id: 6, kind: .effect(.instantHeal), amount: 4, keyword: .health),
        ]
        lane.record(events)
        for (id, region) in [(1, CombatFeedbackRegion.benefit), (2, .setback), (3, .setback), (4, .benefit), (5, .impact), (6, .impact)] {
            #expect(try #require(lane.activeItems.first { $0.sourceEventIDs.contains(id) }).region == region)
        }
    }

    @Test @MainActor func `status consolidation retains source identity without restarting motion or extending visibility`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        let first = BattleSessionTestSupport.makeActionEvent(
            id: 1, kind: .effect(.cleanseApplied), amount: 1, keyword: .poison,
        )
        let second = BattleSessionTestSupport.makeActionEvent(
            id: 2, kind: .effect(.cleanseApplied), amount: 1, keyword: .poison,
        )
        lane.record([first], at: start)
        let original = try #require(lane.activeItems.first)
        let date = start.addingTimeInterval(0.2)
        lane.record([second], at: date)
        #expect(lane.activeItems.count == 1)
        let merged = try #require(lane.activeItems.first)
        let before = BalancedFeedbackMotion.state(for: original, at: date)
        let after = BalancedFeedbackMotion.state(for: merged, at: date)
        #expect(after == before)
        #expect(merged.sourceEventIDs == [1, 2])
        #expect(merged.expiresAt == original.expiresAt && merged.firstScheduledAt == original.firstScheduledAt)
    }

    @Test @MainActor func `feedback clocks stop when all chips pause and on teardown`() throws {
        let view = CombatFeedbackRasterUIView(frame: CGRect(x: 0, y: 0, width: 160, height: 220))
        defer { view.apply(chips: []) }
        let start = Date.now.addingTimeInterval(10)
        let pool = CombatFeedbackRasterPool()
        var items = (1 ... 12).map { id in
            CombatFeedbackItem(
                id: id, sourceEventIDs: [id], actionGroupID: id, presentationIndex: id,
                targetID: "test", feedbackClass: .directDamage, keyword: .physical,
                visualRole: .keyword, label: .amount(-9), availableAt: start,
                expiresAt: start.addingTimeInterval(CombatFeedbackMotionSampler.lifetime),
                reactionKind: .none,
            )
        }
        for index in items.indices.dropFirst() {
            items[index].pausedAt = start
        }
        let raster = try #require(pool.prepare(for: items[0], displayScale: 1))
        view.apply(chips: items.map { ($0, raster) })
        #expect(view.debugIsMotionRegistered)
        items[0].pausedAt = start
        view.apply(chips: items.map { ($0, raster) })
        #expect(view.debugVisibleChipIDs == Set(1 ... 12))
        #expect(!view.debugIsMotionRegistered)

        items[0].pausedAt = nil
        view.apply(chips: [(items[0], raster)])
        #expect(view.debugIsMotionRegistered)
        view.stopMotion()
        #expect(!view.debugIsMotionRegistered)
        #expect(view.debugVisibleChipIDs == [1])
        view.apply(chips: [(items[0], raster)])
        #expect(view.debugIsMotionRegistered)
    }

    @Test @MainActor func `critical merges flash without restarting glints and maskless replacements release old masks`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([event(1, amount: 4)], at: start)
        let item = try #require(lane.activeItems.first)
        let pool = CombatFeedbackRasterPool()
        let raster = try #require(pool.prepare(for: item, displayScale: 1))
        let view = CombatFeedbackRasterUIView(frame: CGRect(x: 0, y: 0, width: 160, height: 220))
        defer { view.apply(chips: []) }
        view.apply(chips: [(item, raster)])
        let chip = try #require(view.layer.sublayers?.first { $0.contents != nil })
        let shine = try #require(chip.sublayers?.first)
        #expect(shine.mask?.contents != nil)
        let mergeAt = start.addingTimeInterval(0.2)
        lane.record(
            [BattleSessionTestSupport.makeActionEvent(id: 2, kind: .abilityDamage, amount: 5, keyword: .physical, isCritical: true)],
            at: mergeAt,
        )
        let merged = try #require(lane.activeItems.first)
        let mergedRaster = try #require(pool.prepare(for: merged, displayScale: 1))
        view.apply(chips: [(merged, mergedRaster)])
        view.debugTickMotion(at: mergeAt)
        #expect(!shine.isHidden)

        let maskless = CombatFeedbackRaster(
            key: mergedRaster.key, image: mergedRaster.image,
            pointSize: mergedRaster.pointSize, displayScale: mergedRaster.displayScale,
        )
        view.apply(chips: [(merged, maskless)])
        view.debugTickMotion(at: mergeAt)
        #expect(shine.isHidden)
        #expect(shine.mask?.contents == nil)
        view.apply(chips: [(merged, mergedRaster)])
        view.debugTickMotion(at: mergeAt)
        #expect(!shine.isHidden)
        #expect(shine.mask?.contents != nil)
        view.debugTickMotion(at: start.addingTimeInterval(0.46))
        #expect(shine.isHidden)
        #expect(merged.firstScheduledAt == item.firstScheduledAt)
    }

    @Test @MainActor func `arrival gap gates merges while suspension preserves the shipping clock`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([event(1, amount: 4)], at: start)
        let original = try #require(lane.activeItems.first)
        lane.record([event(2, amount: 5)], at: start.addingTimeInterval(0.25))
        #expect(lane.activeItems.first?.label == .amount(-9))
        #expect(lane.activeItems.first?.expiresAt == original.expiresAt)
        lane.record([event(3, amount: 1)], at: start.addingTimeInterval(0.501))
        #expect(lane.activeItems.count == 2)
        let pausedAt = start.addingTimeInterval(0.6)
        let before = BalancedFeedbackMotion.state(for: original, at: pausedAt)
        lane.setSuspended(true, at: pausedAt)
        lane.setSuspended(false, at: pausedAt.addingTimeInterval(20))
        let resumed = try #require(lane.activeItems.first)
        #expect(BalancedFeedbackMotion.state(for: resumed, at: pausedAt.addingTimeInterval(20)) == before)
        #expect(abs(BalancedFeedbackMotion.state(for: resumed, at: resumed.expiresAt).opacity) < 0.000001)
    }

    @Test @MainActor func `frequent arrivals cannot merge after the original fade boundary`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        for id in 1 ... 4 {
            lane.record([event(id, amount: 1)], at: start.addingTimeInterval(Double(id - 1) * 0.2))
        }
        let first = try #require(lane.activeItems.first)
        #expect(lane.activeItems.count == 1)
        lane.record([event(5, amount: 1)], at: first.expiresAt.addingTimeInterval(-CombatFeedbackMotionSampler.fadeDuration))
        #expect(lane.activeItems.count == 2)
        #expect(lane.activeItems.first == first)
    }

    private func event(_ id: Int, amount: Int) -> BattleEngine.ActionEvent {
        BattleSessionTestSupport.makeActionEvent(id: id, kind: .abilityDamage, amount: amount, keyword: .physical, actionID: id)
    }
}

struct FeedbackGeometryCacheTests {
    @Test @MainActor func `shared motion tracks preserve merges pause and independent timing`() {
        let start = Date(timeIntervalSince1970: 100)
        var item = CombatFeedbackItem(
            id: 1, sourceEventIDs: [1], actionGroupID: 1, presentationIndex: 0,
            targetID: "test", feedbackClass: .directDamage, keyword: .physical,
            visualRole: .keyword, label: .amount(9), availableAt: start,
            expiresAt: start.addingTimeInterval(CombatFeedbackMotionSampler.lifetime), reactionKind: .damage,
        )
        let track = CombatFeedbackMotionTrack()
        let date = start.addingTimeInterval(0.4)
        func check(_ item: CombatFeedbackItem, at date: Date) {
            let sample = track.sample(for: item, at: date)
            #expect(sample.animation == BalancedFeedbackMotion.state(for: item, at: date))
            let now = item.pausedAt ?? date
            #expect(sample.elapsed == now.timeIntervalSince(item.firstScheduledAt))
            #expect(sample.criticalElapsed == (item.criticalAt.map { max(0, now.timeIntervalSince($0)) } ?? 1))
            #expect(sample.shadowOpacity == Float(1 - BattleMotion.smoothProgress(sample.criticalElapsed / 0.48)))
            #expect(sample.flashOpacity == Float(0.8 * (1 - BattleMotion.smoothProgress(sample.criticalElapsed / 0.14))))
        }
        check(item, at: date)
        check(item, at: date)
        item.criticalAt = date
        item.expiresAt = item.expiresAt.addingTimeInterval(0.12)
        check(item, at: date)
        item.pausedAt = date
        check(item, at: date.addingTimeInterval(1))
        item = item.scheduled(at: date)
        item.pausedAt = nil
        check(item, at: date)
        item.label = .word(.cleanse(.poison))
        check(item, at: date)
    }

    @Test @MainActor func `cached feedback geometry refreshes for resize inset and remounted fragments`() throws {
        let start = Date.now.addingTimeInterval(10)
        let pool = CombatFeedbackRasterPool()
        var item = CombatFeedbackItem(
            id: 1, sourceEventIDs: [1], actionGroupID: 1, presentationIndex: 0,
            targetID: "test", feedbackClass: .buff, keyword: .poison,
            visualRole: .beneficialStatus, label: .amount(9), availableAt: start,
            expiresAt: start.addingTimeInterval(CombatFeedbackMotionSampler.lifetime),
            reactionKind: .none,
        )
        item.pausedAt = start.addingTimeInterval(0.3)
        let raster = try #require(pool.prepare(for: item, displayScale: 1))
        let view = CombatFeedbackRasterUIView(frame: CGRect(x: 0, y: 0, width: 160, height: 220))
        defer { view.apply(chips: []) }
        view.apply(chips: [(item, raster)])
        let chip = try #require(view.layer.sublayers?.first { $0.contents != nil })
        let originalPosition = chip.position
        let originalTransform = chip.transform
        let originalOpacity = chip.opacity
        let layoutCount = view.debugLayoutCount
        view.apply(chips: [(item, raster)])
        view.debugTickMotion(at: start.addingTimeInterval(20))
        #expect(view.debugLayoutCount == layoutCount)
        #expect(chip.position == originalPosition && chip.opacity == originalOpacity)
        #expect(CATransform3DEqualToTransform(chip.transform, originalTransform))
        #expect(!view.debugIsMotionRegistered)
        view.bottomInset = 18
        view.debugTickMotion(at: start)
        #expect(abs(chip.position.y - (originalPosition.y - 18)) < 0.000001)
        view.bounds = CGRect(x: 0, y: 0, width: 120, height: 180)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        #expect(view.debugLayoutCount > layoutCount)
        #expect(view.bounds.contains(chip.frame))
        let fragment = CombatFeedbackRasterUIView(frame: view.bounds)
        fragment.bottomInset = view.bottomInset
        defer { fragment.apply(chips: []) }
        fragment.apply(chips: [(item, raster)])
        let fragmentChip = try #require(fragment.layer.sublayers?.first { $0.contents != nil })
        #expect(fragmentChip.position == chip.position && fragmentChip.opacity == chip.opacity)
        #expect(CATransform3DEqualToTransform(fragmentChip.transform, chip.transform))
    }
}
