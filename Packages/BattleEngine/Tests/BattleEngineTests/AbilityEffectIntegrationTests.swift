import BattleEngine
import Testing
import TrinketContent
import TrinketCore

/// Integration tests for catalog abilities that combine damage, effects, and resources.
struct AbilityEffectIntegrationTests {
    @Test func blackjackGrantsGoldAlongsideStunDamage() throws {
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

        try #expect(battle.gold == 1)
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

        // Two typed damage components (2 bleed, 2 poison) resolve
        // before any end-of-round DoT tick. Leech was removed from Bloodthorn.
        try #expect(battle.health(of: battle.enemy) == 96)
        try #expect(battle.hasEnemyEffect {
            if case .bleed = $0 {
                return true
            }; return false
        })
        try #expect(battle.hasEnemyEffect {
            if case .poison = $0 {
                return true
            }; return false
        })
        try #expect(battle.health(of: battle.hero) == 10)
        try #expect(!battle.hasHeroEffect {
            if case .leech = $0 {
                return true
            }; return false
        })
    }

    @Test func prayerCleanseRandomRemovesOneDebuffAndHeals() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            abilities: [.prayer]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .poison(4), remainingTicks: 0)
            ]
        )

        // Let DoTs tick once so hero is damaged before Prayer.
        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.hero) < 10)

        let events = try #require(
            try BattleTestFixtures.playUntilAbility("Prayer", on: &battle),
            "Expected Prayer to resolve in battle"
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
                ActiveEffect(id: 1, effect: .damageKeywordOverride(.holy, 3, 6), remainingTicks: 6)
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

    @Test func avatarOfJusticeAppliesManifestDefensiveEffects() throws {
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

        let events = try #require(
            try BattleTestFixtures.playUntilAbility("Avatar of Justice", on: &battle),
            "Expected Avatar of Justice to resolve in battle"
        )

        try #expect(battle.activeEffects(of: battle.hero).contains { active in
            if case .damageKeywordOverride(.holy, 3, 6) = active.effect {
                return true
            }
            return false
        })
        try #expect(events.contains { $0.effectKind == .shieldApplied && $0.amount == 7 })
        try #expect(events.contains { $0.effectKind == .damageKeywordOverrideApplied && $0.amount == 3 })
    }
}
