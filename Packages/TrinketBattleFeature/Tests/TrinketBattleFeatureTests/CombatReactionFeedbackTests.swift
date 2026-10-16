import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine
@testable import TrinketBattleFeature

struct CombatReactionFeedbackTests {
    @Test func `reaction announcements retain independent lifetime while typed damage consolidates`() throws {
        let start = Date(timeIntervalSince1970: 10)
        let events = [
            BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 8, keyword: .burn, actionID: 1),
            BattleSessionTestSupport.makeActionEvent(id: 2, kind: .reaction(.frostfire), amount: 0, keyword: .burn, actionID: 1),
            BattleSessionTestSupport.makeActionEvent(id: 3, kind: .abilityDamage, amount: 2, keyword: .burn, actionID: 1),
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: start).map { $0.scheduled(at: start) }
        let announcement = try #require(items.first { $0.region == .announcement })
        let damage = try #require(items.first { $0.region == .impact })
        #expect(announcement.label == .reaction(.frostfire))
        #expect(announcement.chipPresentation.reaction == .frostfire)
        #expect(announcement.expiresAt == start.addingTimeInterval(1.6))
        #expect(damage.label == .amount(-10))
        #expect(damage.sourceEventIDs == [1, 3])
        #expect(CombatFeedbackMotionSampler.state(for: announcement, at: start.addingTimeInterval(1.2)).opacity == 1)
        #expect(CombatSFXMapper.clipID(for: [events[1]]) == nil)
    }

    @MainActor @Test func `new reaction groups evict old groups without renewing their clocks`() {
        let lane = BattleFeedbackLane()
        let start = Date(timeIntervalSince1970: 10)
        var candidates = CombatFeedbackMergeCandidates(items: [])
        for index in 1 ... 4 {
            let event = BattleSessionTestSupport.makeActionEvent(
                id: index,
                kind: .reaction(.venomflash),
                amount: 0,
                keyword: .burn,
                actionID: index,
            )
            let item = CombatFeedbackPresenter.makeItems(from: [event], at: start, actionGroupID: index)[0]
            _ = lane.recordStationary(item, at: start, candidates: &candidates)
        }
        lane.limitCornerItems()
        #expect(lane.evictedItemIDs == [1])
        #expect(lane.activeItems.allSatisfy { $0.expiresAt == start.addingTimeInterval(1.6) })
        lane.resetPresentation()
        #expect(lane.activeItems.isEmpty)
    }

    @Test func `reaction group fitting reserves both columns at peak scale`() {
        var layout = StationaryFeedbackLayout()
        let bounds = CGRect(x: 0, y: 0, width: 180, height: 300)
        layout.retain(ids: [1, 2, 3], in: bounds)
        layout.placeAnnouncementGroup([
            (id: 1, size: CGSize(width: 260, height: 32)),
            (id: 2, size: CGSize(width: 140, height: 32)),
            (id: 3, size: CGSize(width: 220, height: 32)),
        ], groupIndex: 0)
        #expect(layout.slots.count == 3)
        for slot in layout.slots {
            let halfWidth = slot.rect.width * StationaryFeedbackLayout.maximumScale(for: .announcement) / 2
            #expect(slot.rect.midX - halfWidth >= bounds.minX + 8)
            #expect(slot.rect.midX + halfWidth <= bounds.maxX - 8)
        }
        #expect(layout.slots[0].rect.midX < bounds.midX)
        #expect(layout.slots[1].rect.midX > bounds.midX)
    }
}
