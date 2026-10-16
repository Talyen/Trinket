import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct FullHealthAttackPreparationTests {
    @Test(arguments: [false, true])
    func `Sanguine Overflow waits until a later ability even when Bloodthorn repeats`(cardFrame: Bool) {
        var profile = CombatantTalentCatalog.profile(for: ["warlock_leech_t3_1"])
        profile.triggers.criticalChanceBonus = -1
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.dodgeChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroHealth: 19, heroModifiers: profile, enemyModifiers: enemyProfile, appliesFightPacing: false,
        )
        let card = cardFrame ? battle.resolution.beginCard(actorID: battle.hero.id) : nil

        let creatingHits = battle.performTestAction(.bloodthorn)

        #expect(battle.health(of: battle.hero) == 20)
        #expect(creatingHits.filter { $0.effectKind == .leechHeal }.map(\.amount) == [1])
        #expect(creatingHits.filter { $0.kind == .abilityDamage }.map(\.amount) == [2, 1])
        if let card {
            let repeatedHits = battle.performTestAction(.bloodthorn)
            #expect(repeatedHits.filter { $0.kind == .abilityDamage }.map(\.amount) == [2, 1])
            battle.resolution.endCard(card)
        }

        let nextHits = battle.performTestAction(.bloodthorn)
        #expect(nextHits.filter { $0.kind == .abilityDamage }.map(\.amount) == [3, 1])
        let unpreparedHits = battle.performTestAction(.bloodthorn)
        #expect(unpreparedHits.filter { $0.kind == .abilityDamage }.map(\.amount) == [2, 1])
    }
}
