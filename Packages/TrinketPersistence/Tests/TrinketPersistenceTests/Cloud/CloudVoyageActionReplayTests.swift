import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct CloudVoyageActionReplayTests {
    @Test(arguments: GeneratedCaseSeeds.values(defaultCount: 32))
    func `replayed Voyage claims pay once across retries and conflicting rewards`(seed: UInt64) throws {
        var base = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 2000000000))
        base.roster.gold = 100
        base.homestead = PlayerHomesteadState(
            resources: [:], nodeTiers: [:], lastProductionAt: base.modifiedAt,
        )
        let candidate = (1 ... 64).lazy.map { UInt64($0) }.first {
            let offer = VoyageOffer(id: "route-\(seed)", chapterID: "chapter-1", difficulty: .easy, seed: $0)
            return VoyageGenerator.nodes(for: offer, eligibleRecruitEventIDs: [])[1].type == .battle
        }
        let routeSeed = try #require(candidate)
        let offer = VoyageOffer(id: "route-\(seed)", chapterID: "chapter-1", difficulty: .easy, seed: routeSeed)
        base.voyage.activeRun = VoyageRun(
            offer: offer, nodes: VoyageGenerator.nodes(for: offer, eligibleRecruitEventIDs: []),
        )
        let firstGold = Int(seed % 13) + 1
        let firstWood = Int(seed % 7) + 1
        let nextGold = Int(seed % 11) + 1
        let nextWood = Int(seed % 5) + 1
        let accepted = try claimNextBattle(base, gold: firstGold, wood: firstWood)
        let conflict = try claimNextBattle(base, gold: firstGold + 20, wood: firstWood + 10)
        let next = try claimNextBattle(conflict.after.restored(), gold: nextGold, wood: nextWood)
        let head = CloudSaveHead(
            epoch: "epoch", resetCount: 0, authoritySequence: 0,
            revision: CloudSaveRevision(id: "base", clock: ["remote": 1], snapshot: CloudSaveSnapshot(base)),
        )
        var replay = CloudReceiptReplay(head: head)

        let first = try replay.apply(accepted, collectionPositions: [:], onto: base)
        let retried = try replay.apply(accepted, collectionPositions: [:], onto: first)
        let skipped = try replay.apply(conflict, collectionPositions: [:], onto: retried)
        let both = try replay.apply(next, collectionPositions: [:], onto: skipped)
        let retriedNext = try replay.apply(next, collectionPositions: [:], onto: both)

        #expect(retried == first)
        #expect(skipped == first)
        #expect(retriedNext == both)
        #expect(both.roster.gold == 100 + firstGold + nextGold)
        #expect(both.homestead.resources[.wood] == firstWood + nextWood)
        let run = try #require(both.voyage.activeRun)
        let firstTwoCleared = run.nodes.prefix(2).allSatisfy(\.isCleared)
        #expect(firstTwoCleared)
        #expect(run.earnedGold == firstGold + nextGold)
        #expect(run.earnedMaterials[.wood] == firstWood + nextWood)
    }

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
        let firstTwoCleared = run.nodes.prefix(2).allSatisfy(\.isCleared)
        #expect(firstTwoCleared)
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
        let completion = VoyageCompletion.completeBattle(
            runID: run.id, nodeID: node.id, party: (hero, companion),
            rewards: (settled: settlement, earned: plan.resolve(battleGold: .init()), encounterLevel: 12),
            save: &after, access: .free,
        )
        #expect(completion == .completed)
        return ResolvedSaveAction(
            before: CloudSaveSnapshot(before), after: CloudSaveSnapshot(after), kind: .reward,
            claim: .voyage(runID: run.id, nodeID: node.id),
        )
    }
}
