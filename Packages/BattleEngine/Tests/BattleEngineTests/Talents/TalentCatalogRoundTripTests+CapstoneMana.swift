import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `dragon patronage grants hero block once when companion empowers a freeze ability`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 0, heroMana: 0,
            companionMaxMana: 8, companionMana: 3,
            companionModifiers: CombatantTalentCatalog.profile(for: ["frost_whelp_mana_t4_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        var card = Ability.rayOfFrost
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(for: &card, actor: battle.companion, context: &battle)
        #expect(card.damageComponents == [
            DamageComponent(2, keyword: .freeze),
            DamageComponent(2, keyword: .freeze),
        ])
        #expect(battle.roster.hero.currentMana == 0)
        #expect(battle.roster.companion.currentMana == 0)
        #expect(talentPoints(.shield, on: .hero, in: battle) == 2)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 0)
    }

    @Test func `dragon patronage rejects insufficient mana burn cards and defeated patrons`() {
        var battle = capstoneBattle(companion: ["frost_whelp_mana_t4_1"])
        battle.roster.hero.currentMana = 1
        battle.roster.companion.currentMana = 1
        var card = Ability.rayOfFrost
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(for: &card, actor: battle.hero, context: &battle)
        #expect(card == Ability.rayOfFrost)
        #expect(battle.roster.hero.currentMana == 1)
        #expect(battle.roster.companion.currentMana == 1)
        battle.roster.companion.currentMana = 10
        card = .kindling
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(for: &card, actor: battle.hero, context: &battle)
        #expect(card == Ability.kindling)
        #expect(battle.roster.companion.currentMana == 10)
        battle.roster.companion.currentHealth = 0
        card = .rayOfFrost
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(for: &card, actor: battle.hero, context: &battle)
        #expect(card == Ability.rayOfFrost)
        #expect(battle.roster.hero.currentMana == 1)
    }

    @Test func `prismatic scales does not duplicate mixed components or grant unpaid damage`() {
        var battle = capstoneBattle(companion: ["mana_moth_mana_t4_1"])
        var mixed = Ability(
            id: "mixed", name: "Mixed", tier: .skill,
            damageComponents: [DamageComponent(2, keyword: .burn), DamageComponent(3, keyword: .freeze)],
        )
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(for: &mixed, actor: battle.companion, context: &battle)
        #expect(mixed.damageComponents.map(\.amount) == [3, 4])
        #expect(battle.roster.companion.currentMana == 7)
        battle.roster.companion.currentMana = 2
        var unpaid = Ability.rayOfFrost
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(for: &unpaid, actor: battle.companion, context: &battle)
        #expect(unpaid == Ability.rayOfFrost)
        #expect(battle.roster.companion.currentMana == 2)
    }
}
