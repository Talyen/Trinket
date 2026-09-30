import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct ThreefoldPacketRegressionTests {
    @Test(arguments: [
        (Keyword.burn, DamageOperation.resolvedPeriodic),
        (.freeze, .periodic),
        (.holy, .reaction()),
        (.holy, .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1)),
    ], [BattleParticipant.hero, .companion])
    func `Threefold rewards each qualifying elemental damage packet once`(
        packet: (Keyword, DamageOperation),
        owner: BattleParticipant,
    ) throws {
        var bonus = CombatModifierProfile.zero
        bonus.triggers.threefoldElementalDamageManaChancePercent = 0.90
        var context = try UniqueCollectionTests().battle(["threefold_grace"], owner: owner, extra: bonus)
        let source: BattleParticipant = owner == .hero ? .companion : .hero
        let outcome = context.resolveDamage(DamageRequest(
            amount: 5, target: context.roster.enemy.combatant, keyword: packet.0,
            sourceActorID: context.roster[source].id, options: packet.1,
        ))

        #expect(outcome.healthLost == 5)
        #expect(context.roster[owner].currentMana == 1)
        #expect(context.roster[source].currentMana == 0)
        #expect(outcome.events.count { $0.abilityName == "Threefold Grace" && $0.keyword == .mana } == 1)
    }
}
