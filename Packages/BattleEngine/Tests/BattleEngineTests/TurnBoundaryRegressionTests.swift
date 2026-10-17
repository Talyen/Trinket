import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct TurnBoundaryRegressionTests {
    private func makeManaShieldBattle(attackDamage: Int, heroMana: Int) -> BattleState {
        let attack = Ability(
            id: "enemy-attack", name: "Enemy Attack", tier: .basic,
            damageComponents: [DamageComponent(attackDamage, keyword: .physical, target: .hero)],
        )
        var profile = CombatantTalentCatalog.profile(for: ["wizard_mana_t1_2"])
        profile.triggers.dodgeChanceBonus = -1
        return BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [attack], heroMaxMana: heroMana, heroMana: heroMana,
            heroModifiers: profile, appliesFightPacing: false,
        )
    }

    @Test func `Mana reserves cannot indefinitely absorb attacks above the Shield talent budget`() {
        var battle = makeManaShieldBattle(attackDamage: 10, heroMana: 29)
        let health = battle.health(of: battle.hero)
        let events = battle.endTurn().events

        #expect(events.first { $0.abilityName == "Mana Shield" }?.amount == 6)
        #expect(battle.health(of: battle.hero) == health - 4)
        #expect(battle.mana(of: battle.hero) == 29)
    }

    @Test func `Mana Shield protects against the enemy attack following End Turn`() {
        var battle = makeManaShieldBattle(attackDamage: 4, heroMana: 4)
        let health = battle.health(of: battle.hero)
        let events = battle.endTurn().events
        #expect(battle.health(of: battle.hero) == health)
        let shieldIndex = events.firstIndex { $0.abilityName == "Mana Shield" }
        let attackIndex = events.firstIndex { $0.kind == .ability && $0.actorID == battle.enemy.id }
        #expect(shieldIndex != nil && attackIndex != nil)
        if let shieldIndex, let attackIndex {
            #expect(shieldIndex < attackIndex)
        }
    }

    @Test func `Mana Shield uses Mana restored by the preceding party regeneration`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 4, companionMana: 0,
            heroModifiers: .withTriggers {
                $0.partyRegenPerRound = 4
                $0.wishspring = true
                $0.criticalChanceBonus = -1
            },
            companionModifiers: .withTriggers { $0.unspentManaConvertsToBlock = true },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.companion.currentHealth = battle.roster.companion.maxHealth - 1

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerEndTurn(in: &battle) }

        #expect(battle.mana(of: battle.companion) == 2)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 2)
        #expect(events.first { $0.abilityName == "Mana Shield" }?.amount == 2)
    }

    @Test func `loyal companion draws for companion on alternating turns`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionAbilities: [.slash],
            heroModifiers: .withTriggers { $0.companionCardsEveryOtherTurn = 1 },
            dealOpeningHand: false,
        )
        for turn in 0 ... 3 {
            battle.turnCount = turn
            battle.hand = BattleHand()
            battle.companionDeck.putOnBottom(.slash)
            let events = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
            let drawn = events.filter { $0.effectKind == .cardsDrawn }.reduce(0) { $0 + $1.amount }
            #expect(drawn == (turn.isMultiple(of: 2) ? 1 : 0))
            #expect(battle.hand.cards.allSatisfy { $0.owner == .companion })
        }
    }

    @Test func `End Turn stops Hibernation after Arcane Cleansing wins the battle`() {
        var hero = CombatantTalentCatalog.profile(for: ["wizard_mana_t2_2"])
        hero.triggers.cleanseHolyDamage = 1
        let companion = CombatantTalentCatalog.profile(for: ["bear_block_t1_2"])
        var battle = cadenceBattle(heroModifiers: hero, companionModifiers: companion)
        battle.roster.hero.currentHealth = 20
        battle.roster.companion.currentHealth = 10
        battle.insertEffect(.poison(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        DefensePoolEngine.set(1, on: battle.companion, in: &battle)

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerEndTurn(in: &battle) }

        #expect(battle.isBattleOver)
        #expect(battle.health(of: battle.companion) == 10)
        #expect(!battle.roster.hasAffliction(.poison, on: battle.hero))
        #expect(!events.contains { $0.abilityName == "Hibernation" })
    }

    @Test func `Purifying Aura stops before cleansing its second ally after victory`() {
        let hero = CombatModifierProfile.zero
        var pixie = CombatantTalentCatalog.profile(for: ["pixie_cleanse_t1_1", "pixie_cleanse_t3_2"])
        pixie.triggers.criticalChanceBonus = -1
        pixie.triggers.cleanseHolyDamage = 1
        var battle = cadenceBattle(heroModifiers: hero, companionModifiers: pixie)
        battle.insertEffect(.poison(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.insertEffect(.burn(1), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 0)

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }

        #expect(battle.isBattleOver)
        #expect(!battle.roster.hasAffliction(.poison, on: battle.hero))
        #expect(battle.roster.hasAffliction(.burn, on: battle.companion))
        #expect(events.count(where: { $0.abilityName == "Purifying Aura" && $0.effectKind == .cleanseApplied }) == 1)
    }

    @Test func `Toxic Remedy prepares an attack while regeneration continues`() throws {
        var hero = CombatModifierProfile.zero
        let remedy = try #require(GameContent.itemAffixDefinition(matching: "mortar_and_pestle"))
        remedy.basic.triggers.apply(to: &hero, abilityName: remedy.title)
        var companion = CombatModifierProfile.zero
        for id in ["merchants_favor", "windfall", "groves_favor"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.astral.triggers.apply(to: &companion, abilityName: affix.title)
        }
        companion.triggers.criticalChanceBonus = -1
        var battle = cadenceBattle(heroModifiers: hero, companionModifiers: companion)

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }

        #expect(!battle.isBattleOver)
        #expect(battle.gold == 1)
        #expect(battle.health(of: battle.hero) == 14)
        #expect(events.contains { $0.abilityName == "Verdant Renewal" })
        #expect(battle.roster.hero.talents.pending.nextToxicRemedyDamageBonus?.value == 1)
    }

    private func cadenceBattle(
        heroModifiers: CombatModifierProfile,
        companionModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        var hero = heroModifiers
        hero.triggers.criticalChanceBonus = -1
        return BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100, maxMana: 4),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10, companionHealth: 20, enemyHealth: 1, heroMana: 0,
            heroModifiers: hero, companionModifiers: companionModifiers, appliesFightPacing: false,
        )
    }
}
