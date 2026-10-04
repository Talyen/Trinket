import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CoolMossPartyDamageTests {
    @Test(arguments: [(true, true, 11), (true, false, 10), (false, true, 10)])
    func `Cool Moss strengthens companion Freeze against poisoned enemies while Druid lives`(
        heroAlive: Bool, poisoned: Bool, expectedDamage: Int,
    ) throws {
        let druid = try BattleTestFixtures.catalogBuild(combatantID: "druid", talents: "druid_poison_t2_1")
        let whelp = try BattleTestFixtures.catalogBuild(combatantID: "frost_whelp")
        var battle = BattleStateTestFactory.makeBattle(
            hero: druid.combatant, companion: whelp.combatant,
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: druid.modifiers, companionModifiers: whelp.modifiers,
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        if poisoned {
            battle.appendEffect(.poison(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }
        if !heroAlive {
            battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 0 }
        }

        let result = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .freeze, sourceActorID: battle.companion.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(result.healthLost == expectedDamage)
    }
}
