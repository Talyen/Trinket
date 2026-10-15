import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CounterattackManaPreparationTests {
    @Test func `Arcane Surge draws when Knights Answer spends the last Mana`() throws {
        let fixtures = UniqueCollectionTests()
        var profile = CombatantTalentCatalog.profile(for: ["wizard_mana_t3_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = try fixtures.battle(["the_knights_answer"], extra: profile, heroBasic: .rayOfFrost)
        battle.roster.hero.currentMana = 3
        battle.heroDeck = CombatDeck(abilities: [.block, .slash])
        fixtures.block(5, owner: .hero, in: &battle)

        let hit = fixtures.enemyHit(1, in: &battle)

        #expect(battle.mana(of: battle.hero) == 0)
        #expect(hit.events.contains { $0.kind == .ability && $0.abilityID == Ability.rayOfFrost.id })
        #expect(hit.events.count { $0.effectKind == .cardsDrawn && $0.abilityName == "Arcane Surge" } == 1)
        #expect(battle.hand.cards.map(\.ability.id) == [Ability.block.id])
    }

    @Test(arguments: [("wizard_mana_t2_1", 0.2, 5), ("warlock_burn_t2_2", 0.5, 6)])
    func `counterattack Mana preparations empower a later attack`(
        talentID: String, expectedPercent: Double, laterDamage: Int,
    ) {
        let ability = Ability(
            id: "mana-counterattack", name: "Mana Counterattack", tier: .basic,
            damageComponents: [DamageComponent(4, keyword: .burn)], criticalChanceBonus: -1,
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 3, heroMana: 3,
            heroModifiers: CombatantTalentCatalog.profile(for: [talentID]), dealOpeningHand: false, appliesFightPacing: false,
        )
        let beforePreparation = battle.health(of: battle.enemy)

        _ = BattleTurnEngine.performAction(
            ability: ability, actor: battle.hero, abilityTarget: battle.enemy,
            origin: .counterattack, context: &battle,
        )

        #expect(beforePreparation - battle.health(of: battle.enemy) == 5)
        #expect(battle.mana(of: battle.hero) == 0)
        let pending = battle.roster.runtime(for: battle.hero)?.talents.pending
        #expect((pending?.overchargePercent ?? pending?.nextBurnAttackPercent)?.value == expectedPercent)
        let beforeLaterAttack = battle.health(of: battle.enemy)

        _ = battle.performTestAction(ability)

        #expect(beforeLaterAttack - battle.health(of: battle.enemy) == laterDamage)
        #expect(battle.roster.runtime(for: battle.hero)?.talents.pending.overchargePercent == nil)
        #expect(battle.roster.runtime(for: battle.hero)?.talents.pending.nextBurnAttackPercent == nil)
        let beforeUnpreparedAttack = battle.health(of: battle.enemy)

        _ = battle.performTestAction(ability)

        #expect(beforeUnpreparedAttack - battle.health(of: battle.enemy) == 4)
    }
}
