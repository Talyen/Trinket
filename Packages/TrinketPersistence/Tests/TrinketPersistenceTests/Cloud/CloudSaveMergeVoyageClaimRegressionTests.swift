import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct CloudSaveMergeVoyageClaimRegressionTests {
    @Test @MainActor func `merged Voyage totals retain the final bonus for rewards earned on either device`() throws {
        var base = SaveTestSupport.makeSave()
        base.roster.gold = 10
        base.homestead = PlayerHomesteadState(resources: [:], nodeTiers: [:], lastProductionAt: Date(timeIntervalSince1970: 2000000000))
        base.voyage.ensureBoard(access: .free)
        let offer = try #require(base.voyage.offers.first)
        let embarked = base.voyage.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .free)
        #expect(embarked)
        let run = try #require(base.voyage.activeRun)
        let battle = try #require(run.nextNode)
        #expect(battle.type == .battle)
        func claim(gold: Int, wood: Int) -> PlayerSave {
            var save = base
            let hero = save.roster.activeHero
            let companion = save.roster.activeCompanion
            let plan = BattleRewardPlan(
                stageGold: gold, goldFindPercent: 0, heroExperience: 0, companionExperience: 0,
                materials: [ResourceAmount(.wood, wood)], items: [],
            )
            let settled = plan.settle(battleGold: .init(), inputs: RewardSettlementInputs(save: save, hero: hero, companion: companion))
            #expect(VoyageCompletion.completeBattle(
                runID: run.id, nodeID: battle.id, party: (hero, companion),
                rewards: (settled: settled, earned: plan.resolve(battleGold: .init()), encounterLevel: 12),
                save: &save, access: .free,
                recordReceipt: { _ in },
            ) == .completed)
            return save
        }
        var first = claim(gold: 20, wood: 3)
        first.modifiedAt = Date(timeIntervalSince1970: 100)
        var second = claim(gold: 10, wood: 5)
        second.modifiedAt = Date(timeIntervalSince1970: 200)
        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        let context = try PersistenceTestContext()
        let reloaded = try context.seedAndReload(merged).currentSave
        let retained = try #require(reloaded.voyage.activeRun)
        #expect(reloaded.roster.gold == 30)
        #expect(reloaded.homestead.resources[.wood] == 5)
        #expect(retained.earnedGold == 20)
        #expect(retained.earnedMaterials[.wood] == 5)
        let bossAward = BattleRewardPlan(
            stageGold: 5, goldFindPercent: 0, heroExperience: 0, companionExperience: 0,
            materials: [ResourceAmount(.wood, 5)], items: [],
        ).resolve(battleGold: .init())
        let final = VoyageCompletionBonus(gold: retained.earnedGold, materials: retained.earnedMaterials).applying(to: bossAward)
        #expect(final.goldGained == 10)
        #expect(final.materials == [ResourceAmount(.wood, 7)])
    }

    @Test @MainActor func `retired destinations on a newer stale board are replaced after merge and reload`() throws {
        var stale = SaveTestSupport.makeSave()
        stale.voyage.ensureBoard(access: .free)
        let retired = Set(stale.voyage.offers.map(\.id))
        var completed = stale
        completed.voyage.completedRunIDs = retired
        completed.modifiedAt = Date(timeIntervalSince1970: 100)
        stale.modifiedAt = Date(timeIntervalSince1970: 200)
        let merged = CloudSaveMerge.merge(incoming: completed, existing: stale, base: nil, preferIncoming: false)
        let context = try PersistenceTestContext()
        try SaveTestSupport.writeRoot(merged, to: context.storeURL())
        let store = try context.makeSaveStore()
        #expect(store.persistBatch(logging: "Repair retired Voyage board") { save in
            save.voyage.ensureBoard(access: .free)
        })
        var reloaded = try context.makeReloadedStore().currentSave
        #expect(reloaded.voyage.offers.count == 3)
        #expect(retired.isDisjoint(with: Set(reloaded.voyage.offers.map(\.id))))
        #expect(reloaded.voyage.offers.map(\.difficulty) == VoyageDifficulty.allCases)
        #expect(Set(reloaded.voyage.offers.map(\.chapterID)) == ["chapter-1", "chapter-2", "chapter-3"])
        let next = try #require(reloaded.voyage.offers.first)
        let embarked = reloaded.voyage.embark(offerID: next.id, eligibleRecruitEventIDs: [], access: .free)
        #expect(embarked)
    }

    @Test(arguments: [false, true]) @MainActor
    func `abandoned Voyage stays retired without a shared base after disk reload`(reverseBranches: Bool) throws {
        var stale = try finalBossSave()
        let run = try #require(stale.voyage.activeRun)
        var abandoned = stale
        let retired = abandoned.voyage.abandon(runID: run.id, access: .fullGame)
        #expect(retired)
        abandoned.modifiedAt = Date(timeIntervalSince1970: 100)
        stale.modifiedAt = Date(timeIntervalSince1970: 200)
        let incoming = reverseBranches ? stale : abandoned
        let existing = reverseBranches ? abandoned : stale
        let merged = CloudSaveMerge.merge(incoming: incoming, existing: existing, base: nil, preferIncoming: true)
        let context = try PersistenceTestContext()
        try SaveTestSupport.writeRoot(merged, to: context.storeURL())
        let reloaded = try context.makeSaveStore().currentSave

        #expect(reloaded.voyage.activeRun == nil)
        #expect(reloaded.voyage.abandonedRunIDs == [run.id])
        #expect(reloaded.voyage.completedRunIDs == nil)
        #expect(!reloaded.voyage.offers.contains { $0.id == run.id })
        #expect(!reloaded.voyage.isPlayable(runID: run.id, nodeID: run.nodes[0].id))
    }

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

    @Test func `existing Voyage payloads remain readable without retirement history`() throws {
        let base = try finalBossSave()
        var json = try #require(JSONSerialization.jsonObject(with: base.voyage.encodedPayload) as? [String: Any])
        json.removeValue(forKey: "completedRunIDs")
        json.removeValue(forKey: "abandonedRunIDs")
        let restored = try PlayerVoyageState.decodePayload(JSONSerialization.data(withJSONObject: json))
        #expect(!restored.isUnreadable)
        #expect(restored.activeRun == base.voyage.activeRun)
        #expect(restored.abandonedRunIDs == nil)
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
            runID: run.id, nodeID: boss.id, party: (hero, companion),
            rewards: (settled: settled, earned: plan.resolve(battleGold: .init()), encounterLevel: 12),
            save: &save, access: .fullGame,
            recordReceipt: { _ in },
        ) == .completed)
        return save
    }
}
