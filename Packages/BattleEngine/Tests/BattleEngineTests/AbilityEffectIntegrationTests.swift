import BattleEngine
import Testing
import TrinketContent
import TrinketCore

/// Integration tests for catalog abilities that combine damage, effects, and resources.
struct AbilityEffectIntegrationTests {
    @Test func blackjackChoosesStunDamageOrGold() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.blackjack]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy, initialGold: 0)

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        let stoleGold = battle.gold == 2
        let dealtStun = battle.health(of: battle.enemy) < 100
        try #expect(stoleGold != dealtStun)
    }

    @Test func poisonEffectAppliesThroughTargetedEffects() throws {
        let poisonAbility = Ability(
            id: "legacy",
            name: "Legacy",
            tier: .basic,
            directDamage: 1,
            description: "Legacy",
            targetedEffects: [TargetedEffect(.poison(2))]
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [poisonAbility])
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(battle.activeEffects(of: battle.enemy).contains { $0.keyword == .poison })
    }

    @Test func bloodthornDealsComponentDamageAndAppliesDoTs() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.bloodthorn]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
        }

        _ = try #require(
            try BattleTestFixtures.playUntilAbility("Bloodthorn", on: &battle),
            "Expected Bloodthorn to resolve in battle"
        )

        // One randomly chosen typed hit (4 Bleed or 4 Poison) plus paired DoT.
        try #expect(battle.health(of: battle.enemy) == 95)
        let hasBleed = battle.hasEnemyEffect {
            if case .bleed = $0 {
                return true
            }
            return false
        }
        let hasPoison = battle.hasEnemyEffect {
            if case .poison = $0 {
                return true
            }
            return false
        }
        try #expect(hasBleed != hasPoison)
        try #expect(battle.health(of: battle.hero) == 13)
    }

    @Test func cleanseRandomRemovesOneDebuffAndHeals() throws {
        let mend = Ability(
            id: "mend",
            name: "Mend",
            tier: .skill,
            description: "Heal and cleanse a random debuff.",
            targetedEffects: [
                TargetedEffect(.instantHeal(.health, 2)),
                TargetedEffect(.cleanseRandom),
            ]
        )
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            abilities: [mend]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .poison(4), remainingTurns: 0),
            ]
        )

        // Let DoTs tick once so hero is damaged before Mend.
        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.hero) < 10)

        let events = try #require(
            try BattleTestFixtures.playUntilAbility("Mend", on: &battle),
            "Expected Mend to resolve in battle"
        )
        try #expect(events.contains { $0.effectKind == .instantHeal && $0.keyword == .health })
        try #expect(battle.activeEffects(of: battle.hero).filter(ActiveEffect.isDebuff).count == 1)
    }

    @Test func damageKeywordOverrideRewritesOutgoingDamageToHolyWithBonus() throws {
        let strike = Ability(
            id: "strike",
            name: "Strike",
            tier: .basic,
            directDamage: 2,
            damageKeyword: .physical,
            description: "Strike"
        )
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [strike]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .damageKeywordOverride(.holy, 3, 6), remainingTurns: 6),
            ]
        )

        let events = try #require(
            try BattleTestFixtures.playUntilAbility("Strike", on: &battle),
            "Expected Strike to resolve in battle"
        )
        let abilityEvent = try #require(events.first { $0.kind == .ability && $0.abilityName == "Strike" })
        try #expect(abilityEvent.keyword == .holy)
        try #expect(abilityEvent.amount >= 5)
        try #expect(battle.health(of: battle.enemy) <= 95)
    }

    @Test func avatarOfJusticeAppliesBuffPulsesHolyAndBlockThenExpires() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.avatarOfJustice]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)

        _ = try #require(
            try BattleTestFixtures.playUntilAbility("Avatar", on: &battle),
            "Expected Avatar to resolve in battle"
        )

        // The buff lives on the caster, not as a Holy DoT on the enemy.
        try #expect(battle.activeEffects(of: battle.hero).contains { active in
            if case .avatar(6, 4, 1) = active.effect {
                return active.remainingTurns == 1
            }
            return false
        })
        try #expect(!battle.activeEffects(of: battle.enemy).contains { active in
            if case .recurringDamage(.holy, _, _) = active.effect {
                return true
            }
            return false
        })
        #expect(CombatantBuffAura.kind(from: battle.activeEffects(of: battle.hero)) == .avatar)
        #expect(CombatantBuffAura.kind(from: battle.activeEffects(of: battle.enemy)) == nil)

        // First pulse on cast: Holy damage to the enemy plus Block for the caster.
        let healthAfterCast = battle.health(of: battle.enemy)
        try #expect(healthAfterCast < 100)
        let blockAfterCast = DefensePoolEngine.blockPoints(
            in: battle.activeEffects(of: battle.hero)
        )
        try #expect(blockAfterCast == 4)

        // Second pulse next round repeats the Holy damage AND the Block, then the buff expires.
        let endEvents = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.enemy) < healthAfterCast)
        try #expect(endEvents.contains {
            $0.effectKind == .shieldApplied && $0.targetID == hero.id && $0.amount == 4
        })
        try #expect(!battle.activeEffects(of: battle.hero).contains { active in
            if case .avatar = active.effect {
                return true
            }
            return false
        })
    }

    @Test func pounceDoublesStunOnlyOnTheOpeningTurn() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.pounce]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)
        try #expect(battle.turnCount == 0)

        let firstEvents = try BattleTestFixtures.playCardNamed("Pounce", owner: .hero, on: &battle)
        let firstHit = try #require(firstEvents.first { $0.kind == .ability && $0.abilityName == "Pounce" }?.amount)
        try #expect(firstHit == 6)

        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.turnCount == 1)
        let secondEvents = try #require(try BattleTestFixtures.playUntilAbility("Pounce", on: &battle))
        let secondHit = try #require(secondEvents.first { $0.kind == .ability && $0.abilityName == "Pounce" }?.amount)
        try #expect(secondHit == 3)
    }

    @Test func combustionDoublesOnlyWhenEnemyAlreadyBurning() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.combustion]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 100)

        var fresh = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)
        let freshEvents = try BattleTestFixtures.playCardNamed("Combustion", owner: .hero, on: &fresh)
        let freshHit = try #require(freshEvents.first { $0.kind == .ability && $0.abilityName == "Combustion" }?.amount)
        try #expect(freshHit == 4)
        try #expect(BattleTestFixtures.burnPotency(on: fresh) == 4)

        var burning = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .burn(2), remainingTurns: 0)]
        )
        let burningEvents = try BattleTestFixtures.playCardNamed("Combustion", owner: .hero, on: &burning)
        let burningHit = try #require(burningEvents.first { $0.kind == .ability && $0.abilityName == "Combustion" }?.amount)
        try #expect(burningHit == 8)
        try #expect(BattleTestFixtures.burnPotency(on: burning) == 10)
    }
}
