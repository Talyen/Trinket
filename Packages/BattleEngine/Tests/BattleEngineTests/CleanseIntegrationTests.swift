import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CleanseIntegrationTests {
    private let cleanseAll = Ability(
        id: "cleanse-all", name: "Cleanse All", tier: .basic,
        description: "Cleanse all debuffs.", effects: [.cleanse(nil)],
    )

    private func makeCleanseBattle(
        heroAbility: Ability = .panaceaPotion,
        heroMaxHealth: Int = 20,
        enemyMaxHealth: Int = 100,
        activeHeroEffects: [ActiveEffect] = [],
        heroModifiers: CombatModifierProfile = .zero,
        dealOpeningHand: Bool = true,
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: heroMaxHealth, abilities: [heroAbility]),
            enemy: CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: enemyMaxHealth),
            activeHeroEffects: activeHeroEffects,
            heroModifiers: heroModifiers,
            dealOpeningHand: dealOpeningHand,
        )
    }

    @Test(arguments: [Keyword.stun, .freeze])
    func `cleansing control lets an ally play newly drawn cards this turn`(keyword: Keyword) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroAbilities: [.slash], dealOpeningHand: false)
        battle.appendEffect(.controlMeter(keyword, 10, 10), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        _ = battle.finalizeOpeningHand()
        #expect(battle.ownersSkippingThisPlayerTurn.contains(.hero))

        _ = EffectHandlersTestSupport.dispatch(
            .cleanse(keyword), source: battle.companion, target: battle.hero, battle: &battle,
        )
        let card = try #require(BattleCardCombatEngine.drawOne(for: .hero, context: &battle))
        #expect(BattleCardCombatEngine.isCardPlayable(card, in: battle))
        _ = try battle.playCard(cardID: card.id)
    }

    @Test(arguments: [Effect.cleanse(nil), .cleanseRandom], [
        ActiveEffect(id: 90, effect: .poison(7), remainingTurns: 0),
        ActiveEffect(id: 90, effect: .bleed(5), remainingTurns: 1),
        ActiveEffect(id: 90, effect: .damageReductionFlat(3, 3), remainingTurns: 2),
    ])
    func `legacy reflection preserves removed effect`(cleanse: Effect, debuff: ActiveEffect) throws {
        let owl = try BattleTestFixtures.catalogBuild(combatantID: "library_owl")
        var reflection = CombatModifierProfile.zero
        reflection.triggers.cleanseReflectDebuffToEnemy = true
        var battle = BattleStateTestFactory.makeBattle(companion: owl.combatant, companionModifiers: reflection)
        var applied = debuff
        applied.sourceActorID = battle.enemy.id
        battle.roster.hero.activeEffects = [applied]
        let handler = EffectHandlers.handler(for: cleanse.kind)
        let enemyHealth = battle.roster.enemy.currentHealth

        _ = CombatExecutor.run { await handler.apply(
            cleanse, ability: .panaceaPotion, source: battle.companion, target: battle.hero, in: &battle,
        ) }

        #expect(battle.roster.hero.activeEffects.isEmpty)
        let reflected = try #require(battle.roster.enemy.activeEffects.first { $0.effect.kind == debuff.effect.kind })
        #expect(reflected.effect == debuff.effect)
        #expect(reflected.remainingTurns == debuff.remainingTurns)
        #expect(reflected.sourceActorID == battle.companion.id)
        #expect(battle.roster.enemy.currentHealth == enemyHealth)
    }

    @Test func `reflected bleed preserves duration on a poisoned enemy`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.cleanseReflectDebuffToEnemy = true
        profile.triggers.bleedDurationVsPoisonedBonus = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appendEffect(.poison(3), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        battle.appendEffect(.bleed(2), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 1)
        let health = battle.health(of: battle.enemy)

        _ = EffectHandlersTestSupport.dispatch(
            .cleanse(.bleed), source: battle.hero, target: battle.companion, battle: &battle,
        )

        let reflected = try #require(battle.activeEffects(of: battle.enemy).first { $0.effect.isBleed })
        #expect(reflected.effect == .bleed(2))
        #expect(reflected.remainingTurns == 1)
        #expect(battle.health(of: battle.enemy) == health)
    }

    @Test(arguments: [
        (10, 11, true, true, 16, 11),
        (14, 6, true, false, 14, 12),
        (10, 15, false, false, 16, 15),
    ])
    func `panacea cleanses most debuffed and heals lowest including an empty cleanse`(
        heroHealth: Int, companionHealth: Int, debuffed: Bool, shielded: Bool,
        expectedHero: Int, expectedCompanion: Int,
    ) throws {
        let debuffs: [ActiveEffect] = debuffed ? [
            ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0),
            ActiveEffect(id: 2, effect: .burn(4), remainingTurns: 0),
        ] : []
        let buffs = shielded ? [ActiveEffect(id: 3, effect: .shield(.block, 10), remainingTurns: 6)] : []
        var battle = makeCleanseBattle(activeHeroEffects: debuffs + buffs)
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = heroHealth
        battle.roster.companion.currentHealth = companionHealth

        let events = try #require(try BattleTestFixtures.playUntilAbility("Panacea Potion", on: &battle))
        #expect(!battle.activeEffects(of: battle.hero).contains(where: \.effect.isRemovableDebuff))
        #expect(battle.health(of: battle.hero) == expectedHero)
        #expect(battle.health(of: battle.companion) == expectedCompanion)
        if shielded {
            #expect(events.first?.effectKind == .cleanseApplied)
            #expect(battle.activeEffects(of: battle.hero).contains { $0.effect.kind == .shield })
            #expect(events.count { $0.effectKind == .instantHeal } == 1)
        }
    }

    @Test func `cleanse specific keyword removes matching debuffs on use`() throws {
        let cleansePoison = Ability(
            id: "cleanse-poison",
            name: "Cleanse Poison",
            tier: .basic,
            description: "Cleanse Poisoned.",
            effects: [.cleanse(.poison)],
        )
        var battle = makeCleanseBattle(
            heroAbility: cleansePoison,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTurns: 0),
            ],
        )

        let events = try BattleTestFixtures.playCardNamed("Cleanse Poison", owner: .hero, on: &battle)

        try #expect(events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .poison })
        try #expect(!(battle.hasHeroEffect {
            if case .poison = $0 {
                return true
            }; return false
        }))
        try #expect(battle.hasHeroEffect {
            if case .burn = $0 {
                return true
            }; return false
        })
    }

    @Test func `cleanse stun removes control meter buildup`() throws {
        let cleanseAbility = Ability(
            id: "test-cleanse",
            name: "Test Cleanse",
            tier: .basic,
            description: "Cleanse Stunned.",
            targetedEffects: [TargetedEffect(.cleanse(.stun))],
        )
        var battle = makeCleanseBattle(
            heroAbility: cleanseAbility,
            heroMaxHealth: 50,
            enemyMaxHealth: 10,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 5, 10), remainingTurns: 0),
            ],
        )

        _ = try BattleTestFixtures.playCardNamed("Test Cleanse", owner: .hero, on: &battle)

        try #expect(!battle.hasHeroEffect { $0.isControlMeter }, "Cleanse removed buildup")
    }

    @Test func `cleanse all debuffs triggers toxic backlash trait damage when curing poison`() throws {
        var triggers = CombatTraitTriggers()
        triggers.onCleansePoisonDealDamagePerStack = 5
        var battle = makeCleanseBattle(
            heroAbility: cleanseAll,
            heroMaxHealth: 50,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .poison(4), remainingTurns: 0),
                ActiveEffect(id: 3, effect: .burn(4), remainingTurns: 0),
            ],
            heroModifiers: CombatModifierProfile(triggers: triggers),
        )

        let events = try BattleTestFixtures.playCardNamed("Cleanse All", owner: .hero, on: &battle)

        try #expect(events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .poison })
        try #expect(events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .burn })
        try #expect(battle.health(of: battle.enemy) == 90)
    }

    @Test(arguments: [false, true])
    func `cleanse party block rewards one successful removal across mixed debuffs`(hasDebuffs: Bool) throws {
        let debuffs = [Effect.poison(4), .burn(4), .bleed(4)].enumerated().map {
            ActiveEffect(id: $0.offset + 1, effect: $0.element, remainingTurns: 0)
        }
        var battle = makeCleanseBattle(
            heroAbility: cleanseAll, heroMaxHealth: 50,
            activeHeroEffects: hasDebuffs ? debuffs : [],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(cleanse: CleanseTriggers(cleansePartyBlock: 2))),
        )
        let events = try BattleTestFixtures.playCardNamed("Cleanse All", owner: .hero, on: &battle)
        if hasDebuffs {
            #expect(events.first?.effectKind == .cleanseApplied)
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == (hasDebuffs ? 2 : 0))
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == (hasDebuffs ? 2 : 0))
    }

    @Test func `purifying wisdom does not draw or consume claim on empty cleanse`() {
        let cleanseAbility = Ability(
            id: "cleanse-one",
            name: "Cleanse",
            tier: .basic,
            effects: [.cleanse(nil)],
        )
        var battle = makeCleanseBattle(
            heroAbility: cleanseAbility, heroMaxHealth: 50,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(cleanse: CleanseTriggers(cleanseBonusDraw: 1))),
            dealOpeningHand: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.slash, .smite, .block])

        let initialHandCount = battle.hand.count
        _ = EffectHandlersTestSupport.dispatch(
            .cleanse(nil), source: battle.hero, target: battle.hero, battle: &battle,
        )

        #expect(battle.hand.count == initialHandCount)

        battle.appendEffect(.poison(3), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        _ = EffectHandlersTestSupport.dispatch(
            .cleanse(nil), source: battle.hero, target: battle.hero, battle: &battle,
        )

        #expect(battle.hand.count == initialHandCount + 1)

        // Third cleanse with a new debuff does not draw again (once per combat)
        battle.appendEffect(.bleed(3), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 1)
        _ = EffectHandlersTestSupport.dispatch(
            .cleanse(nil), source: battle.hero, target: battle.hero, battle: &battle,
        )
        #expect(battle.hand.count == initialHandCount + 1)
    }
}

extension CleanseIntegrationTests {
    @Test(arguments: [Keyword.stun, .freeze])
    func `legacy reflection returns triggered control to a tougher enemy`(keyword: Keyword) throws {
        let owl = try BattleTestFixtures.catalogBuild(combatantID: "library_owl")
        var reflection = CombatModifierProfile.zero
        reflection.triggers.cleanseReflectDebuffToEnemy = true
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20),
            companion: owl.combatant, enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: reflection, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let hero = battle.hero
        let enemy = battle.enemy
        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            100, keyword: keyword, to: hero, sourceActorID: enemy.id,
            applyFightPacing: false, in: &battle,
        ) }
        #expect(battle.roster.hasPendingActionSkip(for: hero, keyword: keyword))
        let card = BattleCardCombatEngine.deal(.panaceaPotion, owner: .companion, context: &battle)

        let events = try battle.playCard(cardID: card.id).events

        #expect(!battle.roster.hasPendingActionSkip(for: hero, keyword: keyword))
        #expect(battle.roster.hasPendingActionSkip(for: enemy, keyword: keyword))
        #expect(events.contains { $0.effectKind == .controlTriggered && $0.targetID == enemy.id && $0.keyword == keyword })
        #expect(battle.health(of: enemy) == 100)
        let skipped = CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: enemy, context: &battle) }
        #expect(skipped.contains { $0.effectKind == .controlActionSkipped && $0.keyword == keyword })
        #expect(!battle.roster.hasPendingActionSkip(for: enemy, keyword: keyword))
    }
}

extension CleanseIntegrationTests {
    @Test(arguments: [0, 1, 2])
    func `reproving light rewards successful removal rather than debuff count`(removedCount: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["library_owl_cleanse_t3_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        for effect in [Effect.poison(2), .burn(2)].prefix(removedCount) {
            battle.appendEffect(effect, to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        }
        let before = battle.health(of: battle.enemy)
        let outcome = CombatExecutor.run { await EffectRemovalOperation.resolveCleanse(
            .all(nil), source: battle.companion, target: battle.hero, abilityName: "Cleanse", in: &battle,
        ) }
        #expect(before - battle.health(of: battle.enemy) == (removedCount > 0 ? 3 : 0))
        #expect(outcome.events.count { $0.kind == .abilityDamage && $0.abilityName == "Reproving Light" } == (removedCount > 0 ? 1 : 0))
        #expect(!battle.hasTalentDebuff(on: battle.hero))
    }

    @Test func `reproving light does not reopen Holy rewards or reward a nested Cleanse`() {
        var profile = CombatantTalentCatalog.profile(for: ["library_owl_cleanse_t3_1"])
        profile.triggers.holyDamageCleanseCount = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(companionModifiers: profile, dealOpeningHand: false)
        battle.appliesFightPacing = false
        for recipient in [battle.hero, battle.companion] {
            battle.appendEffect(.poison(2), to: recipient, sourceID: battle.enemy.id, remainingTurns: 0)
        }
        let before = battle.health(of: battle.enemy)
        let outcome = CombatExecutor.run { await EffectRemovalOperation.resolveCleanse(
            .all(nil), source: battle.companion, target: battle.hero, abilityName: "Cleanse", in: &battle,
        ) }
        #expect(before - battle.health(of: battle.enemy) == 3)
        #expect(outcome.events.count { $0.kind == .abilityDamage && $0.abilityName == "Reproving Light" } == 1)
        #expect(battle.hasTalentDebuff(on: battle.companion))
        let nested = CombatExecutor.run { await CombatTriggerEngine.withHeroReaction(in: &battle) { context in
            await EffectRemovalOperation.resolveCleanse(
                .all(nil), source: context.companion, target: context.companion,
                abilityName: "Nested Cleanse", in: &context,
            ).events
        } }
        #expect(!battle.hasTalentDebuff(on: battle.companion))
        #expect(nested.contains { $0.effectKind == .cleanseApplied })
        #expect(!nested.contains { $0.abilityName == "Reproving Light" })
        #expect(before - battle.health(of: battle.enemy) == 3)
    }

    @Test func `perfect purity requires removal and prevents debuffs without preventing damage`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["alchemist_cleanse_t4_1"]), dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        func cleanse(_ battle: inout BattleState) {
            _ = CombatExecutor.run { await EffectRemovalOperation.resolveCleanse(
                .all(nil), source: battle.companion, target: battle.hero, abilityName: "Cleanse", in: &battle,
            ) }
        }
        cleanse(&battle)
        #expect(!battle.roster.hero.talents.turn.negativeStatusImmune)
        battle.appendEffect(.poison(2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        cleanse(&battle)
        #expect(battle.roster.hero.talents.turn.negativeStatusImmune)
        let damage = battle.resolveTestDamage(3, from: .enemy, to: .hero, keyword: .poison, options: .reaction())
        #expect(damage.healthLost == 3)
        let prevented = battle.appendEffect(.poison(2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        #expect(!prevented)
        _ = CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        let reapplied = battle.appendEffect(.poison(2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        #expect(reapplied)
    }
}
