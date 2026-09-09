import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test(arguments: [0, 1])
    func `dragon patronage pays only the shortfall and credits the actual spenders`(heroMana: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: heroMana, heroMana: heroMana,
            companionMaxMana: 8, companionMana: 3,
            companionModifiers: CombatantTalentCatalog.profile(for: ["frost_whelp_mana_t4_1", "frost_whelp_mana_t2_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        var card = Ability.rayOfFrost
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(for: &card, actor: battle.hero, context: &battle)
        #expect(card.effects == [.recurringDamage(.freeze, 2, 2)])
        #expect(battle.roster.hero.currentMana == 0)
        #expect(battle.roster.companion.currentMana == heroMana)
        #expect(talentPoints(.shield, on: .companion, in: battle) == (heroMana > 0 ? 2 : 0))
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

    @Test(arguments: [Keyword.burn, .freeze])
    func `prismatic scales empowers both damage types for one mana payment`(keyword: Keyword) throws {
        var battle = capstoneBattle(companion: ["mana_moth_mana_t4_1"])
        let original = Ability(
            id: "prismatic", name: "Prismatic", tier: .skill,
            damageComponents: [DamageComponent(2, keyword: keyword)],
        )
        var empowered = original
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(for: &empowered, actor: battle.companion, context: &battle)
        #expect(battle.roster.companion.currentMana == 7)
        #expect(empowered.damageComponents.count == 2)
        #expect(empowered.damageComponents.first { $0.keyword == keyword }?.amount == 3)
        let opposite: Keyword = keyword == .burn ? .freeze : .burn
        #expect(empowered.damageComponents.first { $0.keyword == opposite }?.amount == 1)
        battle.roster.companion.currentMana = 10
        try playHeroTalentCard(original, owner: .companion, in: &battle)
        #expect(battle.roster.companion.currentMana == 7)
        #expect(talentPoints(.burn, on: .enemy, in: battle) > 0)
        #expect(battle.roster.enemy.activeEffects.contains { $0.keyword == .freeze })
        #expect(battle.roster.enemy.currentHealth < 200)
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

    @Test(arguments: [Effect.purge(nil), .purgeRandom])
    func `sealed sarcophagus protects only block from purge and theft`(effect: Effect) throws {
        var battle = capstoneBattle(companion: ["shield_scarab_block_t4_1"])
        seedHeroTalentEffect(.shield(.block, 5), on: .companion, in: &battle)
        seedHeroTalentEffect(.thorns(2), on: .companion, in: &battle)
        let handler = try #require(EffectHandlers.all[effect.kind])
        _ = handler.apply(effect, ability: .cleanse, source: battle.enemy, target: battle.companion, in: &battle)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 5)
        #expect(talentPoints(.thorns, on: .companion, in: battle) == 0)
        _ = DefensePoolEngine.steal(5, from: battle.companion, to: battle.enemy, abilityName: "Theft", in: &battle)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 5)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 0)
        _ = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id, options: .reaction(),
        ))
        #expect(talentPoints(.shield, on: .companion, in: battle) == 3)
        DefensePoolEngine.decayBlock(on: battle.companion, in: &battle)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 1)
    }

    @Test func `light fingered steals only available block for actual gold gains`() {
        var battle = capstoneBattle(companion: ["fox_gold_t4_1"])
        seedHeroTalentEffect(.shield(.block, 5), on: .enemy, in: &battle)
        _ = battle.grantGoldEvent(2, to: battle.companion, abilityName: "Steal")
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 3)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 2)
        _ = battle.grantGoldEvent(4, to: battle.companion, abilityName: "Lucky Strike")
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 0)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 5)
        #expect(battle.gold == 6)
    }

    @Test(arguments: ["wizard_mana_t4_1", "warlock_mana_t1_1"])
    func `mana stun talents build control with their damage`(talent: String) {
        var battle = capstoneBattle(hero: [talent])
        battle.roster.hero.currentMana = 0
        _ = CombatTriggerEngine.afterSpendMana(by: battle.hero, amountSpent: 3, in: &battle)
        #expect(battle.roster.enemy.currentHealth == 197)
        #expect(battle.roster.enemy.activeEffects.contains {
            if case let .controlMeter(.stun, amount, _) = $0.effect {
                return amount == 3
            }
            return false
        })
    }

    @Test func `chaos rift freeze damage builds control`() {
        var battle = capstoneBattle(hero: ["warlock_mana_t3_1"])
        var freezeDamage = 0
        for _ in 0 ..< 8 {
            var expectedRNG = battle.rng
            if [Keyword.freeze, .burn, .poison, .holy].shuffled(using: &expectedRNG).prefix(2).contains(.freeze) {
                freezeDamage += 1
            }
            _ = CombatTriggerEngine.afterSpendMana(by: battle.hero, amountSpent: 2, in: &battle)
        }
        #expect(freezeDamage > 0)
        #expect(battle.roster.enemy.currentHealth == 184)
        #expect(battle.roster.enemy.activeEffects.contains {
            if case let .controlMeter(.freeze, amount, _) = $0.effect {
                return amount == freezeDamage
            }
            return false
        })
    }

    @Test(arguments: [1, 2, 3, 5])
    func `mana conversion talents use every payment including odd amounts`(amount: Int) {
        var battle = capstoneBattle(hero: ["warlock_mana_t3_1"], companion: ["mana_moth_mana_t2_1"])
        battle.roster.companion.currentHealth = 20
        for payment in 1 ... 2 {
            _ = CombatTriggerEngine.afterSpendMana(by: battle.hero, amountSpent: amount, in: &battle)
            _ = CombatTriggerEngine.afterSpendMana(by: battle.companion, amountSpent: amount, in: &battle)
            #expect(battle.roster.enemy.currentHealth == 200 - amount * payment)
            #expect(talentPoints(.shield, on: .companion, in: battle) == amount * payment)
            #expect(battle.roster.companion.currentHealth == 20)
        }
    }

    @Test(arguments: [Keyword.burn, .poison])
    func `arcane cleansing spends its removal on an existing affliction`(keyword: Keyword) {
        var battle = capstoneBattle(hero: ["wizard_mana_t2_2"])
        seedHeroTalentEffect(.decayingDoT(keyword: keyword, potency: 6), on: .hero, in: &battle, source: .enemy)
        seedHeroTalentEffect(.bleed(2), on: .hero, in: &battle, source: .enemy)
        for (amount, remaining) in [(1, 5), (3, 2), (5, 0)] {
            _ = CombatTriggerEngine.afterSpendMana(by: battle.hero, amountSpent: amount, in: &battle)
            let potency = battle.activeEffects(of: battle.hero).filter { $0.keyword == keyword }
                .reduce(0) { $0 + ($1.effect.potency ?? 0) }
            #expect(potency == remaining)
        }
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.keyword == keyword })
        #expect(talentPoints(.bleed, on: .hero, in: battle) == 2)
        #expect(battle.roster.hero.currentHealth == 40)
    }
}
