import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct AbilityEffectIntegrationTests {
    @Test func blackjackChoosesStunDamageOrGold() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.blackjack]
        )
        let companion = BattleTestFixtures.passiveCompanion()
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
        let companion = BattleTestFixtures.passiveCompanion()
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(battle.activeEffects(of: battle.enemy).contains { $0.keyword == .poison })
    }

    @Test func doTComponentDoesNotLandWhenDamageComponentDefeatsTarget() throws {
        let lethal = Ability(
            id: "lethal",
            name: "Lethal Cut",
            tier: .basic,
            directDamage: 100,
            description: "Lethal",
            targetedEffects: [TargetedEffect(.bleed(3))]
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [lethal])
        let companion = BattleTestFixtures.passiveCompanion()
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.enemy) <= 0)
        try #expect(!battle.activeEffects(of: battle.enemy).contains(where: \.effect.isBleed))
    }

    @Test func bloodthornDealsComponentDamageAndAppliesDoTs() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.bloodthorn]
        )
        let companion = BattleTestFixtures.passiveCompanion()
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
        }

        _ = try #require(
            try BattleTestFixtures.playUntilAbility("Bloodthorn", on: &battle),
            "Expected Bloodthorn to resolve in battle"
        )

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
        let companion = BattleTestFixtures.passiveCompanion()
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
        let companion = BattleTestFixtures.passiveCompanion()
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
        let companion = BattleTestFixtures.passiveCompanion()
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)

        _ = try #require(
            try BattleTestFixtures.playUntilAbility("Avatar", on: &battle),
            "Expected Avatar to resolve in battle"
        )

        try #expect(avatarRemainingTurns(on: battle.hero, in: battle) == 2)
        try #expect(!battle.activeEffects(of: battle.enemy).contains {
            if case .recurringDamage(.holy, _, _) = $0.effect {
                return true
            }
            return false
        })
        #expect(CombatantBuffAura.kind(from: battle.activeEffects(of: battle.hero)) == .avatar)
        #expect(CombatantBuffAura.kind(from: battle.activeEffects(of: battle.enemy)) == nil)

        let healthAfterCast = battle.health(of: battle.enemy)
        try #expect(healthAfterCast < 100)
        try #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 4)

        let firstEndEvents = BattleTestFixtures.endTurn(on: &battle)
        let healthAfterFirstRound = battle.health(of: battle.enemy)
        try #expect(healthAfterFirstRound < healthAfterCast)
        try #expect(avatarPulsedBlock(firstEndEvents, casterID: hero.id))
        try #expect(avatarRemainingTurns(on: battle.hero, in: battle) == 1)

        let secondEndEvents = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.enemy) < healthAfterFirstRound)
        try #expect(avatarPulsedBlock(secondEndEvents, casterID: hero.id))
        try #expect(avatarRemainingTurns(on: battle.hero, in: battle) == nil)
    }

    @Test func pounceDoublesStunOnlyOnTheOpeningTurn() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.pounce]
        )
        let companion = BattleTestFixtures.passiveCompanion()
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
        let companion = BattleTestFixtures.passiveCompanion()
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

    @Test func hemorrhageAppliesDebuffToEnemyAndDamagesEnemyWhenItAttacks() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.hemorrhage]
        )
        let companion = BattleTestFixtures.passiveCompanion()
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [.slash]
        )
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)

        _ = try BattleTestFixtures.playCardNamed("Hemorrhage", owner: .hero, on: &battle)

        try #expect(battle.hasEnemyEffect {
            if case .hemorrhage = $0 {
                return true
            }
            return false
        })
        try #expect(!battle.hasHeroEffect {
            if case .hemorrhage = $0 {
                return true
            }
            if case .onHitDamage = $0 {
                return true
            }
            return false
        })
        try #expect(!battle.activeEffects(of: battle.companion).contains {
            if case .hemorrhage = $0.effect {
                return true
            }
            if case .onHitDamage = $0.effect {
                return true
            }
            return false
        })

        let enemyHealthBefore = battle.health(of: battle.enemy)

        let enemyTurnEvents = BattleTestFixtures.endTurn(on: &battle)

        try #expect(enemyTurnEvents.contains { $0.effectKind == .hemorrhageTriggered && $0.amount == 4 })
        try #expect(battle.health(of: battle.enemy) == enemyHealthBefore - 8)

        try #expect(!battle.hasEnemyEffect {
            if case .hemorrhage = $0 {
                return true
            }
            return false
        })
    }

    @Test func hemorrhageDamagesEnemyWhenItPerformsNonDamagingAction() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.hemorrhage]
        )
        let companion = BattleTestFixtures.passiveCompanion()
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [.block]
        )
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)

        _ = try BattleTestFixtures.playCardNamed("Hemorrhage", owner: .hero, on: &battle)

        try #expect(battle.hasEnemyEffect {
            if case .hemorrhage = $0 {
                return true
            }
            return false
        })

        let enemyHealthBefore = battle.health(of: battle.enemy)

        let enemyTurnEvents = BattleTestFixtures.endTurn(on: &battle)

        try #expect(enemyTurnEvents.contains { $0.effectKind == .hemorrhageTriggered && $0.amount == 4 })
        let healthLost = enemyHealthBefore - battle.health(of: battle.enemy)
        try #expect(healthLost == 5)

        try #expect(!battle.hasEnemyEffect {
            if case .hemorrhage = $0 {
                return true
            }
            return false
        })
    }
}

private func avatarRemainingTurns(on combatant: Combatant, in battle: BattleState) -> Int? {
    battle.activeEffects(of: combatant).compactMap { active -> Int? in
        if case .avatar(6, 4, 2) = active.effect {
            return active.remainingTurns
        }
        return nil
    }.first
}

private func avatarPulsedBlock(_ events: [ActionEvent], casterID: String) -> Bool {
    events.contains {
        $0.effectKind == .shieldApplied && $0.targetID == casterID && $0.amount == 4
    }
}
