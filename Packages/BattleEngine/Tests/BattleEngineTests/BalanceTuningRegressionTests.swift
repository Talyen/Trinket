import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct BalanceTuningRegressionTests {
    @Test(arguments: [false, true])
    func `hit scoped Leech stays on one hit through Mana empowerment`(empowered: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 5
        let ability = empowered ? Ability(
            id: "empowered-leech", name: "Empowered Leech", tier: .skill,
            damageComponents: [DamageComponent(2, keyword: .burn, hasLeech: true), DamageComponent(1, keyword: .poison)],
        ).empoweredByMana(amount: 2) : Ability(
            id: "split-leech", name: "Split Leech", tier: .ultimate,
            damageComponents: [DamageComponent(2, keyword: .bleed, hasLeech: true), DamageComponent(1, keyword: .poison)],
        )
        let events = battle.performTestAction(ability)
        #expect(events.count { $0.effectKind == .leechHeal } == 1)
        #expect(battle.health(of: battle.hero) == (empowered ? 7 : 6))
    }

    @Test(arguments: [Keyword.bleed, .poison])
    func `Bloodthorn resolves one alternative hit and leeches from either outcome`(keyword: Keyword) throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 5
        battle.rng = try BattleTestFixtures.rngSelectingOutcome(.bloodthorn, in: battle) {
            $0.damageComponents.first?.keyword == keyword
        }
        let events = battle.performTestAction(.bloodthorn)
        let hits = events.filter { $0.kind == .abilityDamage }
        #expect(hits.map(\.keyword) == [keyword])
        #expect(hits.first?.amount == 3)
        #expect(events.filter { $0.effectKind == .leechHeal }.map(\.amount) == [2])
        #expect(battle.health(of: battle.hero) == 7)
    }

    @Test(arguments: [9, 10, 11])
    func `emberdrinker checks health on the first Burn attack rather than a later hit`(health: Int) {
        var profile = CombatantTalentCatalog.profile(for: ["warlock_leech_t4_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 20, heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = health
        let ability = Ability(
            id: "two-burn-hits", name: "Two Burn Hits", tier: .basic,
            damageComponents: [DamageComponent(4, keyword: .burn), DamageComponent(4, keyword: .burn)],
        )
        let first = battle.performTestAction(ability)
        #expect(first.count { $0.effectKind == .leechHeal } == (health < 10 ? 2 : 0))
        battle.roster.hero.currentHealth = 1
        let later = battle.performTestAction(ability)
        #expect(!later.contains { $0.effectKind == .leechHeal })
        battle.turnCount += 1
        let nextTurn = battle.performTestAction(ability)
        #expect(nextTurn.count { $0.effectKind == .leechHeal } == 2)
    }

    @Test func `lucky break draws once per turn on actual Gold gains`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash, .pounce, .hemorrhage],
            heroModifiers: CombatantTalentCatalog.profile(for: ["wildcard_gold_t4_1"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.grantGoldEvent(0, to: battle.hero, abilityName: "No Gold")
        #expect(battle.hand.isEmpty)
        battle.grantGoldEvent(1, to: battle.hero, abilityName: "Gold")
        #expect(battle.hand.count == 1)
        battle.grantGoldEvent(2, to: battle.hero, abilityName: "Gold")
        #expect(battle.hand.count == 1)
        battle.turnCount += 1
        battle.grantGoldEvent(1, to: battle.hero, abilityName: "Steal", isTheft: true)
        #expect(battle.hand.count == 2)
    }

    @Test func `fox steals half Block on only the first actual theft each turn`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["fox_gold_t4_1"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(5, on: battle.enemy, in: &battle)
        battle.grantGoldEvent(2, to: battle.companion, abilityName: "Gold")
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 5)
        battle.grantGoldEvent(2, to: battle.companion, abilityName: "Steal", isTheft: true)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 3)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 2)
        battle.grantGoldEvent(2, to: battle.companion, abilityName: "Steal", isTheft: true)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 3)
        battle.turnCount += 1
        DefensePoolEngine.set(0, on: battle.enemy, in: &battle)
        battle.grantGoldEvent(2, to: battle.companion, abilityName: "Steal", isTheft: true)
        DefensePoolEngine.set(6, on: battle.enemy, in: &battle)
        battle.grantGoldEvent(2, to: battle.companion, abilityName: "Steal", isTheft: true)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 6)
        battle.turnCount += 1
        battle.grantGoldEvent(2, to: battle.companion, abilityName: "Steal", isTheft: true)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 3)
    }
}
