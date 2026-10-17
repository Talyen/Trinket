import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct ManaEmpowermentTests {
    @Test(arguments: [6, 9])
    func `Wishspring grants one free Meteor empowerment before its paid repeats`(mana: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: mana, companionMana: mana,
            companionModifiers: CombatantTalentCatalog.profile(for: ["pixie_health_t4_1"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        let companion = battle.companion
        _ = CombatExecutor.run { await HealingEngine.resolveHealing(HealRequest(
            amount: 1, target: companion, sourceActorID: companion.id,
            origin: .restoration(.health), logAs: .silent,
        ), in: &battle) }
        #expect(battle.roster.companion.talents.pending.nextManaEmpowerDiscount == 3)
        battle.nextCardID += 1
        let card = BattleCard(id: battle.nextCardID, ability: .meteor, owner: .companion)
        battle.hand.append(card)
        let assessment = battle.assessCard(card)
        #expect(assessment.denial == nil)
        #expect(assessment.resources.contains { $0.keyword == .mana && $0.combatantID == companion.id })

        var budget = ManaEmpowermentBudget(ability: .meteor, actor: companion, in: battle)
        var payments: [Int] = []
        for _ in 0 ..< budget.purchaseLimit {
            guard let payment = budget.nextPayment() else { break }
            payments.append(payment.ownMana)
        }
        #expect(payments == [0] + Array(repeating: 3, count: mana / 3))
        #expect(battle.roster.companion.talents.pending.nextManaEmpowerDiscount == 3)

        var ability = Ability.meteor
        CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: companion, context: &battle,
        ) }
        #expect(battle.mana(of: companion) == 0)
        #expect(ability.directDamage == Ability.meteor.directDamage + 1 + mana / 3)
        #expect(battle.roster.companion.talents.pending.nextManaEmpowerDiscount == 0)
    }

    @Test func `persistent free empowerment remains limited to one Meteor purchase`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [], heroMaxMana: 9, heroMana: 9,
            heroModifiers: .withTriggers { $0.empowermentCostReduction = 3 },
        )
        #expect(ManaEmpowermentBudget(ability: .meteor, actor: battle.hero, in: battle).purchaseLimit == 1)
        var ability = Ability.meteor
        CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        ) }
        #expect(battle.mana(of: battle.hero) == 9)
        #expect(ability.directDamage == Ability.meteor.directDamage + 1)
    }

    @Test func `shared payment keeps the patrons last mana fact through an automatic refill`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 1, heroMana: 1, companionMaxMana: 2, companionMana: 2,
            heroModifiers: .withTriggers { $0.spendManaThresholdAutoPlayCard = 1 }, companionModifiers: .withTriggers {
                $0.dragonPatronage = true
                $0.spendLastManaStunDamage = 3
            }, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.heroDeck = CombatDeck(abilities: [Ability(
            id: "refill-patron", name: "Refill Patron", tier: .basic,
            targetedEffects: [TargetedEffect(.resourceGain(.mana, 2), target: .companion)],
        )])
        var ability = Ability.frostbolt
        CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability,
            actor: battle.hero,
            context: &battle,
        ) }
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(battle.mana(of: battle.companion) == 2)
        #expect(battle.roster.enemy.currentHealth == 97)
    }

    @Test func `barkweave grants block for each falling star empowerment`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["druid_mana_t1_2"])
        let meteorite = try #require(GameContent.trinketItems.first { $0.templateID == "meteorite" })
        let power = try #require(meteorite.resolvedPower(at: 0))
        power.triggers.apply(to: &profile)
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [], heroMaxMana: 9, heroMana: 9,
            heroModifiers: profile,
        )
        battle.insertEffect(.thorns(5), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        var ability = BattleAbilityRules.resolveOutcome(.cinderbloom, actor: battle.hero, in: &battle)
        #expect(ability.damageComponents.first?.keyword == .burn)
        CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        ) }
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == .thorns(5) })
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 6)
    }

    @Test func `recurring freeze empowerment draws the opposite element`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [], heroMaxMana: 3, heroMana: 3,
            heroModifiers: .withTriggers { $0.empoweredElementDrawOpposite = true },
        )
        battle.heroDeck = CombatDeck(abilities: [.kindling])
        var ability = Ability.rayOfFrost
        let events = battle.recordingEvents { battle in await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        ) }
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(events.contains { $0.effectKind == .cardsDrawn })
        #expect(battle.hand.cards.contains { $0.ability.id == Ability.kindling.id })
    }

    @Test func `dragon spark waits for affordable empowerment then discounts only once`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [], heroMaxMana: 4, heroMana: 0,
            heroModifiers: .withTriggers { $0.firstEmpowermentCostReduction = 2 },
        )
        var unpayable = Ability.frostbolt
        CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &unpayable, actor: battle.hero, context: &battle,
        ) }
        #expect(unpayable.directDamage == Ability.frostbolt.directDamage)

        battle.roster.hero.currentMana = 4
        for expectedMana in [3, 0] {
            var ability = Ability.frostbolt
            CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
                for: &ability, actor: battle.hero, context: &battle,
            ) }
            #expect(battle.mana(of: battle.hero) == expectedMana)
            #expect(ability.directDamage == Ability.frostbolt.directDamage + 1)
        }
    }

    @Test(arguments: [0, 1])
    func `arcane breath adds flat damage even with discounted empowerment`(discount: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [], heroMaxMana: 3, heroMana: 3,
            heroModifiers: .withTriggers {
                $0.empowermentDamageBonus = 3
                $0.empowermentCostReduction = discount
            },
        )
        var ability = Ability.frostbolt
        CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        ) }
        #expect(battle.mana(of: battle.hero) == discount)
        #expect(ability.directDamage == Ability.frostbolt.directDamage + 4)
    }

    @Test(arguments: [
        (Ability.fireball, 5, 5, 2, 5),
        (.fireball, 20, 20, 17, 5),
        (.fireball, 5, 2, 2, 4),
        (.fireball, 5, 0, 0, 4),
        (.frostbolt, 4, 4, 1, 5),
        (.fireArrow, 4, 4, 1, 4),
    ])
    func `burn and freeze spells empower only when three mana is spent`(
        ability: Ability, maxMana: Int, mana: Int, expectedMana: Int, expectedDamage: Int,
    ) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [ability], heroMaxMana: maxMana, heroMana: mana,
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == ability.id })
        let events = try battle.playCard(cardID: card.id).events
        #expect(battle.mana(of: battle.hero) == expectedMana)
        let abilityEvent = try #require(events.first { $0.kind == .ability && $0.abilityID == ability.id })
        #expect(abilityEvent.amount == expectedDamage)
        if ability.id != Ability.frostbolt.id {
            #expect(BattleTestFixtures.burnPotency(on: battle) == expectedDamage)
        }
    }

    @Test func `blizzard stores empowered recurring freeze potency`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.blizzard],
            heroMaxMana: 3,
            heroMana: 3,
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.blizzard.id })
        _ = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 0)
        let recurring = battle.activeEffects(of: battle.enemy).first {
            $0.effect.kind == .recurringDamage && $0.keyword == .freeze
        }
        #expect(recurring?.effect.potency == 7)
    }

    @Test(arguments: [(Keyword.burn, Effect.burn(2), 0), (.poison, .poison(2), 3)])
    func `burn branch spends mana poison branch does not`(keyword: Keyword, effect: Effect, expectedMana: Int) throws {
        let ability = Ability(
            id: "\(keyword.rawValue)-only", name: keyword.rawValue, tier: .basic,
            damageComponents: [DamageComponent(2, keyword: keyword)],
            targetedEffects: [TargetedEffect(effect)],
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroAbilities: [ability], heroMaxMana: 3, heroMana: 3)
        let card = try #require(battle.hand.cards.first { $0.ability.id == ability.id })
        _ = try battle.playCard(cardID: card.id)
        #expect(battle.mana(of: battle.hero) == expectedMana)
    }

    @Test(arguments: [true, false])
    func `mana regenerates at start of player turn only for mana users`(hasManaPool: Bool) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash], companionAbilities: [.bash], enemyAbilities: [],
            heroMaxMana: hasManaPool ? 5 : 0, heroMana: hasManaPool ? 2 : 0,
            companionMaxMana: hasManaPool ? 4 : 0, companionMana: hasManaPool ? 1 : 0,
        )
        let events = battle.endTurn().events
        #expect(battle.mana(of: battle.hero) == (hasManaPool ? 3 : 0))
        #expect(battle.mana(of: battle.companion) == (hasManaPool ? 2 : 0))
        #expect(events.count(where: { $0.effectKind == .resourceGain && $0.keyword == .mana }) == (hasManaPool ? 2 : 0))
    }

    @Test func `aetherward triggers on mana empower spend`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.frostbolt],
            heroMaxMana: 3,
            heroMana: 3,
            heroModifiers: CombatModifierProfile.withTriggers { $0.spendManaBlockFlat = 2 },
        )
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.frostbolt.id })
        let events = try battle.playCard(cardID: card.id).events

        try #expect(events.contains { $0.abilityName == "Aetherward" && $0.amount == 2 })
        try #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 2)
    }

    @Test func `mana shield spends remaining mana after empower`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.kindling, .manaShield],
            companionAbilities: [.bash],
            heroMaxMana: 5,
            heroMana: 5,
        )
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .manaShield, owner: .hero))
        let kindling = try #require(battle.hand.cards.first { $0.ability.id == Ability.kindling.id })
        _ = try battle.playCard(cardID: kindling.id)
        try #expect(battle.mana(of: battle.hero) == 2)

        let shieldCard = try #require(
            battle.hand.cards.first { $0.ability.id == Ability.manaShield.id && $0.owner == .hero },
        )
        let manaBeforeShield = battle.mana(of: battle.hero)
        let events = try battle.playCard(cardID: shieldCard.id).events

        try #expect(battle.mana(of: battle.hero) == 0)
        try #expect(events.contains {
            $0.effectKind == .shieldApplied && $0.abilityName == Ability.manaShield.name && $0.amount == manaBeforeShield
        })
        try #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == manaBeforeShield + 1)
    }
}

extension ManaEmpowermentTests {
    @Test func `Spell Echo doubles Dark Pact damage without increasing its Health cost`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wizard_mana_t3_2"])
        profile.triggers.manaEmpoweredAttackDoubleChancePercent = 1
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.darkPact], heroMaxHealth: 2,
            heroMaxMana: 6, heroMana: 6, heroModifiers: profile, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        let card = try #require(battle.hand.cards.first { $0.ability.id == Ability.darkPact.id })

        _ = try battle.playCard(cardID: card.id)

        #expect(battle.health(of: battle.hero) == 1)
        #expect(battle.health(of: battle.enemy) == 96)
        #expect(BattleTestFixtures.burnPotency(on: battle) == 4)
        #expect(battle.mana(of: battle.hero) == 3)
    }

    @Test(arguments: [Keyword.burn, .freeze])
    func `Arcane Breath strengthens Astral Arrow Freeze without adding Freeze to Burn`(keyword: Keyword) throws {
        var profile = CombatantTalentCatalog.profile(for: ["frost_whelp_mana_t1_2"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 3, companionMana: 3,
            companionModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        let branches = try #require(Ability.astralArrow.outcomeBranches)
        let branch = try #require(branches.first { $0.damageComponents.first?.keyword == keyword })
        let ability = Ability.astralArrow.resolving(branch: branch, using: &battle.rng)
        let events = battle.performTestAction(ability, from: .companion)
        let hits = events.filter { $0.kind == .abilityDamage }
        let expectedDamage = keyword == .freeze ? 9 : 8
        #expect(hits.count == 1)
        #expect(hits.first?.keyword == keyword)
        #expect(hits.first?.amount == expectedDamage)
        #expect(battle.health(of: battle.enemy) == 100 - expectedDamage)
        #expect(battle.mana(of: battle.companion) == 0)
        if keyword == .burn {
            #expect(!battle.activeEffects(of: battle.enemy).contains { $0.keyword == .freeze })
        }
    }

    @Test func `large saved Mana capacities remain usable for shared and discounted empowerment`() throws {
        let battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: Int.max, heroMana: 1,
            companionMaxMana: Int.max, companionMana: 2,
            companionModifiers: .withTriggers { $0.dragonPatronage = true }, dealOpeningHand: false,
        )
        var shared = ManaEmpowermentBudget(ability: .frostbolt, actor: battle.hero, in: battle)
        let sharedPayment = shared.nextPayment()
        let payment = try #require(sharedPayment)
        #expect(payment.ownMana == 1 && payment.partnerMana == 2)
        #expect(shared.nextPayment() == nil)

        var discountedBattle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: Int.max, heroMana: 1,
            heroModifiers: .withTriggers { $0.empowermentCostReduction = 2 }, dealOpeningHand: false,
        )
        discountedBattle.roster.hero.talents.pending.nextManaEmpowerDiscount = 1
        var repeated = ManaEmpowermentBudget(ability: .meteor, actor: discountedBattle.hero, in: discountedBattle)
        #expect(repeated.purchaseLimit == Int.max)
        let freePayment = repeated.nextPayment()
        #expect(try #require(freePayment).ownMana == 0)
        let paidPayment = repeated.nextPayment()
        #expect(try #require(paidPayment).ownMana == 1)
        #expect(repeated.nextPayment() == nil)
    }
}
