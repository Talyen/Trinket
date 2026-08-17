import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct ManaEmpowermentTests {
    private func makeBattle(
        heroAbilities: [Ability],
        companionAbilities: [Ability] = [],
        enemyAbilities: [Ability] = [],
        heroMaxMana: Int = 0,
        heroMana: Int? = nil,
        companionMaxMana: Int = 0,
        companionMana: Int? = nil,
        heroModifiers: CombatModifierProfile = .zero
    ) -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: heroAbilities,
            companionAbilities: companionAbilities,
            enemyAbilities: enemyAbilities,
            heroMaxMana: heroMaxMana,
            heroMana: heroMana,
            companionMaxMana: companionMaxMana,
            companionMana: companionMana,
            heroModifiers: heroModifiers
        )
    }

    private func burnStackPotency(on battle: BattleState) -> Int? {
        battle.activeEffects(of: battle.enemy).first {
            $0.effect.isDecayingDoT && $0.keyword == .burn
        }?.effect.potency
    }

    private func recurringFreezePotency(on battle: BattleState) -> Int? {
        battle.activeEffects(of: battle.enemy).first {
            if case let .recurringDamage(keyword, _, _) = $0.effect {
                return keyword == .freeze
            }
            return false
        }?.effect.potency
    }

    private func blockPoints(on battle: BattleState, for combatant: Combatant) -> Int {
        battle.activeEffects(of: combatant).reduce(0) { sum, active in
            if case let .shield(.block, points) = active.effect {
                return sum + points
            }
            return sum
        }
    }

    @Test func burnAbilitySpendsThreeManaAndRaisesDamageNumbers() throws {
        var battle = makeBattle(
            heroAbilities: [.fireball],
            heroMaxMana: 5,
            heroMana: 5
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.fireball.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 2)
        let abilityEvent = try #require(events.first { $0.kind == .ability && $0.abilityID == Ability.fireball.id })
        try #expect(abilityEvent.amount == 3)
        try #expect(burnStackPotency(on: battle) == 3)
    }

    @Test func burnEmpowermentDoesNotScaleWithMaxMana() throws {
        var battle = makeBattle(
            heroAbilities: [.fireball],
            heroMaxMana: 20,
            heroMana: 20
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.fireball.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 17)
        let abilityEvent = try #require(events.first { $0.kind == .ability && $0.abilityID == Ability.fireball.id })
        try #expect(abilityEvent.amount == 3)
        try #expect(burnStackPotency(on: battle) == 3)
    }

    @Test func burnAbilityWithoutEnoughManaPlaysWithoutBonus() throws {
        var battle = makeBattle(
            heroAbilities: [.fireball],
            heroMaxMana: 5,
            heroMana: 2
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.fireball.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 2)
        let abilityEvent = try #require(events.first { $0.kind == .ability && $0.abilityID == Ability.fireball.id })
        try #expect(abilityEvent.amount == 2)
        try #expect(burnStackPotency(on: battle) == 2)
    }

    @Test func burnAbilityAtZeroManaPlaysWithoutBonus() throws {
        var battle = makeBattle(
            heroAbilities: [.fireball],
            heroMaxMana: 5,
            heroMana: 0
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.fireball.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 0)
        let abilityEvent = try #require(events.first { $0.kind == .ability && $0.abilityID == Ability.fireball.id })
        try #expect(abilityEvent.amount == 2)
        try #expect(burnStackPotency(on: battle) == 2)
    }

    @Test func freezeAbilitySpendsThreeManaForBonusDamage() throws {
        var battle = makeBattle(
            heroAbilities: [.frostbolt],
            heroMaxMana: 4,
            heroMana: 4
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.frostbolt.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 1)
        let abilityEvent = try #require(events.first { $0.kind == .ability && $0.abilityID == Ability.frostbolt.id })
        try #expect(abilityEvent.amount == 4)
    }

    @Test func blizzardStoresEmpoweredRecurringFreezePotency() throws {
        var battle = makeBattle(
            heroAbilities: [.blizzard],
            heroMaxMana: 3,
            heroMana: 3
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.blizzard.id })
        _ = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 0)
        try #expect(recurringFreezePotency(on: battle) == 4)
    }

    @Test func burnBranchSpendsManaPoisonBranchDoesNot() throws {
        let burnOnly = Ability(
            id: "burn-only",
            name: "Burn Only",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .burn)],
            targetedEffects: [TargetedEffect(.burn(2))]
        )
        let poisonOnly = Ability(
            id: "poison-only",
            name: "Poison Only",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .poison)],
            targetedEffects: [TargetedEffect(.poison(2))]
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

    @Test func multiBurnNumbersSpendOnlyThreeMana() throws {
        var battle = makeBattle(
            heroAbilities: [.fireArrow],
            heroMaxMana: 4,
            heroMana: 4
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.fireArrow.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 1)
        let abilityEvent = try #require(events.first { $0.kind == .ability && $0.abilityID == Ability.fireArrow.id })
        try #expect(abilityEvent.amount == 2)
        // Empowered burn(2) plus conditional burn(2) after the enemy is burning.
        try #expect(burnStackPotency(on: battle) == 4)
    }

    @Test func manaRegeneratesAtStartOfPlayerTurnForManaUsers() throws {
        var battle = makeBattle(
            heroAbilities: [.slash],
            companionAbilities: [.bash],
            enemyAbilities: [],
            heroMaxMana: 5,
            heroMana: 2,
            companionMaxMana: 4,
            companionMana: 1
        )
        let events = battle.endTurn()

        try #expect(battle.mana(of: battle.hero) == 3)
        try #expect(battle.mana(of: battle.companion) == 2)
        try #expect(events.count(where: { $0.effectKind == .resourceGain && $0.keyword == .mana }) == 2)
    }

    @Test func manaDoesNotRegenerateWithoutManaPool() throws {
        var battle = makeBattle(
            heroAbilities: [.slash],
            companionAbilities: [.bash],
            heroMaxMana: 0,
            companionMaxMana: 0
        )
        let events = battle.endTurn()

        try #expect(battle.mana(of: battle.hero) == 0)
        try #expect(battle.mana(of: battle.companion) == 0)
        try #expect(!events.contains { $0.effectKind == .resourceGain && $0.keyword == .mana })
    }

    @Test func aetherwardTriggersOnManaEmpowerSpend() throws {
        var battle = makeBattle(
            heroAbilities: [.frostbolt],
            heroMaxMana: 3,
            heroMana: 3,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    spendManaBlockFlat: 2
                )
            ))
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.frostbolt.id })
        let events = try battle.playCard(cardID: card.id)

        try #expect(events.contains { $0.abilityName == "Aetherward" && $0.amount == 2 })
        try #expect(blockPoints(on: battle, for: battle.hero) == 2)
    }

    @Test func manaShieldSpendsRemainingManaAfterEmpower() throws {
        var battle = makeBattle(
            heroAbilities: [.kindling, .manaShield],
            companionAbilities: [.bash],
            heroMaxMana: 5,
            heroMana: 5
        )
        let kindling = try #require(battle.hand.cards.first { $0.ability.id == Ability.kindling.id })
        _ = try battle.playCard(cardID: kindling.id)
        try #expect(battle.mana(of: battle.hero) == 2)

        let shieldCard = try #require(
            battle.hand.cards.first { $0.ability.id == Ability.manaShield.id && $0.owner == .hero }
        )
        let manaBeforeShield = battle.mana(of: battle.hero)
        let events = try battle.playCard(cardID: shieldCard.id)

        try #expect(battle.mana(of: battle.hero) == 0)
        try #expect(events.contains {
            $0.effectKind == .shieldApplied && $0.abilityName == Ability.manaShield.name && $0.amount == manaBeforeShield
        })
        try #expect(blockPoints(on: battle, for: battle.hero) == manaBeforeShield)
    }
}
