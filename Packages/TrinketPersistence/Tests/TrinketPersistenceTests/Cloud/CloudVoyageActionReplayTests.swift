import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct CloudVoyageActionReplayTests {
    @Test @MainActor func `accepted Voyage actions exclude earlier rejected rewards from the final bonus after reload`() throws {
        var base = SaveTestSupport.makeSave()
        base.roster.gold = 100
        base.homestead = PlayerHomesteadState(
            resources: [:], nodeTiers: [:], lastProductionAt: Date(timeIntervalSince1970: 2000000000),
        )
        let candidate = (1 ... 64).lazy.map {
            VoyageOffer(id: "shared-voyage", chapterID: "chapter-1", difficulty: .easy, seed: UInt64($0))
        }.first {
            VoyageGenerator.nodes(for: $0, eligibleRecruitEventIDs: [])[1].type == .battle
        }
        let offer = try #require(candidate)
        base.voyage.activeRun = VoyageRun(
            offer: offer, nodes: VoyageGenerator.nodes(for: offer, eligibleRecruitEventIDs: []),
        )
        let accepted = try claimNextBattle(base, gold: 10, wood: 3)
        let duplicate = try claimNextBattle(base, gold: 20, wood: 7)
        let localAfterDuplicate = try duplicate.after.restored()
        let next = try claimNextBattle(localAfterDuplicate, gold: 5, wood: 2)
        let existing = try accepted.after.restored()
        let initialHead = CloudSaveHead(
            epoch: "epoch", resetCount: 0, authoritySequence: 0,
            revision: CloudSaveRevision(id: "remote", clock: ["remote": 1], snapshot: accepted.after),
        )
        var replay = CloudReceiptReplay(head: initialHead)
        let skipped = try replay.apply(duplicate, collectionPositions: [:], onto: existing)
        #expect(skipped == existing)

        var positions: [HomesteadResource: UInt64] = [:]
        let records = try ResolvedSaveAction.records([duplicate, next], following: duplicate.before, positions: &positions)
        let mutation = CloudSaveMutation(
            id: "two-voyage-actions", changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: duplicate.before, after: next.after, actions: records,
        )
        let journal = try JSONDecoder().decode(CloudSaveJournal.self, from: JSONEncoder().encode(CloudSaveJournal([mutation])))
        let request = CloudSaveRequest(
            id: "upload", action: .upload, baseEpoch: "epoch", baseRevisionID: "base", authoritySequence: 0,
            revision: CloudSaveRevision(id: "upload", clock: ["incoming": 1], snapshot: next.after),
            baseSnapshot: CloudSaveSnapshot(base), mutations: journal,
        )
        let server = CloudServerSave(head: initialHead, changeToken: Data(), serverTime: base.homestead.lastProductionAt)
        let head = try CloudSaveReconciler.resolve(request, against: server).head
        let merged = try head.revision.snapshot.restored()
        let context = try PersistenceTestContext()
        let reloaded = try context.seedAndReload(merged).currentSave
        let run = try #require(reloaded.voyage.activeRun)
        #expect(reloaded.roster.gold == 115)
        #expect(reloaded.homestead.resources[.wood] == 5)
        #expect(run.nodes.prefix(2).allSatisfy(\.isCleared))
        #expect(run.earnedGold == 15)
        #expect(run.earnedMaterials == [.wood: 5])
        let bossAward = BattleRewardPlan(
            stageGold: 5, goldFindPercent: 0, heroExperience: 0, companionExperience: 0,
            materials: [ResourceAmount(.wood, 1)], items: [],
        ).resolve(battleGold: .init())
        let final = VoyageCompletionBonus(gold: run.earnedGold, materials: run.earnedMaterials).applying(to: bossAward)
        #expect(final.goldGained == 9)
        #expect(final.materials == [ResourceAmount(.wood, 2)])
    }

    private func claimNextBattle(_ before: PlayerSave, gold: Int, wood: Int) throws -> ResolvedSaveAction {
        var after = before
        let run = try #require(before.voyage.activeRun)
        let node = try #require(run.nextNode)
        #expect(node.type == .battle)
        let hero = before.roster.activeHero
        let companion = before.roster.activeCompanion
        let plan = BattleRewardPlan(
            stageGold: gold, goldFindPercent: 0, heroExperience: 0, companionExperience: 0,
            materials: [ResourceAmount(.wood, wood)], items: [],
        )
        let settlement = plan.settle(
            battleGold: .init(), inputs: RewardSettlementInputs(save: before, hero: hero, companion: companion),
        )
        #expect(VoyageCompletion.completeBattle(
            runID: run.id, nodeID: node.id, party: (hero, companion),
            rewards: (settled: settlement, earned: plan.resolve(battleGold: .init()), encounterLevel: 12),
            save: &after, access: .free,
        ) == .completed)
        return ResolvedSaveAction(
            before: CloudSaveSnapshot(before), after: CloudSaveSnapshot(after), kind: .reward,
            claim: .voyage(runID: run.id, nodeID: node.id),
        )
    }
}
