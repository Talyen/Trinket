import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `grove accord rewards the pair once per turn`() throws {
        var battle = heroTalentBattle("druid_mana_t4_1")
        for _ in 0 ..< 2 {
            for owner in [BattleParticipant.hero, .companion, .hero, .companion] {
                try playHeroTalentCard(.kindling, owner: owner, in: &battle)
            }
            let expected = battle.turnCount + 1
            #expect(talentPoints(.thorns, on: .hero, in: battle) == expected)
            #expect(talentPoints(.thorns, on: .companion, in: battle) == expected)
            battle.turnCount += 1
            _ = CombatTriggerEngine.startHeroTalentTurn(in: &battle)
            battle.roster.hero.currentMana = 10
            battle.roster.companion.currentMana = 10
        }
    }

    @Test func `earthquake enables entangling growth for the rest of the turn`() throws {
        var battle = heroTalentBattle("druid_poison_t3_2")
        try playHeroTalentCard(.earthquake, owner: .companion, in: &battle)
        let poison = Ability(
            id: "growth-poison",
            name: "Poison",
            tier: .basic,
            damageComponents: [DamageComponent(1, keyword: .poison)],
            criticalChanceBonus: -1,
        )
        let events = try playHeroTalentCard(poison, in: &battle)
        #expect(events.first { $0.kind == .abilityDamage }?.amount == 2)
        battle.turnCount += 1
        _ = CombatTriggerEngine.startHeroTalentTurn(in: &battle)
        let next = try playHeroTalentCard(poison, in: &battle)
        #expect(next.first { $0.kind == .abilityDamage }?.amount == 1)
    }

    func heroTalentBattle(
        _ talents: String...,
        companionMana: Int = 10,
        seed: UInt64 = CombatantFixtures.deterministicBattleSeed,
    ) -> BattleState {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 10, companionMaxMana: companionMana,
            heroModifiers: CombatantTalentCatalog.profile(for: Set(talents)), rngSeed: seed, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        return battle
    }

    var heroTalentPhysicalCard: Ability {
        Ability(id: "test-physical", name: "Physical", tier: .basic, damageComponents: [DamageComponent(1, keyword: .physical)])
    }

    var heroTalentHealingCard: Ability {
        Ability(
            id: "test-healing",
            name: "Healing",
            tier: .basic,
            targetedEffects: [TargetedEffect(.instantHeal(.health, 1), target: .actor)],
        )
    }

    var heroTalentGoldCard: Ability {
        Ability(
            id: "test-gold",
            name: "Gold",
            tier: .skill,
            targetedEffects: [TargetedEffect(.resourceGain(.gold, 1), target: .actor)],
        )
    }

    @discardableResult
    func playHeroTalentCard(_ ability: Ability, owner: BattleParticipant = .hero, in battle: inout BattleState) throws -> [ActionEvent] {
        let card = BattleCard(id: battle.nextCardID, ability: ability, owner: owner)
        battle.nextCardID += 1
        battle.hand.append(card)
        return try BattleCardCombatEngine.playDrawnCard(card, context: &battle)
    }

    func seedHeroTalentEffect(
        _ effect: Effect,
        on owner: BattleParticipant,
        in battle: inout BattleState,
        source: BattleParticipant = .hero,
    ) {
        battle.appendEffect(
            effect,
            to: battle.roster[owner].combatant,
            sourceID: battle.roster[source].id,
            remainingTurns: effect.durationTurns,
        )
    }

    func talentPoints(_ kind: EffectKind, on owner: BattleParticipant, in battle: BattleState) -> Int {
        battle.roster.activeEffects(for: battle.roster[owner].combatant).reduce(0) { sum, active in
            guard active.effect.kind == kind else { return sum }
            if case let .shield(_, amount) = active.effect {
                return sum + amount
            }
            return sum + (active.effect.potency ?? 0)
        }
    }

    @Test(arguments: [
        ("alchemist_poison_t1_2", BattleParticipant.hero, EffectKind.burn),
        ("druid_poison_t2_1", .companion, .burn),
    ])
    func `poison cards remove one point on every card`(talent: String, owner: BattleParticipant, kind: EffectKind) throws {
        var battle = heroTalentBattle(talent)
        let effect: Effect = kind == .burn ? .burn(2) : .thorns(2)
        seedHeroTalentEffect(effect, on: owner, in: &battle)
        try playHeroTalentCard(.poisonDagger, in: &battle)
        #expect(talentPoints(kind, on: owner, in: battle) == 1)
        try playHeroTalentCard(.poisonDagger, in: &battle)
        #expect(talentPoints(kind, on: owner, in: battle) == 0)
        battle.turnCount += 1
        try playHeroTalentCard(.poisonDagger, in: &battle)
        #expect(talentPoints(kind, on: owner, in: battle) == 0)
    }

    @Test func `empowered skills play twice`() throws {
        var battle = heroTalentBattle("wizard_mana_t3_2")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 10 }
        let events = try playHeroTalentCard(.fireball, in: &battle)
        #expect(events.count { $0.kind == .abilityDamage } == 2)
    }

    @Test func `protective bloom deals holy damage on heal`() throws {
        var battle = heroTalentBattle("pixie_health_t2_2")
        let enemyHealth = battle.maxHealth(of: battle.enemy)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = $0.maxHealth - 3 }
        _ = try playHeroTalentCard(heroTalentHealingCard, in: &battle)
        #expect(battle.health(of: battle.enemy) == enemyHealth - 2)
    }

    @Test func `auto played cards preserve hero sequence and do not consume outer preparation`() throws {
        var battle = heroTalentBattle("alchemist_poison_t2_1", "alchemist_health_t1_2")
        let opener = Ability(
            id: "test-burn-draw",
            name: "Burn and Draw",
            tier: .basic,
            damageComponents: [DamageComponent(1, keyword: .burn)],
            targetedEffects: [TargetedEffect(.drawAndPlayCards(1), target: .actor)],
        )
        battle.heroDeck = CombatDeck(abilities: [.poisonDagger])
        let events = try playHeroTalentCard(opener, in: &battle)
        let poison = try #require(events.first { $0.kind == .abilityDamage && $0.keyword == .poison })
        #expect(poison.amount == (poison.isCritical ? 4 : 2) + 1)
        #expect(battle.heroTalents.history[battle.hero.id]?.lastDamageKeywords == [.poison])
        #expect(battle.heroTalents.cards.isEmpty)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 1; $0.currentMana = 0 }
        let restoring = Ability(id: "test-mana-draw", name: "Mana and Draw", tier: .basic, targetedEffects: [
            TargetedEffect(.resourceGain(.mana, 1), target: .actor),
            TargetedEffect(.drawAndPlayCards(1), target: .actor),
        ])
        battle.heroDeck = CombatDeck(abilities: [heroTalentHealingCard])
        let nested = try playHeroTalentCard(restoring, in: &battle)
        let nestedHeal = try #require(nested.first { $0.effectKind == .instantHeal && $0.abilityName == heroTalentHealingCard.name })
        #expect(nestedHeal.amount == (nestedHeal.isCritical ? 2 : 1))
        let next = try playHeroTalentCard(heroTalentHealingCard, in: &battle)
        let nextHeal = try #require(next.first { $0.effectKind == .instantHeal && $0.abilityName == heroTalentHealingCard.name })
        #expect(nextHeal.amount == (nextHeal.isCritical ? 2 : 1) + 1)
    }

    @Test func `fumes remove thorns before the poison hit can trigger them`() throws {
        var battle = heroTalentBattle("alchemist_poison_t3_1")
        seedHeroTalentEffect(.thorns(2), on: .enemy, in: &battle)
        let events = try playHeroTalentCard(.poisonDagger, in: &battle)
        let thorns = events.filter { $0.targetID == battle.hero.id && $0.amount > 0 }
        #expect(battle.roster.hero.currentHealth == 19)
        #expect(!thorns.isEmpty)
    }

    @Test func `poison card defenses respect conditions and repeats`() throws {
        var coating = heroTalentBattle("alchemist_poison_t1_1")
        try playHeroTalentCard(.bloodthorn, in: &coating)
        try playHeroTalentCard(.poisonDagger, in: &coating)
        #expect(talentPoints(.thorns, on: .hero, in: coating) == 2)
        var bark = heroTalentBattle("druid_poison_t1_2")
        try playHeroTalentCard(.poisonDagger, in: &bark)
        #expect(talentPoints(.shield, on: .hero, in: bark) == 0)
        seedHeroTalentEffect(.thorns(1), on: .hero, in: &bark)
        try playHeroTalentCard(.poisonDagger, in: &bark)
        try playHeroTalentCard(.poisonDagger, in: &bark)
        #expect(talentPoints(.shield, on: .hero, in: bark) == 2)
    }

    @Test func `resolved random burn does not count as poison`() throws {
        var burnRolls = 0
        var poisonRolls = 0
        for seed in UInt64(1) ... 20 {
            var battle = heroTalentBattle("alchemist_poison_t1_1", seed: seed)
            let events = try playHeroTalentCard(.cinderbloom, in: &battle)
            let original = try #require(events.first { $0.kind == .abilityDamage })
            #expect(talentPoints(.thorns, on: .hero, in: battle) == (original.keyword == .poison ? 1 : 0))
            if original.keyword == .burn {
                burnRolls += 1
            } else {
                poisonRolls += 1
            }
        }
        #expect(burnRolls > 0 && poisonRolls > 0)
    }

    @Test func `reactive sediment tracks the actors consecutive cards`() throws {
        var battle = heroTalentBattle("alchemist_poison_t2_1")
        try playHeroTalentCard(.kindling, in: &battle)
        try playHeroTalentCard(.block, owner: .companion, in: &battle)
        let events = try playHeroTalentCard(.poisonDagger, in: &battle)
        let hit = try #require(events.first { $0.kind == .abilityDamage && $0.keyword == .poison })
        #expect(hit.amount == Ability.poisonDagger.damageComponents[0].amount * (hit.isCritical ? 2 : 1) + 1)
        let again = try playHeroTalentCard(.poisonDagger, in: &battle)
        let repeated = try #require(again.first { $0.kind == .abilityDamage && $0.keyword == .poison })
        #expect(repeated.amount == Ability.poisonDagger.damageComponents[0].amount * (repeated.isCritical ? 2 : 1))
    }

    @Test func `paid in full waits through intervening cards and does not rearm itself`() throws {
        var battle = heroTalentBattle("wildcard_physical_t4_1")
        for _ in 0 ..< 2 {
            try playHeroTalentCard(.goldenPlate, in: &battle)
        }
        try playHeroTalentCard(.block, in: &battle)
        let before = battle.gold
        let first = try playHeroTalentCard(.slash, in: &battle)
        #expect(battle.gold == before + 2)
        #expect(first.count { $0.abilityName == "Paid in Full" && $0.keyword == .gold } == 1)
        try playHeroTalentCard(.slash, in: &battle)
        #expect(battle.gold == before + 2)
        try playHeroTalentCard(.goldenPlate, in: &battle)
        let beforeAgain = battle.gold
        try playHeroTalentCard(.slash, in: &battle)
        #expect(battle.gold == beforeAgain + 2)
    }

    @Test func `entangling growth requires companion stun in the same turn`() throws {
        var battle = heroTalentBattle("druid_poison_t3_2")
        try playHeroTalentCard(.bash, owner: .companion, in: &battle)
        let events = try playHeroTalentCard(.poisonDagger, in: &battle)
        let hit = try #require(events.first { $0.kind == .abilityDamage })
        #expect(hit.amount == (hit.isCritical ? 4 : 2) + 1)
        battle.turnCount += 1
        _ = CombatTriggerEngine.startHeroTalentTurn(in: &battle)
        let next = try playHeroTalentCard(.poisonDagger, in: &battle)
        let nextHit = try #require(next.first { $0.kind == .abilityDamage })
        #expect(nextHit.amount == (nextHit.isCritical ? 4 : 2))
    }

    @Test func `cleanse cards reward empty cleanse and remove thorns`() throws {
        var battle = heroTalentBattle("alchemist_cleanse_t1_1", "alchemist_cleanse_t1_2")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 0 }
        seedHeroTalentEffect(.thorns(2), on: .enemy, in: &battle)
        try playHeroTalentCard(.cleanse, in: &battle)
        try playHeroTalentCard(.cleanse, in: &battle)
        #expect(battle.roster.hero.currentMana == 2)
        #expect(talentPoints(.thorns, on: .enemy, in: battle) == 0)
    }

    @Test func `healing cards remove burn and basic healing removes block`() throws {
        var battle = heroTalentBattle("alchemist_health_t2_1", "alchemist_health_t3_2")
        seedHeroTalentEffect(.burn(2), on: .hero, in: &battle)
        seedHeroTalentEffect(.shield(.block, 2), on: .enemy, in: &battle)
        try playHeroTalentCard(.apple, in: &battle)
        #expect(talentPoints(.burn, on: .hero, in: battle) == 2)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 5 }
        try playHeroTalentCard(.apple, in: &battle)
        try playHeroTalentCard(.apple, in: &battle)
        #expect(talentPoints(.burn, on: .hero, in: battle) == 0)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 0)
    }

    @Test func `companion card healing has distinct prescription and pruning rewards`() throws {
        var battle = heroTalentBattle("alchemist_health_t3_1", "druid_health_t1_2")
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle)
        seedHeroTalentEffect(.thorns(2), on: .enemy, in: &battle)
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 4 }
        _ = CombatTriggerEngine.heroTalentHeal(to: battle.companion, source: battle.hero, name: "Reward", in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 2)
        try playHeroTalentCard(.apple, owner: .companion, in: &battle)
        try playHeroTalentCard(.apple, owner: .companion, in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
        #expect(talentPoints(.thorns, on: .enemy, in: battle) == 0)
    }

    @Test func `lucky charm removes poison on gold cards`() throws {
        var battle = heroTalentBattle("wildcard_gold_t2_2", "wildcard_gold_t3_2")
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle)
        seedHeroTalentEffect(.thorns(2), on: .enemy, in: &battle)
        try playHeroTalentCard(heroTalentGoldCard, in: &battle)
        try playHeroTalentCard(heroTalentGoldCard, in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
        #expect(talentPoints(.thorns, on: .enemy, in: battle) == 2)
    }

    @Test func `full house carries across turns and pays for each fresh set`() throws {
        var battle = heroTalentBattle("wildcard_gold_t2_1")
        for ability in [Ability.block, .block, .stoneskinPotion, .stoneskinPotion] {
            try playHeroTalentCard(ability, in: &battle)
        }
        #expect(battle.gold == 0)
        battle.turnCount += 1
        _ = CombatTriggerEngine.startHeroTalentTurn(in: &battle)
        try playHeroTalentCard(.thornMail, owner: .companion, in: &battle)
        #expect(battle.gold == 0)
        let first = try playHeroTalentCard(.thornMail, in: &battle)
        #expect(battle.gold == 5)
        #expect(first.contains { $0.abilityName == "Full House" && $0.effectKind == .cardsDrawn && $0.amount == 1 })
        try playHeroTalentCard(.block, in: &battle)
        try playHeroTalentCard(.stoneskinPotion, in: &battle)
        #expect(battle.gold == 5)
        let second = try playHeroTalentCard(.thornMail, in: &battle)
        #expect(battle.gold == 10)
        #expect(second.contains { $0.abilityName == "Full House" && $0.effectKind == .cardsDrawn })
    }

    @Test func `converted poison increases the existing hit without duplicating equipment bonuses`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["alchemist_poison_t4_1"])
        profile.damageDealtBonus[.poison] = 3
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroModifiers: profile, dealOpeningHand: false)
        battle.appliesFightPacing = false
        seedHeroTalentEffect(.poison(7), on: .hero, in: &battle, source: .enemy)
        let events = try playHeroTalentCard(.causticJab, in: &battle)
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.amount) == [11])
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 8)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
    }

    @Test(arguments: [Ability.steal, .bountyShot, .blackjack, .tithe])
    func `authored theft cards preserve gilded claws through outcome resolution`(ability: Ability) throws {
        var battle = capstoneBattle(companion: ["lizard_scout_gold_t3_2"])
        var stolen = 0
        for _ in 0 ..< 8 {
            seedHeroTalentEffect(.controlMeter(.stun, 40, 40), on: .enemy, in: &battle)
            seedHeroTalentEffect(.marked(3, 6), on: .enemy, in: &battle)
            let events = try playHeroTalentCard(ability, owner: .companion, in: &battle)
            stolen = events.filter { $0.effectKind == .resourceGain && $0.keyword == .gold }.reduce(0) { $0 + $1.amount }
            if stolen > 0 {
                break
            }
        }
        #expect(stolen > 0)
        #expect(battle.heroTalents.history[battle.companion.id]?.stolenGoldDamage == stolen)
        ActiveEffectMutation.removeMatching(from: battle.enemy, in: &battle) { $0.kind == .marked }
        let next = try playHeroTalentCard(.stab, owner: .companion, in: &battle)
        let hit = try #require(next.first { $0.kind == .abilityDamage && $0.keyword == .physical })
        #expect(hit.amount == (2 + stolen) * (hit.isCritical ? 2 : 1))
    }

    @Test func `unstable culture rewards natural enemy poison expiry without accumulating multipliers`() throws {
        var battle = heroTalentBattle("alchemist_poison_t3_2")
        for _ in 0 ..< 2 {
            seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle)
            _ = EffectTurnEngine.advanceAll(context: &battle)
        }
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 2)
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 3)
        let cleanseEnemy = Ability(id: "enemy-cleanse", name: "Cleanse Enemy", tier: .skill, targetedEffects: [
            TargetedEffect(.cleanse(.poison), target: .enemy),
        ])
        try playHeroTalentCard(cleanseEnemy, in: &battle)
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 1)
        ActiveEffectMutation.removeMatching(from: battle.enemy, in: &battle) { $0.kind == .poison }
        seedHeroTalentEffect(.poison(1), on: .hero, in: &battle)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 1)
    }

    @Test func `a cleansing attack cannot consume its own perfect purity`() throws {
        var battle = heroTalentBattle("alchemist_cleanse_t4_1")
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle, source: .enemy)
        let cleansingHit = Ability(
            id: "cleansing-hit", name: "Cleansing Hit", tier: .skill,
            damageComponents: [DamageComponent(1)],
            targetedEffects: [TargetedEffect(.cleanse(nil), target: .actor)],
        )
        let repeated = try playHeroTalentCard(cleansingHit, in: &battle)
        #expect(repeated.count { $0.kind == .abilityDamage && $0.keyword == .physical } == 1)
        #expect(!repeated.contains { $0.kind == .abilityDamage && $0.keyword == .poison })
        let next = try playHeroTalentCard(.stab, in: &battle)
        #expect(next.count { $0.kind == .abilityDamage && $0.keyword == .poison } == 1)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 2)
    }
}

extension TalentCatalogRoundTripTests {
    @Test func `elemental card talents use the random outcome`() throws {
        var freezeOutcomes = 0
        for seed in UInt64(1) ... 12 {
            var battle = heroTalentBattle("wizard_freeze_t3_2", seed: seed)
            battle.roster.hero.currentMana = 0
            try playHeroTalentCard(.rayOfFrost, in: &battle)
            try playHeroTalentCard(.rayOfFrost, in: &battle)
            let events = try playHeroTalentCard(.astralArrow, in: &battle)
            let hit = try #require(events.first { $0.kind == .abilityDamage })
            let isFreeze = hit.keyword == .freeze
            freezeOutcomes += isFreeze ? 1 : 0
            #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .freeze) == isFreeze)
        }
        #expect(freezeOutcomes > 0 && freezeOutcomes < 12)
    }

    @Test func `defeated card owner cannot trigger inferno barrage`() throws {
        var battle = heroTalentBattle("ranger_burn_t3_2")
        battle.roster.hero.currentHealth = 1
        battle.roster.hero.hasConsumedDeathsDoor = true
        seedHeroTalentEffect(.thorns(100), on: .enemy, in: &battle, source: .enemy)
        try playHeroTalentCard(.bloodthorn, in: &battle)
        #expect(!battle.roster.hero.isAlive)
        #expect(talentPoints(.burn, on: .enemy, in: battle) == 0)
    }
}
