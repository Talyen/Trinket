import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct FullHealthAttackPreparationTests {
    @Test(arguments: [false, true])
    func `Sanguine Overflow waits until a later ability even when a multi hit Leech attack repeats`(cardFrame: Bool) {
        var profile = CombatantTalentCatalog.profile(for: ["warlock_leech_t3_1"])
        profile.triggers.criticalChanceBonus = -1
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.dodgeChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroHealth: 19, heroModifiers: profile, enemyModifiers: enemyProfile, appliesFightPacing: false,
        )
        let card = cardFrame ? battle.resolution.beginCard(actorID: battle.hero.id) : nil
        let ability = Ability(
            id: "split-leech", name: "Split Leech", tier: .ultimate,
            damageComponents: [DamageComponent(2, keyword: .bleed, hasLeech: true), DamageComponent(1, keyword: .poison)],
        )

        let creatingHits = battle.performTestAction(ability)

        #expect(battle.health(of: battle.hero) == 20)
        #expect(creatingHits.filter { $0.effectKind == .leechHeal }.map(\.amount) == [1])
        #expect(creatingHits.filter { $0.kind == .abilityDamage }.map(\.amount) == [2, 1])
        if let card {
            let repeatedHits = battle.performTestAction(ability)
            #expect(repeatedHits.filter { $0.kind == .abilityDamage }.map(\.amount) == [2, 1])
            battle.resolution.endCard(card)
        }

        let nextHits = battle.performTestAction(ability)
        #expect(nextHits.filter { $0.kind == .abilityDamage }.map(\.amount) == [3, 1])
        let unpreparedHits = battle.performTestAction(ability)
        #expect(unpreparedHits.filter { $0.kind == .abilityDamage }.map(\.amount) == [2, 1])
    }
}
