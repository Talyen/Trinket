import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct CloudSaveMergeVoyageClaimRegressionTests {
    @Test(arguments: [false, true]) @MainActor
    func `starting another Voyage retains overlap detection for the finished run`(reverseBranches: Bool) throws {
        var stale = try finalBossSave()
        var base = stale
        base.voyage.activeRun = nil
        stale.roster.gold += 7
        var completed = try completeFinalBoss(stale)
        let next = try #require(completed.voyage.offers.first)
        let embarked = completed.voyage.embark(offerID: next.id, eligibleRecruitEventIDs: [], access: .fullGame)
        #expect(embarked)
        let incoming = reverseBranches ? stale : completed
        let existing = reverseBranches ? completed : stale

        for preferIncoming in [true, false] {
            let merged = CloudSaveMerge.merge(incoming: incoming, existing: existing, base: base, preferIncoming: preferIncoming)
            let context = try PersistenceTestContext()
            try SaveTestSupport.writeRoot(merged, to: context.storeURL())
            let reloaded = try context.makeSaveStore().currentSave
            #expect(reloaded.roster.gold == completed.roster.gold)
            #expect(reloaded.voyage.activeRun?.id == next.id)
            #expect(CloudSaveMerge.hasDuplicateClaim(incoming: incoming, existing: existing, base: base))
        }
    }

    @Test(arguments: [false, true]) @MainActor
    func `a completed Voyage cannot reopen from a branch embarked after the shared save`(reverseBranches: Bool) throws {
        let stale = try finalBossSave()
        let run = try #require(stale.voyage.activeRun)
        let boss = try #require(run.nextNode)
        var base = stale
        base.voyage.activeRun = nil
        let completed = try completeFinalBoss(stale)
        let incoming = reverseBranches ? stale : completed
        let existing = reverseBranches ? completed : stale

        for preferIncoming in [true, false] {
            let merged = CloudSaveMerge.merge(incoming: incoming, existing: existing, base: base, preferIncoming: preferIncoming)
            let context = try PersistenceTestContext()
            try SaveTestSupport.writeRoot(merged, to: context.storeURL())
            var reloaded = try context.makeSaveStore().currentSave
            #expect(reloaded.voyage.activeRun == nil)
            #expect(!reloaded.voyage.offers.contains { $0.id == run.id })
            #expect(!reloaded.voyage.isPlayable(runID: run.id, nodeID: boss.id))
            let embarked = reloaded.voyage.embark(offerID: run.id, eligibleRecruitEventIDs: [], access: .fullGame)
            #expect(!embarked)
        }
    }

    @Test @MainActor func `two offline final boss victories retain one payout after reload`() throws {
        let base = try finalBossSave()
        let first = try completeFinalBoss(base)
        var second = try completeFinalBoss(base)
        second.homestead.resources[.stone] = 7
        #expect(first.voyage.activeRun == nil)
        #expect(second.voyage.activeRun == nil)
        for preferIncoming in [true, false] {
            let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: preferIncoming)
            let context = try PersistenceTestContext()
            try SaveTestSupport.writeRoot(merged, to: context.storeURL())
            let reloaded = try context.makeSaveStore().currentSave
            #expect(reloaded.roster.gold == first.roster.gold)
            #expect(reloaded.roster.progression(for: base.roster.activeHero) == first.roster.progression(for: base.roster.activeHero))
            #expect(reloaded.homestead.resources[.wood] == first.homestead.resources[.wood])
            #expect(reloaded.homestead.resources[.stone] == 7)
            #expect(reloaded.voyage.activeRun == nil)
            #expect(reloaded.voyage.completedRunIDs == first.voyage.completedRunIDs)
            #expect(CloudSaveMerge.hasDuplicateClaim(incoming: first, existing: reloaded, base: base))
        }
    }

    @Test func `abandoning the same Voyage does not discard independent rewards`() throws {
        let base = try finalBossSave()
        let runID = try #require(base.voyage.activeRun?.id)
        var first = base
        var second = base
        let firstAbandoned = first.voyage.abandon(runID: runID, access: .fullGame)
        let secondAbandoned = second.voyage.abandon(runID: runID, access: .fullGame)
        #expect(firstAbandoned && secondAbandoned)
        first.roster.gold += 10
        second.roster.gold += 20
        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.roster.gold == base.roster.gold + 30)
    }

    @Test func `existing Voyage payloads remain readable without completion history`() throws {
        let base = try finalBossSave()
        var json = try #require(JSONSerialization.jsonObject(with: base.voyage.encodedPayload) as? [String: Any])
        json.removeValue(forKey: "completedRunIDs")
        let restored = try PlayerVoyageState.decodePayload(JSONSerialization.data(withJSONObject: json))
        #expect(!restored.isUnreadable)
        #expect(restored.activeRun == base.voyage.activeRun)
    }

    @Test @MainActor func `invalid completed Voyage data stays unreadable instead of disappearing`() throws {
        var valid = try finalBossSave()
        let run = try #require(valid.voyage.activeRun)
        for node in run.nodes {
            valid.voyage.updateNode(runID: run.id, nodeID: node.id) { $0.isCleared = true }
        }
        let normalized = PlayerVoyageState.decodePayload(valid.voyage.encodedPayload)
        #expect(!normalized.isUnreadable)
        #expect(normalized.activeRun == nil)
        #expect(normalized.completedRunIDs == [run.id])

        var invalid = valid
        invalid.voyage.activeRun?.nodes.removeLast()
        let payload = invalid.voyage.encodedPayload
        let preserved = PlayerVoyageState.decodePayload(payload)
        #expect(preserved.isUnreadable)
        #expect(preserved.encodedPayload == payload)
        let context = try PersistenceTestContext()
        try SaveTestSupport.writeRoot(invalid, to: context.storeURL())
        let reloaded = try context.makeSaveStore()
        #expect(reloaded.voyage.isUnreadable)
        #expect(reloaded.voyage.encodedPayload == payload)
    }

    private func finalBossSave() throws -> PlayerSave {
        var base = SaveTestSupport.makeSave()
        base.roster.gold = 10
        base.homestead.resources = [:]
        base.homestead.lastProductionAt = Date().addingTimeInterval(86400)
        base.voyage.ensureBoard(access: .fullGame)
        let offer = try #require(base.voyage.offers.first)
        let embarked = base.voyage.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .fullGame)
        #expect(embarked)
        let run = try #require(base.voyage.activeRun)
        for node in run.nodes.dropLast() {
            base.voyage.updateNode(runID: run.id, nodeID: node.id) { $0.isCleared = true }
        }
        return base
    }

    private func completeFinalBoss(_ base: PlayerSave) throws -> PlayerSave {
        var save = base
        let run = try #require(base.voyage.activeRun)
        let boss = try #require(run.nextNode)
        #expect(boss.type == .boss)
        let hero = save.roster.activeHero
        let companion = save.roster.activeCompanion
        let plan = BattleRewardPlan(
            stageGold: 10, goldFindPercent: 0, heroExperience: 15, companionExperience: 15,
            materials: [ResourceAmount(.wood, 3)], items: [],
        )
        let settled = plan.settle(
            battleGold: .init(), inputs: RewardSettlementInputs(save: save, hero: hero, companion: companion),
        )
        #expect(VoyageCompletion.completeBattle(
            runID: run.id, nodeID: boss.id, hero: hero, companion: companion,
            rewards: (settled: settled, earned: plan.resolve(battleGold: .init()), encounterLevel: 12),
            save: &save, access: .fullGame,
        ) == .completed)
        return save
    }
}
