import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct BattleRewardClaimTests {
    @Test(arguments: [false, true]) @MainActor
    func `old battle cannot reward reset or replaced progress`(replacesExternally: Bool) throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let stage = try #require(GameContent.chapters.first?.stages.first)
        let hero = store.roster.activeHero
        let companion = store.roster.activeCompanion
        let claims = [BattleCompletionDestination.journey(stage), nil].map {
            store.prepareBattleRewardClaim(at: $0, heroID: hero.id, companionID: companion.id)
        }
        let award = plan.settle(
            battleGold: .init(),
            inputs: RewardSettlementInputs(save: store.currentSave, hero: hero, companion: companion),
        )
        if replacesExternally {
            var incoming = store.currentSave
            incoming.corruptionAltarCooldownRemaining += 1
            // Preserve seed and economic inputs: only the save generation changes.
            try store.commitCloudState(store.cloudDeviceState, replacing: incoming)
        } else {
            try store.resetGameplayProgress()
        }
        let before = store.currentSave
        for claim in claims {
            guard case .rejected = store.completeBattle(claim, award: award, enemyEncounterLevel: 1),
                  case .rejected = store.claimDefeatExperience(claim, award: award) else {
                Issue.record("An old battle changed replacement progress")
                return
            }
        }
        #expect(store.currentSave == before)
        #expect(try context.makeReloadedStore().currentSave == before)
    }

    @Test @MainActor func `failed victory retains its claim and committed victory consumes it across outcomes`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let hero = store.roster.activeHero
        let companion = store.roster.activeCompanion
        let claim = store.prepareBattleRewardClaim(at: nil, heroID: hero.id, companionID: companion.id)
        let before = store.currentSave
        let award = plan.settle(battleGold: .init(), inputs: RewardSettlementInputs(save: before, hero: hero, companion: companion))
        store.forcesNextSaveFailure = true
        guard case .persistFailed = store.completeBattle(claim, award: award, enemyEncounterLevel: nil) else {
            Issue.record("Expected a refused durable write")
            return
        }
        #expect(store.currentSave == before)
        // Attaching this unchanged local save is metadata, not replacement progress.
        var metadata = store.cloudDeviceState
        metadata.activeAccountID = "account"
        try store.commitCloudState(metadata)
        guard case .committed = store.completeBattle(claim, award: award, enemyEncounterLevel: nil) else {
            Issue.record("The failed write consumed the claim")
            return
        }
        let duplicate = plan.settle(
            battleGold: .init(),
            inputs: RewardSettlementInputs(save: store.currentSave, hero: hero, companion: companion),
        )
        guard case .rejected = store.completeBattle(claim, award: duplicate, enemyEncounterLevel: nil),
              case .rejected = store.claimDefeatExperience(claim, award: duplicate) else {
            Issue.record("A consumed victory paid twice")
            return
        }
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == before.roster.gold + award.award.goldDelta)
        #expect(reloaded.roster.progression(for: hero) == award.heroProgressionAfter)
        #expect(reloaded.roster.progression(for: companion) == award.companionProgressionAfter)
    }

    @Test @MainActor func `claims reject another store and stale settlements without consuming a current claim`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let hero = store.roster.activeHero
        let companion = store.roster.activeCompanion
        let claim = store.prepareBattleRewardClaim(at: nil, heroID: hero.id, companionID: companion.id)
        let award = plan.settle(
            battleGold: .init(),
            inputs: RewardSettlementInputs(save: store.currentSave, hero: hero, companion: companion),
        )
        let peer = try context.makeReloadedStore()
        guard case .rejected = peer.completeBattle(claim, award: award, enemyEncounterLevel: nil) else {
            Issue.record("Another store accepted a foreign claim")
            return
        }
        try #require(store.persistFixtureBatch(logging: "Change wallet before claim") { $0.roster.gold += 1 })
        let before = store.currentSave
        guard case .rejected = store.completeBattle(claim, award: award, enemyEncounterLevel: nil) else {
            Issue.record("A stale settlement changed the wallet")
            return
        }
        #expect(store.currentSave == before)
        let refreshed = plan.settle(battleGold: .init(), inputs: RewardSettlementInputs(save: before, hero: hero, companion: companion))
        guard case .committed = store.completeBattle(claim, award: refreshed, enemyEncounterLevel: nil) else {
            Issue.record("A rejected settlement consumed the claim")
            return
        }
        #expect(try context.makeReloadedStore().roster.gold == before.roster.gold + refreshed.award.goldDelta)
    }

    private var plan: BattleRewardPlan {
        BattleRewardPlan(stageGold: 12, goldFindPercent: 0, heroExperience: 4, companionExperience: 5, materials: [], items: [])
    }
}
