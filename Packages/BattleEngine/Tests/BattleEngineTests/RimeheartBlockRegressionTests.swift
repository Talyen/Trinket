import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct RimeheartBlockRegressionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Rimeheart copies Freeze Health damage without scaling Block or spending preparation`(owner: BattleParticipant) throws {
        let locket = try #require(GameContent.unique(matching: "rimeheart_locket"))
        let signature = try #require(locket.affixPowers?.first)
        var profile = CombatModifierProfile(blockGainedBonus: 3)
        profile.merge(signature.modifiers)
        signature.triggers.apply(to: &profile, abilityName: locket.displayName)
        profile.triggers.blockGainBelowHalfMultiplier = 1.5
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10,
            companionHealth: 10,
            heroModifiers: owner == .hero ? profile : .zero,
            companionModifiers: owner == .companion ? profile : .zero,
        )
        battle.appliesFightPacing = false
        let actor = battle.roster[owner].combatant
        battle.roster.mutateRuntime(for: actor) {
            $0.talents.pending.nextBlockGainMultiplier = PreparedTalentBonus(value: 2)
        }

        let outcome = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: .freeze, sourceActorID: actor.id,
            options: .effect(scaling: .flat),
        ))

        #expect(outcome.healthLost == 8)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster[owner].activeEffects) == outcome.healthLost)
        #expect(battle.roster.runtime(for: actor)?.talents.pending.nextBlockGainMultiplier?.value == 2)
        #expect(outcome.events.contains {
            $0.effectKind == .shieldApplied && $0.abilityName == locket.displayName && $0.amount == outcome.healthLost
        })
    }
}
