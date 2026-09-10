import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct HealingReductionTests {
    @Test(arguments: [0, 1])
    func `blood link applies hero healing reduction before transferring excess`(missingHealth: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 40, companionMaxHealth: 40,
            heroMaxMana: 3,
            heroModifiers: CombatantTalentCatalog.profile(for: ["warlock_leech_t2_1", "warlock_leech_t2_2"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentMana = 0
        battle.roster.hero.currentHealth -= missingHealth
        battle.roster.companion.currentHealth = 1
        battle.appendEffect(.healingReductionPercent(0.5, 3), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 3)
        let outcome = HealingEngine.leechFromDamage(
            16, sourceActorID: battle.hero.id, target: battle.enemy,
            abilityHasLeech: true, damageKeyword: .physical, in: &battle,
        )
        #expect(outcome.flags.contains(.leeched))
        #expect(battle.roster.hero.currentMana == 1)
        #expect(battle.roster.hero.currentHealth == 40)
        #expect(battle.roster.companion.currentHealth == 1 + 4 - missingHealth)
    }

    @Test func `healing logging cannot change leech rules or randomness`() {
        var silent = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
            heroHealth: 10,
            heroModifiers: .init(triggers: CombatTraitTriggers(damage: DamageTriggers(criticalChanceBonus: 0.5))),
        )
        var visible = silent
        let silentResult = silent.resolveHeal(HealRequest(
            amount: 5, target: silent.hero, sourceActorID: silent.hero.id, origin: .leech,
        ))
        let visibleResult = visible.resolveHeal(HealRequest(
            amount: 5, target: visible.hero, sourceActorID: visible.hero.id, origin: .leech,
            logAs: .instantHeal(actorName: visible.hero.name, abilityName: "Leech", keyword: .health),
        ))
        #expect(silentResult.healthRestored == visibleResult.healthRestored)
        #expect(silentResult.isCritical == visibleResult.isCritical)
        for owner in [BattleParticipant.hero, .companion, .enemy] {
            #expect(silent.roster[owner] == visible.roster[owner])
        }
        #expect(silent.rng.next() == visible.rng.next())
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `enemy serrated edge reduces only the afflicted ally healing`(recipient: BattleParticipant) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(abilities: [.serratedEdge]),
        )
        battle.appliesFightPacing = false
        let target = battle.roster[recipient].combatant
        _ = BattleTurnEngine.performAction(
            ability: .serratedEdge, actor: battle.enemy, abilityTarget: target, context: &battle,
        )

        for ally in [battle.hero, battle.companion] {
            battle.roster.mutateRuntime(for: ally) { $0.currentHealth = 10 }
            let outcome = battle.resolveHeal(HealRequest(
                amount: 8, target: ally, sourceActorID: ally.id, logAs: .silent,
            ))
            #expect(outcome.healthRestored == (ally.id == target.id ? 6 : 8))
        }
    }

    @Test func `serrated edge reduces enemy healing`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.serratedEdge]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: battle.roster.enemy.combatant) { $0.currentHealth = 10 }
        _ = BattleTurnEngine.performAction(
            ability: .serratedEdge,
            actor: battle.roster.hero.combatant,
            abilityTarget: battle.roster.enemy.combatant,
            context: &battle,
        )
        let outcome = battle.resolveHeal(
            HealRequest(
                amount: 8,
                target: battle.roster.enemy.combatant,
                sourceActorID: battle.roster.enemy.id,
                logAs: .silent,
                skipFightPacing: true,
            ),
        )
        #expect(outcome.healthRestored == 6)
        #expect(battle.roster.health(for: battle.roster.enemy.combatant) == 14)
    }

    @Test func `serrated edge leaves ally healing alone`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.serratedEdge]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 10 }
        _ = BattleTurnEngine.performAction(
            ability: .serratedEdge,
            actor: battle.roster.hero.combatant,
            abilityTarget: battle.roster.enemy.combatant,
            context: &battle,
        )
        let outcome = battle.resolveHeal(
            HealRequest(
                amount: 8,
                target: battle.roster.hero.combatant,
                sourceActorID: battle.roster.hero.id,
                logAs: .silent,
                skipFightPacing: true,
            ),
        )
        #expect(outcome.healthRestored == 8)
    }

    @Test func `healing triggered block uses the healers outgoing bonus`() {
        var battle = BattleStateTestFactory.makeBattle(
            heroModifiers: CombatModifierProfile(blockGainedBonus: 7),
            companionModifiers: CombatModifierProfile(
                blockGainedBonus: 3,
                triggers: CombatTraitTriggers(healing: HealingTriggers(onHealGrantBlock: 2)),
            ),
        )
        battle.appliesFightPacing = false
        let hero = battle.roster.hero.combatant
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 1 }

        let outcome = battle.resolveHeal(HealRequest(amount: 1, target: hero, sourceActorID: battle.roster.companion.id))

        let block = outcome.events.first { $0.effectKind == .shieldApplied }
        #expect(block?.amount == 5)
        #expect(block?.actorName == battle.roster.companion.name)
    }

    @Test func `healing triggered cleanse rewards the healer`() {
        var battle = BattleStateTestFactory.makeBattle(
            companionModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                healing: HealingTriggers(cleanseBonusHeal: 3, onHealCleanseTargetChance: 1),
            )),
        )
        battle.appliesFightPacing = false
        let hero = battle.roster.hero.combatant
        let companion = battle.roster.companion.combatant
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 1 }
        battle.roster.mutateRuntime(for: companion) { $0.currentHealth = 1 }
        battle.appendEffect(.poison(3), to: hero, sourceID: battle.roster.enemy.id, remainingTurns: 0)

        let outcome = battle.resolveHeal(HealRequest(amount: 1, target: hero, sourceActorID: companion.id))

        #expect(battle.roster.hero.currentHealth == 5)
        #expect(!battle.roster.activeEffects(for: hero).contains { $0.effect.isRemovableDebuff })
        #expect(outcome.events.first { $0.effectKind == .cleanseApplied }?.actorName == companion.name)
    }
}
