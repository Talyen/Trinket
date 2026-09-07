import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct HealingReductionTests {
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
