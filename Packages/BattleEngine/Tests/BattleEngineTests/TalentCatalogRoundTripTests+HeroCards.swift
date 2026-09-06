import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
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
    func `poison cards remove one point once per turn`(talent: String, owner: BattleParticipant, kind: EffectKind) throws {
        var battle = heroTalentBattle(talent)
        let effect: Effect = kind == .burn ? .burn(2) : .thorns(2)
        seedHeroTalentEffect(effect, on: owner, in: &battle)
        try playHeroTalentCard(.poisonDagger, in: &battle)
        #expect(talentPoints(kind, on: owner, in: battle) == 1)
        try playHeroTalentCard(.poisonDagger, in: &battle)
        #expect(talentPoints(kind, on: owner, in: battle) == 1)
        battle.turnCount += 1
        try playHeroTalentCard(.poisonDagger, in: &battle)
        #expect(talentPoints(kind, on: owner, in: battle) == 0)
    }

    @Test func `card repeats do not double per card rewards`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["alchemist_poison_t1_1"])
        profile.triggers.merge(CombatTraitTriggers(mana: ManaTriggers(firstSkillCardPlaysTwicePerBattle: true)))
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroModifiers: profile, dealOpeningHand: false)
        battle.appliesFightPacing = false
        let events = try playHeroTalentCard(.poisonDagger, in: &battle)
        #expect(events.count { $0.kind == .abilityDamage } == 2)
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 1)
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
        #expect(talentPoints(.thorns, on: .hero, in: coating) == 1)
        var bark = heroTalentBattle("druid_poison_t1_2")
        try playHeroTalentCard(.poisonDagger, in: &bark)
        #expect(talentPoints(.shield, on: .hero, in: bark) == 0)
        seedHeroTalentEffect(.thorns(1), on: .hero, in: &bark)
        try playHeroTalentCard(.poisonDagger, in: &bark)
        try playHeroTalentCard(.poisonDagger, in: &bark)
        #expect(talentPoints(.shield, on: .hero, in: bark) == 1)
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

    @Test func `sediment and paid in full track only the actors consecutive cards`() throws {
        let cases: [(String, Ability, Ability, Keyword)] = [
            ("alchemist_poison_t2_1", Ability.kindling, .poisonDagger, Keyword.poison),
            ("wildcard_physical_t4_1", heroTalentGoldCard, heroTalentPhysicalCard, .physical),
        ]
        for (talent, preceding, following, keyword) in cases {
            var battle = heroTalentBattle(talent)
            try playHeroTalentCard(preceding, in: &battle)
            try playHeroTalentCard(.block, owner: .companion, in: &battle)
            let events = try playHeroTalentCard(following, in: &battle)
            let hit = try #require(events.first { $0.kind == .abilityDamage && $0.keyword == keyword })
            let base = following.damageComponents[0].amount * (hit.isCritical ? 2 : 1)
            #expect(hit.amount == base + 1)
            let again = try playHeroTalentCard(following, in: &battle)
            let repeated = try #require(again.first { $0.kind == .abilityDamage && $0.keyword == keyword })
            #expect(repeated.amount == following.damageComponents[0].amount * (repeated.isCritical ? 2 : 1))
        }
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

    @Test func `cleanse cards reward empty cleanse and remove thorns once`() throws {
        var battle = heroTalentBattle("alchemist_cleanse_t1_1", "alchemist_cleanse_t1_2")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 0 }
        seedHeroTalentEffect(.thorns(2), on: .enemy, in: &battle)
        try playHeroTalentCard(.cleanse, in: &battle)
        try playHeroTalentCard(.cleanse, in: &battle)
        #expect(battle.roster.hero.currentMana == 1)
        #expect(talentPoints(.thorns, on: .enemy, in: battle) == 1)
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
        #expect(talentPoints(.burn, on: .hero, in: battle) == 1)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 1)
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
        #expect(talentPoints(.poison, on: .hero, in: battle) == 1)
        #expect(talentPoints(.thorns, on: .enemy, in: battle) == 1)
    }

    @Test func `gold cards clean poison and consume dodge preparation once`() throws {
        var battle = heroTalentBattle("wildcard_gold_t2_2", "wildcard_gold_t3_2")
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle)
        seedHeroTalentEffect(.thorns(2), on: .enemy, in: &battle)
        _ = CombatTriggerEngine.afterHeroTalentDodge(by: battle.hero, in: &battle)
        try playHeroTalentCard(heroTalentGoldCard, in: &battle)
        try playHeroTalentCard(heroTalentGoldCard, in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 1)
        #expect(talentPoints(.thorns, on: .enemy, in: battle) == 1)
    }

    @Test func `full house requires all three tiers and pays only once`() throws {
        var battle = heroTalentBattle("wildcard_gold_t2_1")
        for ability in [Ability.block, .stoneskinPotion, Ability(id: "test-ultimate", name: "Ultimate", tier: .ultimate)] {
            try playHeroTalentCard(ability, in: &battle)
        }
        #expect(battle.gold == 1)
        try playHeroTalentCard(.block, in: &battle)
        #expect(battle.gold == 1)
    }
}
