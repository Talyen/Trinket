import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct CleanseIntegrationTests {
    @Test(arguments: [Keyword.stun, .freeze])
    func `cleansing control lets an ally play newly drawn cards this turn`(keyword: Keyword) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroAbilities: [.slash], dealOpeningHand: false)
        battle.appendEffect(.controlMeter(keyword, 10, 10), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        _ = BattleCardCombatEngine.finalizeOpeningHand(context: &battle)
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
    func `reflective ward preserves removed effect`(cleanse: Effect, debuff: ActiveEffect) throws {
        let owl = try BattleTestFixtures.catalogBuild(combatantID: "library_owl", talents: "library_owl_cleanse_t3_1")
        var battle = BattleStateTestFactory.makeBattle(companion: owl.combatant, companionModifiers: owl.modifiers)
        var applied = debuff
        applied.sourceActorID = battle.enemy.id
        battle.roster.hero.activeEffects = [applied]
        battle.roster.companion.talents.pending.doubleStatusNextCard = true
        let isPrepared = battle.roster.companion.talents.pending.doubleStatusNextCard
        try #require(isPrepared)
        let handler = try #require(EffectHandlers.all[cleanse.kind])
        let enemyHealth = battle.roster.enemy.currentHealth

        _ = handler.apply(
            cleanse, ability: .panaceaPotion, source: battle.companion, target: battle.hero, in: &battle,
        )

        #expect(battle.roster.hero.activeEffects.isEmpty)
        let remainsPrepared = battle.roster.companion.talents.pending.doubleStatusNextCard
        #expect(remainsPrepared)
        let reflected = try #require(battle.roster.enemy.activeEffects.first { $0.effect.kind == debuff.effect.kind })
        #expect(reflected.effect == debuff.effect)
        #expect(reflected.remainingTurns == debuff.remainingTurns)
        #expect(reflected.sourceActorID == battle.companion.id)
        #expect(battle.roster.enemy.currentHealth == enemyHealth)
    }

    @Test(arguments: [false, true])
    func `mass cleanse heals the other cleansed ally`(primaryHasDebuff: Bool) throws {
        let owl = try BattleTestFixtures.catalogBuild(
            combatantID: "library_owl", talents: "library_owl_cleanse_t2_2", "library_owl_cleanse_t1_2",
        )
        let cleanse = Ability(id: "mass-cleanse", name: "Cleanse", tier: .basic, targetedEffects: [
            TargetedEffect(.cleanse(nil), target: .companion),
        ])
        var battle = BattleStateTestFactory.makeBattle(companion: owl.combatant, companionModifiers: owl.modifiers)
        battle.withEngineContext { context in
            context.appliesFightPacing = false
            context.roster.hero.currentHealth = 1
            context.roster.hero.activeEffects = [
                ActiveEffect(id: 90, effect: .poison(4), remainingTurns: 0, sourceActorID: context.enemy.id),
            ]
            if primaryHasDebuff {
                context.roster.companion.activeEffects = [
                    ActiveEffect(id: 91, effect: .burn(4), remainingTurns: 0, sourceActorID: context.enemy.id),
                ]
            }
        }
        battle.hand = BattleHand()
        _ = BattleCardCombatEngine.deal(cleanse, owner: .companion, context: &battle)
        _ = try BattleTestFixtures.playCardNamed("Cleanse", owner: .companion, on: &battle)
        try #expect(!battle.activeEffects(of: battle.hero).contains(where: \.effect.isRemovableDebuff))
        #expect(battle.health(of: battle.hero) == 3)
    }

    @Test func `panacea cleanses most debuffed and heals lowest as one action`() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.panaceaPotion],
        )
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTurns: 0),
                ActiveEffect(id: 3, effect: .shield(.block, 10), remainingTurns: 6),
            ],
        )
        battle.withEngineContext { context in
            context.appliesFightPacing = false
            context.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
            context.roster.mutateRuntime(for: companion) { $0.currentHealth = 11 }
        }

        let events = try #require(try BattleTestFixtures.playUntilAbility("Panacea Potion", on: &battle))
        try #expect(!(battle.activeEffects(of: battle.hero)).contains(where: \.effect.isRemovableDebuff))
        try #expect(events.first?.effectKind == .cleanseApplied)
        try #expect(battle.hasHeroEffect {
            if case .shield = $0 {
                return true
            }; return false
        })
        let heroHealth = battle.health(of: battle.hero)
        let companionHealth = battle.health(of: battle.companion)
        try #expect(heroHealth == 17, "hero health: \(heroHealth)")
        try #expect(companionHealth == 11, "companion health: \(companionHealth)")
        try #expect(events.count(where: { $0.effectKind == .instantHeal }) == 1)
    }

    @Test func `panacea cleanses most debuffed but heals lowest when split`() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.panaceaPotion],
        )
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTurns: 0),
            ],
        )
        battle.withEngineContext { context in
            context.appliesFightPacing = false
            context.roster.mutateRuntime(for: hero) { $0.currentHealth = 14 }
            context.roster.mutateRuntime(for: companion) { $0.currentHealth = 6 }
        }

        _ = try BattleTestFixtures.playUntilAbility("Panacea Potion", on: &battle)

        try #expect(!(battle.activeEffects(of: battle.hero)).contains(where: \.effect.isRemovableDebuff))
        try #expect(battle.health(of: battle.hero) == 14)
        try #expect(battle.health(of: battle.companion) == 13)
    }

    @Test func `panacea heals base amount when no debuffs present`() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.panaceaPotion],
        )
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
        )
        battle.withEngineContext { context in
            context.appliesFightPacing = false
            context.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
            context.roster.mutateRuntime(for: companion) { $0.currentHealth = 15 }
        }

        _ = try BattleTestFixtures.playUntilAbility("Panacea Potion", on: &battle)

        try #expect(battle.health(of: battle.hero) == 13)
        try #expect(battle.health(of: battle.companion) == 15)
    }

    @Test func `cleanse specific keyword removes matching debuffs on use`() throws {
        let cleansePoison = Ability(
            id: "cleanse-poison",
            name: "Cleanse Poison",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse Poisoned.",
            effects: [.cleanse(.poison)],
        )
        let hero = CombatantFixtures.combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20,
            abilities: [cleansePoison],
        )
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
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
            directDamage: 0,
            description: "Cleanse Stunned.",
            targetedEffects: [TargetedEffect(.cleanse(.stun))],
        )
        let hero = CombatantFixtures.combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            abilities: [cleanseAbility],
        )
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 5, 10), remainingTurns: 0),
            ],
        )

        _ = try BattleTestFixtures.playCardNamed("Test Cleanse", owner: .hero, on: &battle)

        try #expect(!battle.hasHeroEffect { $0.isControlMeter }, "Cleanse removed buildup")
    }

    @Test func `cleanse all debuffs triggers toxic backlash trait damage when curing poison`() throws {
        let cleanseAll = Ability(
            id: "cleanse-all",
            name: "Cleanse All",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse all debuffs.",
            effects: [.cleanse(nil)],
        )
        let hero = CombatantFixtures.combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 50,
            abilities: [cleanseAll],
        )
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var triggers = CombatTraitTriggers()
        triggers.onCleansePoisonDealDamagePerStack = 5
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
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

    @Test func `cleanse all applies party cleanse block once across mixed debuffs`() throws {
        let cleanseAll = Ability(
            id: "cleanse-all",
            name: "Cleanse All",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse all debuffs.",
            effects: [.cleanse(nil)],
        )
        let hero = CombatantFixtures.combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 50,
            abilities: [cleanseAll],
        )
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        let triggers = CombatTraitTriggers(cleanse: CleanseTriggers(cleansePartyBlock: 2))
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTurns: 0),
                ActiveEffect(id: 3, effect: .bleed(4), remainingTurns: 0),
            ],
            heroModifiers: CombatModifierProfile(triggers: triggers),
        )

        let events = try BattleTestFixtures.playCardNamed("Cleanse All", owner: .hero, on: &battle)

        try #expect(events.first?.effectKind == .cleanseApplied)
        try #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 2)
        try #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 2)
    }
}
