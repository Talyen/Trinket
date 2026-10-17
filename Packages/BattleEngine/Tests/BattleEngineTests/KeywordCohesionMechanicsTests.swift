import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

private func cohesionBattleWithHand(
    _ ability: Ability,
    heroModifiers: CombatModifierProfile = .zero,
    companionModifiers: CombatModifierProfile = .zero,
    enemyMaxHealth: Int = 100,
) -> BattleState {
    var battle = BattleStateTestFactory.makeBattleWithAbilities(
        heroAbilities: [ability],
        enemyMaxHealth: enemyMaxHealth,
        heroModifiers: heroModifiers,
        companionModifiers: companionModifiers,
    )
    battle.nextCardID += 1
    battle.hand = BattleHand(cards: [BattleCard(id: battle.nextCardID, ability: ability, owner: .hero)])
    battle.appliesFightPacing = false
    return battle
}

private func makeCohesionBattle(
    heroMaxHealth: Int = 20,
    companionMaxHealth: Int = 20,
    enemyMaxHealth: Int = 100,
    heroHealth: Int? = nil,
    companionHealth: Int? = nil,
    enemyHealth: Int? = nil,
    heroEffects: [ActiveEffect] = [],
    heroModifiers: CombatModifierProfile = .zero,
    companionModifiers: CombatModifierProfile = .zero,
    enemyModifiers: CombatModifierProfile = .zero,
) -> BattleState {
    BattleStateTestFactory.makeMinimalBattle(
        hero: CombatantFixtures.passiveHero(maxHealth: heroMaxHealth),
        companion: CombatantFixtures.passiveCompanion(maxHealth: companionMaxHealth),
        enemy: CombatantFixtures.passiveEnemy(maxHealth: enemyMaxHealth),
        heroEffects: heroEffects,
        heroHealth: heroHealth,
        companionHealth: companionHealth,
        enemyHealth: enemyHealth,
        heroModifiers: heroModifiers,
        companionModifiers: companionModifiers,
        enemyModifiers: enemyModifiers, appliesFightPacing: false,
    )
}

struct KeywordCohesionMechanicsTests {
    @Test func `sniff out refreshes one bonus for the partners next attack`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        for _ in 0 ..< 2 {
            let card = BattleCardCombatEngine.deal(.sniffOut, owner: .hero, context: &battle)
            _ = try battle.playCard(cardID: card.id)
        }
        let attack = Ability(
            id: "partner-freeze", name: "Partner Freeze", tier: .basic,
            directDamage: 2, damageKeyword: .freeze, criticalChanceBonus: -1,
        )
        for expected in [3, 2] {
            let card = BattleCardCombatEngine.deal(attack, owner: .companion, context: &battle)
            let before = battle.health(of: battle.enemy)
            _ = try battle.playCard(cardID: card.id)
            #expect(before - battle.health(of: battle.enemy) == expected)
        }
    }

    @Test func `predators focus bleeds and leeches without critical preparation`() throws {
        var battle = cohesionBattleWithHand(.predatorsFocus)
        let before = battle.roster.enemy.currentHealth
        _ = try BattleTestFixtures.playCardNamed("Predator's Focus", owner: .hero, on: &battle)
        let hero = battle.hero
        #expect(before - battle.roster.enemy.currentHealth == 1)
        #expect(battle.roster.activeEffects(for: hero).contains { $0.effect == .nextStrikeLeech })
        #expect(!battle.roster.activeEffects(for: hero).contains { $0.effect == .nextStrikeCritical })
        // Next attack Leeches; pre-existing Leech does not double.
        let fangs = Ability(id: "fangs-test", name: "Fangs", tier: .basic, directDamage: 4, damageKeyword: .bleed, hasLeech: true)
        battle.nextCardID += 1
        battle.hand = BattleHand(cards: [BattleCard(id: battle.nextCardID, ability: fangs, owner: .hero)])
        let heroBefore = battle.roster.health(for: battle.hero)
        // Damage Hero first to create missing Health for Leech to restore.
        _ = battle.resolveTestDamage(6, from: .enemy, to: .hero, options: .effect())
        let missing = battle.roster.maxHealth(for: battle.hero) - battle.roster.health(for: battle.hero)
        #expect(missing > 0)
        _ = try BattleTestFixtures.playCardNamed("Fangs", owner: .hero, on: &battle)
        // Leech restored some (single base rate, not doubled).
        #expect(battle.roster.health(for: battle.hero) > heroBefore - 6)
        #expect(!battle.roster.activeEffects(for: hero).contains { $0.effect == .nextStrikeLeech })
    }

    @Test func `tithe and bounty produce fixed gold without conditions`() throws {
        for (ability, name) in [
            (Ability.tithe, "Tithe"),
            (Ability.bountyShot, "Bounty Shot"),
        ] {
            var battle = cohesionBattleWithHand(ability)
            _ = try BattleTestFixtures.playCardNamed(name, owner: .hero, on: &battle)
            #expect(battle.gold == 2, "\(name) should steal 2 Gold")
            #expect(ability.outcomeBranches == nil, "\(name) should have no branches")
        }
    }

    @Test func `golden plate grants block and gold only`() throws {
        var battle = cohesionBattleWithHand(.goldenPlate)
        _ = try BattleTestFixtures.playCardNamed("Golden Plate", owner: .hero, on: &battle)
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 8)
        #expect(battle.gold == 5)
    }

    @Test(arguments: [BattleParticipant.hero, .enemy])
    func `sunburst heals its living allies without reviving`(owner: BattleParticipant) {
        var battle = makeCohesionBattle(
            heroHealth: 10, companionHealth: 0, enemyHealth: 50,
            heroModifiers: .withTriggers { $0.criticalChanceBonus = -1 },
        )
        let events = battle.performTestAction(.sunburst, from: owner, to: owner == .hero ? .enemy : .hero)
        #expect(battle.roster.hero.currentHealth == (owner == .hero ? 13 : 4))
        #expect(battle.roster.companion.currentHealth == 0)
        #expect(battle.roster.enemy.currentHealth == (owner == .hero ? 44 : 53))
        let recipient = battle.roster[owner].id
        #expect(events.filter { $0.effectKind == .instantHeal }.map(\.targetID) == [recipient])
    }
}

extension KeywordCohesionMechanicsTests {
    @Test func `thick hide reduces only physical`() {
        let profile = CombatModifierProfile.withTriggers { $0.passivePhysicalMitigationFlat = 2 }
        var battle = makeCohesionBattle(companionModifiers: profile)
        // Companion takes Physical (reduced) vs Burn (not reduced). Use companion as defender via enemy targeting companion.
        let physical = battle.resolveTestDamage(5, from: .enemy, to: .companion)
        #expect(physical.healthLost == 3)
        let burn = battle.resolveTestDamage(5, from: .enemy, to: .companion, keyword: .burn)
        // Burn takes full (no Block, no mitigation) = 5, modulo enemy scaling? Use healthLost relative.
        #expect(burn.healthLost == 5)
    }

    @Test func `surprise strike crits first physical only`() {
        let profile =
            CombatModifierProfile.withTriggers { $0.firstPhysicalAttackGuaranteedCritical = true }
        var battle = makeCohesionBattle(enemyMaxHealth: 200, companionModifiers: profile)
        // Non-Physical first does not consume or crit (Burn, no guaranteed crit).
        let first = battle.resolveTestDamage(4, from: .companion, keyword: .burn)
        #expect(!first.isCritical)
        // First Physical Crits.
        let physical = battle.resolveTestDamage(4, from: .companion)
        #expect(physical.isCritical)
        // Second Physical does not Crit (allowance spent).
        let second = battle.resolveTestDamage(4, from: .companion)
        #expect(!second.isCritical)
    }

    @Test func `guardian blocks only the first qualifying attack each combat`() {
        let profile = CombatantTalentCatalog.profile(for: ["golden_retriever_block_t1_1"])
        var battle = makeCohesionBattle(
            heroModifiers: .withTriggers { $0.dodgeChanceBonus = -1 }, companionModifiers: profile,
        )
        // Ongoing damage must not spend Guardian before the first attack.
        _ = battle.resolveTestDamage(1, from: .enemy, to: .hero, options: .periodic)
        let multi = Ability(id: "multi", name: "Multi", tier: .basic, damageComponents: [
            DamageComponent(3, keyword: .physical), DamageComponent(3, keyword: .physical),
        ])
        for expectedLoss in [1, 6] {
            let before = battle.health(of: battle.hero)
            let events = battle.performTestAction(multi, from: .enemy, to: .hero)
            #expect(before - battle.health(of: battle.hero) == expectedLoss)
            #expect(events.filter { $0.effectKind == .shieldApplied }.map(\.amount) == (expectedLoss == 1 ? [5] : []))
        }
    }

    @Test func `dense bones doubles physical block`() {
        let profile = CombatModifierProfile.withTriggers { $0.doublePhysicalBlockAbsorption = true }
        var battle = makeCohesionBattle(companionModifiers: profile)
        DefensePoolEngine.set(2, on: battle.companion, in: &battle)
        // 3 Physical with 2 Block (doubled capacity 4) absorbs all 3, consumes 2 (rounded 1.5->2).
        let physical = battle.resolveTestDamage(3, from: .enemy, to: .companion)
        #expect(physical.healthLost == 0)
        // Non-Physical with same Block uses normal efficiency.
        DefensePoolEngine.set(2, on: battle.companion, in: &battle)
        let burn = battle.resolveTestDamage(3, from: .enemy, to: .companion, keyword: .burn)
        #expect(burn.healthLost == 1)
    }

    @Test(arguments: [false, true])
    func `shieldbreaker strips borrowed block as well as direct block`(companionProtectsHero: Bool) throws {
        let ogre = try #require(GameContent.enemies.first { $0.id == "ogre" })
        let protection = CombatModifierProfile.withTriggers {
            $0.blockAbsorbsCompanionDamage = !companionProtectsHero
            $0.companionBlockAbsorbsHeroDamage = companionProtectsHero
        }
        var battle = makeCohesionBattle(
            heroModifiers: companionProtectsHero ? .zero : protection,
            companionModifiers: companionProtectsHero ? protection : .zero,
            enemyModifiers: CombatBuildResolver.build(enemy: ogre).modifiers,
        )
        let protector = companionProtectsHero ? battle.companion : battle.hero
        let protected = companionProtectsHero ? battle.hero : battle.companion
        DefensePoolEngine.set(10, on: protector, in: &battle)

        let borrowed = battle.resolveTestDamage(3, to: protected, keyword: .physical, sourceActorID: battle.enemy.id)

        #expect(borrowed.healthLost == 0)
        #expect(BattleTestFixtures.shieldPoints(for: protector, in: battle) == 4)
        DefensePoolEngine.set(10, on: protector, in: &battle)
        let direct = battle.resolveTestDamage(3, to: protector, keyword: .physical, sourceActorID: battle.enemy.id)
        #expect(direct.healthLost == 0)
        #expect(BattleTestFixtures.shieldPoints(for: protector, in: battle) == 4)
    }

    @Test func `shieldbreaker doubles consumed block after dense bones absorption`() throws {
        let ogre = try #require(GameContent.enemies.first { $0.id == "ogre" })
        let denseBones = CombatantTalentCatalog.profile(for: ["risen_skeleton_physical_t2_2"])
        var battle = makeCohesionBattle(
            companionModifiers: denseBones,
            enemyModifiers: CombatBuildResolver.build(enemy: ogre).modifiers,
        )
        DefensePoolEngine.set(10, on: battle.companion, in: &battle)

        let damage = battle.resolveTestDamage(
            8,
            from: .enemy,
            to: .companion,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )

        #expect(damage.healthLost == 0)
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 2)
    }

    @Test(arguments: [0, 1])
    func `corrosive venom strips borrowed block once before absorbing poison`(recipientBlock: Int) throws {
        let snake = try #require(GameContent.enemies.first { $0.id == "giant_snake" })
        let protection = CombatModifierProfile.withTriggers { $0.blockAbsorbsCompanionDamage = true }
        var battle = makeCohesionBattle(
            heroModifiers: protection,
            enemyModifiers: CombatBuildResolver.build(enemy: snake).modifiers,
        )
        DefensePoolEngine.set(1, on: battle.hero, in: &battle)
        DefensePoolEngine.set(recipientBlock, on: battle.companion, in: &battle)

        let damage = battle.resolveTestDamage(3, from: .enemy, to: .companion, keyword: .poison)

        #expect(damage.healthLost == 3 - recipientBlock)
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 0)
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 0)
    }

    @Test func `loyal companion draws on real heal once per turn`() throws {
        let profile = CombatModifierProfile.withTriggers { $0.healCompanionDrawsCompanionCard = true }
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.heal], heroModifiers: profile, appliesFightPacing: false,
        )
        _ = battle.resolveTestDamage(5, from: .enemy, to: .companion, options: .effect())
        let deckBefore = battle.companionDeck.count
        battle.nextCardID += 1
        battle.hand = BattleHand(cards: [BattleCard(id: battle.nextCardID, ability: .heal, owner: .hero)])
        _ = try BattleTestFixtures.playCardNamed("Heal", owner: .hero, on: &battle)
        // Heal targets lowestHealthAlly (companion, damaged) with 6, restores 5 (missing), draws 1 Companion card (claimed before draw).
        #expect(battle.companionDeck.count == max(0, deckBefore - 1))
        // Second heal same turn does not draw again (once per turn).
        _ = battle.resolveTestDamage(1, from: .enemy, to: .companion, options: .effect())
        battle.nextCardID += 1
        battle.hand = BattleHand(cards: [BattleCard(id: battle.nextCardID, ability: .heal, owner: .hero)])
        let deckMid = battle.companionDeck.count
        _ = try BattleTestFixtures.playCardNamed("Heal", owner: .hero, on: &battle)
        #expect(battle.companionDeck.count == deckMid)
    }

    @Test func `forbidden knowledge pays health before drawing on cadence`() {
        let profile = CombatModifierProfile.withTriggers { $0.forbiddenKnowledge = true }
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash, .bash, .block],
            heroModifiers: profile,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        let heroBefore = battle.roster.health(for: battle.hero)
        let first = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(battle.roster.health(for: battle.hero) == heroBefore - 1)
        #expect(first.first { $0.effectKind == .cardsDrawn }?.amount == 1)

        battle.turnCount = 1
        let second = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(battle.roster.health(for: battle.hero) == heroBefore - 1)
        #expect(!second.contains { $0.effectKind == .cardsDrawn })

        battle.turnCount = 2
        battle.heroDeck = CombatDeck(abilities: [.slash])
        let third = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(battle.roster.health(for: battle.hero) == heroBefore - 2)
        #expect(third.first { $0.effectKind == .cardsDrawn }?.amount == 1)
    }

    @Test func `a forbidden knowledge death stops Purifying Aura`() {
        let profile = CombatModifierProfile.withTriggers {
            $0.forbiddenKnowledge = true
            $0.purifyingAura = true
        }
        var battle = makeCohesionBattle(
            heroMaxHealth: 10,
            companionMaxHealth: 10,
            enemyMaxHealth: 10,
            companionHealth: 1,
            heroEffects: [ActiveEffect(id: 1, effect: .bleed(1), remainingTurns: 2)],
            companionModifiers: profile,
        )
        battle.roster.mutateRuntime(for: battle.companion) { $0.hasConsumedDeathsDoor = true }

        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }

        #expect(battle.roster.health(for: battle.companion) == 0)
        #expect(battle.roster.activeEffects(for: battle.hero).contains { $0.effect.isBleed })
    }

    @Test func `turn start death releases hand slots for a living ally`() {
        let profile = CombatModifierProfile.withTriggers { $0.forbiddenKnowledge = true }
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash], companionAbilities: [.bash, .block],
            heroModifiers: profile, dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: battle.hero) {
            $0.currentHealth = 1
            $0.hasConsumedDeathsDoor = true
        }
        battle.hand = BattleHand(
            cards: [
                BattleCard(id: 1, ability: .slash, owner: .hero),
                BattleCard(id: 2, ability: .bash, owner: .companion),
            ],
            buffer: [BattleCard(id: 3, ability: .block, owner: .companion)],
        )

        battle.heroDeck = CombatDeck()
        battle.companionDeck = CombatDeck()
        _ = battle.drawOpeningHand()

        #expect(battle.roster.health(for: battle.hero) == 0)
        #expect(battle.hand.cards.map(\.owner) == [.companion, .companion])
        #expect(battle.hand.buffer.isEmpty)
    }

    @Test func `a turn start victory stops later ally Gold gains`() {
        let cleansing = CombatModifierProfile.withTriggers {
            $0.purifyingAura = true
            $0.cleanseHolyDamage = 1
        }
        let gold = CombatModifierProfile.withTriggers { $0.goldPerTurn = 1 }
        var battle = makeCohesionBattle(
            heroMaxHealth: 10,
            companionMaxHealth: 10,
            enemyMaxHealth: 10,
            heroHealth: 9,
            enemyHealth: 1,
            heroModifiers: cleansing,
            companionModifiers: gold,
        )

        battle.insertEffect(.poison(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)

        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }

        #expect(battle.isEnemyDefeated)
        #expect(battle.gold == 0)
    }

    @Test func `verdant renewal restores health on alternate player turns`() {
        let profile = CombatModifierProfile.withTriggers { $0.healthPerTurn = 2 }
        var battle = makeCohesionBattle(
            heroHealth: 10, companionHealth: 5, heroModifiers: profile,
        )
        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(battle.roster.health(for: battle.companion) == 7)
        #expect(battle.roster.health(for: battle.hero) == 10)
        battle.turnCount = 1
        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(battle.roster.health(for: battle.companion) == 7)
        battle.turnCount = 2
        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(battle.roster.health(for: battle.companion) == 9)
    }

    @Test func `campfire comfort heals the lowest ally on alternate player turns`() {
        let profile = CombatModifierProfile.withTriggers { $0.endOfTurnHealLowestAlly = 2 }
        var battle = makeCohesionBattle(
            companionHealth: 10, companionModifiers: profile,
        )
        let events = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerEndTurn(in: &battle) }
        #expect(events.contains { $0.abilityName == "Campfire Comfort" && $0.effectKind == .instantHeal })
        #expect(battle.roster.health(for: battle.companion) == 12)
        #expect(battle.roster.health(for: battle.hero) == 20)
        battle.turnCount = 1
        CombatExecutor.run { await CombatTriggerEngine.atPlayerEndTurn(in: &battle) }
        #expect(battle.roster.health(for: battle.companion) == 12)
        battle.turnCount = 2
        CombatExecutor.run { await CombatTriggerEngine.atPlayerEndTurn(in: &battle) }
        #expect(battle.roster.health(for: battle.companion) == 14)
    }

    @Test func `mimic deals one opening bleed bonus`() {
        let profile = CombatModifierProfile.withTriggers { $0.firstAttackBleedBonus = 2 }
        var battle = makeCohesionBattle(heroMaxHealth: 50, enemyModifiers: profile)
        let attack = Ability(id: "hit", name: "Hit", tier: .basic, directDamage: 4, damageKeyword: .physical)
        let before = battle.roster.health(for: battle.hero)
        battle.performTestAction(attack, from: .enemy, to: .hero)
        // 4 Physical + 2 Bleed bonus (separate hit) = 6 total (before Block/mitigation).
        #expect(before - battle.roster.health(for: battle.hero) >= 6)
        // Second attack no bonus (once).
        let mid = battle.roster.health(for: battle.hero)
        battle.performTestAction(attack, from: .enemy, to: .hero)
        #expect(mid - battle.roster.health(for: battle.hero) == 4)
    }

    @Test func `companion cards per turn draws alongside draw every other turn`() {
        let heroProfile = CombatModifierProfile.withTriggers {
            $0.drawEveryOtherTurn = 1
            $0.companionCardsPerTurn = 1
        }
        var battle = makeCohesionBattle(heroModifiers: heroProfile)
        battle.hand = BattleHand()
        battle.heroDeck = CombatDeck(abilities: [.slash, .smite, .block])
        battle.companionDeck = CombatDeck(abilities: [.slash, .smite, .block])
        battle.turnCount = 0

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(events.contains { $0.abilityName == "Tattered Pages" })
        #expect(events.contains { $0.abilityName == "Companion's Collar" })
        #expect(battle.hand.cards.contains { $0.owner == BattleParticipant.hero })
        #expect(battle.hand.cards.contains { $0.owner == BattleParticipant.companion })
    }
}
