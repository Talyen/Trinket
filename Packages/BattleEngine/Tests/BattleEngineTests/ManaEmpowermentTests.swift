import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct ManaEmpowermentTests {
    @Test func `shared payment keeps the patrons last mana fact through an automatic refill`() {
        var heroProfile = CombatModifierProfile.zero
        heroProfile.triggers.spendManaThresholdAutoPlayCard = 1
        var companionProfile = CombatModifierProfile.zero
        companionProfile.triggers.dragonPatronage = true
        companionProfile.triggers.spendLastManaStunDamage = 3
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 1, heroMana: 1, companionMaxMana: 2, companionMana: 2,
            heroModifiers: heroProfile, companionModifiers: companionProfile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.heroDeck = CombatDeck(abilities: [Ability(
            id: "refill-patron", name: "Refill Patron", tier: .basic,
            targetedEffects: [TargetedEffect(.resourceGain(.mana, 2), target: .companion)],
        )])
        var ability = Ability.frostbolt
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(for: &ability, actor: battle.hero, context: &battle)
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(battle.mana(of: battle.companion) == 2)
        #expect(battle.roster.enemy.currentHealth == 97)
    }

    @Test func `barkweave removes thorns for each falling star empowerment`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["druid_mana_t1_2"])
        let meteorite = try #require(GameContent.trinketItems.first { $0.templateID == "meteorite" })
        let power = try #require(meteorite.resolvedPower(at: 0))
        power.triggers.apply(to: &profile)
        var battle = makeBattle(
            heroAbilities: [], heroMaxMana: 9, heroMana: 9,
            heroModifiers: profile,
        )
        battle.appendEffect(.thorns(5), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        var ability = BattleAbilityRules.resolveOutcome(.cinderbloom, actor: battle.hero, in: &battle)
        #expect(ability.damageComponents.first?.keyword == .burn)
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        )
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == .thorns(2) })
    }

    @Test func `empowerment stops when arcane burst kills its caster`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 12, companionMana: 12,
            companionModifiers: CombatantTalentCatalog.profile(for: ["mana_moth_mana_t3_2"]),
            dealOpeningHand: false,
        )
        battle.roster.companion.currentHealth = 1
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.companionDeck = CombatDeck(abilities: [.pixieDust])
        battle.appendEffect(.thorns(10), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        var ability = Ability.meteor
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.companion, context: &battle,
        )
        #expect(battle.health(of: battle.companion) == 0)
        #expect(battle.mana(of: battle.companion) == 3)
        #expect(ability.directDamage == Ability.meteor.directDamage + 2)
    }

    @Test func `recurring freeze empowerment draws the opposite element`() {
        var battle = makeBattle(
            heroAbilities: [], heroMaxMana: 3, heroMana: 3,
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(empoweredElementDrawOpposite: true),
            )),
        )
        battle.heroDeck = CombatDeck(abilities: [.kindling])
        var ability = Ability.rayOfFrost
        let events = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        )
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(events.contains { $0.effectKind == .cardsDrawn })
        #expect(battle.hand.cards.contains { $0.ability.id == Ability.kindling.id })
    }

    @Test func `dragon spark discounts only first empowerment and preserves its effect`() {
        var battle = makeBattle(
            heroAbilities: [], heroMaxMana: 4, heroMana: 4,
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(firstEmpowermentCostReduction: 2),
            )),
        )
        for expectedMana in [3, 0] {
            var ability = Ability.frostbolt
            _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
                for: &ability, actor: battle.hero, context: &battle,
            )
            #expect(battle.mana(of: battle.hero) == expectedMana)
            #expect(ability.directDamage == Ability.frostbolt.directDamage + 1)
        }
    }

    @Test func `dragon spark does not consume discount without enough mana`() {
        var battle = makeBattle(
            heroAbilities: [], heroMaxMana: 4, heroMana: 0,
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(firstEmpowermentCostReduction: 2),
            )),
        )
        var ability = Ability.frostbolt
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        )
        #expect(ability.directDamage == Ability.frostbolt.directDamage)
        _ = battle.endTurn()
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        )
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(ability.directDamage == Ability.frostbolt.directDamage + 1)
    }

    @Test(arguments: [0, 1])
    func `arcane breath adds flat damage even with discounted empowerment`(discount: Int) {
        var battle = makeBattle(
            heroAbilities: [], heroMaxMana: 3, heroMana: 3,
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(empowermentDamageBonus: 3, empowermentCostReduction: discount),
            )),
        )
        var ability = Ability.frostbolt
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        )
        #expect(battle.mana(of: battle.hero) == discount)
        #expect(ability.directDamage == Ability.frostbolt.directDamage + 4)
    }

    private func makeBattle(
        heroAbilities: [Ability],
        companionAbilities: [Ability] = [],
        enemyAbilities: [Ability] = [],
        heroMaxMana: Int = 0,
        heroMana: Int? = nil,
        companionMaxMana: Int = 0,
        companionMana: Int? = nil,
        heroModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: heroAbilities,
            companionAbilities: companionAbilities,
            enemyAbilities: enemyAbilities,
            heroMaxMana: heroMaxMana,
            heroMana: heroMana,
            companionMaxMana: companionMaxMana,
            companionMana: companionMana,
            heroModifiers: heroModifiers,
        )
    }

    private func recurringFreezePotency(on battle: BattleState) -> Int? {
        battle.activeEffects(of: battle.enemy).first {
            if case let .recurringDamage(keyword, _, _) = $0.effect {
                return keyword == .freeze
            }
            return false
        }?.effect.potency
    }

    private struct FireballCase {
        let heroMaxMana: Int
        let heroMana: Int
        let expectedManaAfter: Int
        let expectedDamage: Int

        static let fullPool = Self(heroMaxMana: 5, heroMana: 5, expectedManaAfter: 2, expectedDamage: 4)
        static let largePool = Self(heroMaxMana: 20, heroMana: 20, expectedManaAfter: 17, expectedDamage: 4)
        static let partialPool = Self(heroMaxMana: 5, heroMana: 2, expectedManaAfter: 2, expectedDamage: 3)
        static let emptyPool = Self(heroMaxMana: 5, heroMana: 0, expectedManaAfter: 0, expectedDamage: 3)
    }

    @Test(arguments: [Self.FireballCase.fullPool, .largePool, .partialPool, .emptyPool])
    private func `fireball empowers only when three mana is spent`(_ testCase: FireballCase) throws {
        var battle = makeBattle(
            heroAbilities: [.fireball],
            heroMaxMana: testCase.heroMaxMana,
            heroMana: testCase.heroMana,
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.fireball.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == testCase.expectedManaAfter)
        let abilityEvent = try #require(events.first { $0.kind == .ability && $0.abilityID == Ability.fireball.id })
        try #expect(abilityEvent.amount == testCase.expectedDamage)
        try #expect(BattleTestFixtures.burnPotency(on: battle) == testCase.expectedDamage)
    }

    @Test func `freeze ability spends three mana for bonus damage`() throws {
        var battle = makeBattle(
            heroAbilities: [.frostbolt],
            heroMaxMana: 4,
            heroMana: 4,
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.frostbolt.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 1)
        let abilityEvent = try #require(events.first { $0.kind == .ability && $0.abilityID == Ability.frostbolt.id })
        try #expect(abilityEvent.amount == 4)
    }

    @Test func `blizzard stores empowered recurring freeze potency`() throws {
        var battle = makeBattle(
            heroAbilities: [.blizzard],
            heroMaxMana: 3,
            heroMana: 3,
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.blizzard.id })
        _ = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 0)
        try #expect(recurringFreezePotency(on: battle) == 5)
    }

    @Test func `burn branch spends mana poison branch does not`() throws {
        let burnOnly = Ability(
            id: "burn-only",
            name: "Burn Only",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .burn)],
            targetedEffects: [TargetedEffect(.burn(2))],
        )
        let poisonOnly = Ability(
            id: "poison-only",
            name: "Poison Only",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .poison)],
            targetedEffects: [TargetedEffect(.poison(2))],
        )

        var burnBattle = makeBattle(heroAbilities: [burnOnly], heroMaxMana: 3, heroMana: 3)
        let burnCard = try #require(burnBattle.hand.cards.first { $0.ability.id == burnOnly.id })
        _ = try burnBattle.playCard(cardID: burnCard.id)
        try #expect(burnBattle.mana(of: burnBattle.hero) == 0)

        var poisonBattle = makeBattle(heroAbilities: [poisonOnly], heroMaxMana: 3, heroMana: 3)
        let poisonCard = try #require(poisonBattle.hand.cards.first { $0.ability.id == poisonOnly.id })
        _ = try poisonBattle.playCard(cardID: poisonCard.id)
        try #expect(poisonBattle.mana(of: poisonBattle.hero) == 3)
    }

    @Test func `multi burn numbers spend only three mana`() throws {
        var battle = makeBattle(
            heroAbilities: [.fireArrow],
            heroMaxMana: 4,
            heroMana: 4,
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.fireArrow.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 1)
        let abilityEvent = try #require(events.first { $0.kind == .ability && $0.abilityID == Ability.fireArrow.id })
        try #expect(abilityEvent.amount == 2)
        try #expect(BattleTestFixtures.burnPotency(on: battle) == 2)
    }

    @Test func `mana regenerates at start of player turn for mana users`() throws {
        var battle = makeBattle(
            heroAbilities: [.slash],
            companionAbilities: [.bash],
            enemyAbilities: [],
            heroMaxMana: 5,
            heroMana: 2,
            companionMaxMana: 4,
            companionMana: 1,
        )
        let events = battle.endTurn()

        try #expect(battle.mana(of: battle.hero) == 3)
        try #expect(battle.mana(of: battle.companion) == 2)
        try #expect(events.count(where: { $0.effectKind == .resourceGain && $0.keyword == .mana }) == 2)
    }

    @Test func `mana does not regenerate without mana pool`() throws {
        var battle = makeBattle(
            heroAbilities: [.slash],
            companionAbilities: [.bash],
            heroMaxMana: 0,
            companionMaxMana: 0,
        )
        let events = battle.endTurn()

        try #expect(battle.mana(of: battle.hero) == 0)
        try #expect(battle.mana(of: battle.companion) == 0)
        try #expect(!events.contains { $0.effectKind == .resourceGain && $0.keyword == .mana })
    }

    @Test func `aetherward triggers on mana empower spend`() throws {
        var battle = makeBattle(
            heroAbilities: [.frostbolt],
            heroMaxMana: 3,
            heroMana: 3,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaBlockFlat: 2,
                ),
            )),
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.frostbolt.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(events.contains { $0.abilityName == "Aetherward" && $0.amount == 2 })
        try #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 2)
    }

    @Test func `mana shield spends remaining mana after empower`() throws {
        var battle = makeBattle(
            heroAbilities: [.kindling, .manaShield],
            companionAbilities: [.bash],
            heroMaxMana: 5,
            heroMana: 5,
        )
        let kindling = try #require(battle.hand.cards.first { $0.ability.id == Ability.kindling.id })
        _ = try battle.playCard(cardID: kindling.id)
        try #expect(battle.mana(of: battle.hero) == 2)

        let shieldCard = try #require(
            battle.hand.cards.first { $0.ability.id == Ability.manaShield.id && $0.owner == .hero },
        )
        let manaBeforeShield = battle.mana(of: battle.hero)
        let events = try battle.playCard(cardID: shieldCard.id)

        try #expect(battle.mana(of: battle.hero) == 0)
        try #expect(events.contains {
            $0.effectKind == .shieldApplied && $0.abilityName == Ability.manaShield.name && $0.amount == manaBeforeShield
        })
        try #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == manaBeforeShield)
    }
}
