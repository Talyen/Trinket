import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension CombatSurvivalTests {
    @Test(arguments: [false, true])
    func `healing rewards stop when a triggered cleanse defeats the healer`(cleanSlate: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.cleanSlate = cleanSlate
        profile.triggers.onHealCleanseTargetChance = cleanSlate ? 0 : 1
        profile.triggers.cleanseHolyDamage = 3
        profile.triggers.onHealGrantBlock = 3
        profile.triggers.healOverTimeOnHealAmount = 2
        profile.triggers.healOverTimeOnHealTurns = 2
        profile.triggers.overhealConvertsToBlock = true
        profile.triggers.wishspring = true
        var battle = makeBattle(profile: profile, heroHealth: 19)
        battle.insertEffect(.poison(2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)

        let outcome = battle.resolveHeal(HealRequest(amount: 3, target: battle.hero, sourceActorID: battle.companion.id))

        #expect(!battle.roster.companion.isAlive)
        #expect(outcome.healthRestored == 1)
        #expect(battle.health(of: battle.hero) == 20)
        #expect(!battle.hasTalentDebuff(on: battle.hero))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == (cleanSlate ? 0 : 5))
        #expect(battle.roster.hero.currentMana == (cleanSlate ? 0 : 1))
        #expect(battle.roster.hero.talents.timed.lingeringBlessing == nil)
    }

    @Test func `stored healing from a defeated source preserves restoration and recipient overflow rewards`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.onHealGrantBlock = 3
        profile.triggers.wishspring = true
        var battle = makeBattle(profile: profile, heroHealth: 19, heroModifiers: .withTriggers { $0.overhealConvertsToBlock = true })
        battle.roster.companion.currentHealth = 0

        let outcome = battle.resolveHeal(HealRequest(
            amount: 3, target: battle.hero, sourceActorID: battle.companion.id, origin: .periodic,
        ))

        #expect(outcome.healthRestored == 1)
        #expect(battle.health(of: battle.hero) == 20)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 2)
        #expect(battle.roster.hero.currentMana == 0)
    }

    @Test(arguments: [Keyword.poison, .bleed])
    func `Shared Roots requires its Druid to survive Cleansing Dew`(keyword: Keyword) {
        var profile = CombatModifierProfile.zero
        profile.triggers.cleansingDew = true
        profile.triggers.cleanseHolyDamage = 3
        profile.triggers.sharedRootsHealPercent = 1
        var battle = makeBattle(profile: profile, heroHealth: 5)
        battle.insertEffect(keyword == .poison ? .poison(2) : .bleed(2), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 2)

        _ = battle.resolveHeal(HealRequest(amount: 1, target: battle.companion, sourceActorID: battle.companion.id))

        #expect(!battle.roster.companion.isAlive)
        #expect(battle.health(of: battle.hero) == 5)
    }

    @Test(arguments: [false, true])
    func `Cleansing Dew removes Poison and Bleed in one operation only after actual healing`(missingHealth: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: missingHealth ? 10 : 20,
            heroModifiers: .withTriggers {
                $0.cleansingDew = true
                $0.cleanseHolyDamage = 3
                $0.criticalChanceBonus = -1
            },
            appliesFightPacing: false,
        )
        for effect in [Effect.poison(2), .bleed(2), .burn(2)] {
            battle.insertEffect(effect, to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 2)
        }

        _ = battle.resolveHeal(HealRequest(amount: 1, target: battle.companion, sourceActorID: battle.hero.id))

        #expect(battle.roster.hasAffliction(.poison, on: battle.companion) == !missingHealth)
        #expect(battle.roster.hasAffliction(.bleed, on: battle.companion) == !missingHealth)
        #expect(battle.roster.hasAffliction(.burn, on: battle.companion))
        #expect(battle.health(of: battle.enemy) == (missingHealth ? 97 : 100))
    }

    @Test(arguments: [false, true])
    func `party card healing stops when its source falls during the first heal`(survives: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: survives ? 10 : 1, companionHealth: 5,
            heroModifiers: .withTriggers {
                $0.cardsPlayedHealPartyThreshold = 1
                $0.cardsPlayedHealPartyAmount = 2
                $0.onHealDealHoly = 3
                $0.criticalChanceBonus = -1
            },
            enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 4 },
            appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        battle.turnCadence.cardsPlayed[.hero] = 1
        DefensePoolEngine.set(6, on: battle.enemy, in: &battle)

        CombatExecutor.run { await CombatTriggerEngine.afterPartyCardPlayed(in: &battle) }

        #expect(battle.roster.hero.isAlive == survives)
        #expect(battle.health(of: battle.companion) == (survives ? 7 : 5))
    }

    private func makeBattle(
        profile: CombatModifierProfile,
        heroHealth: Int,
        heroModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        var companionProfile = profile
        companionProfile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20, maxMana: 5),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: heroHealth, companionHealth: 1, heroMana: 0,
            heroModifiers: heroModifiers, companionModifiers: companionProfile, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 2 },
            appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(6, on: battle.enemy, in: &battle)
        return battle
    }

    @Test(arguments: [false, true])
    func `Grizzly Guard rewards a surviving lethal hit but not a final defeat`(finallyDefeated: Bool) throws {
        let bear = try BattleTestFixtures.catalogBuild(combatantID: "bear", talents: "bear_block_t2_1")
        var battle = BattleStateTestFactory.makeBattle(
            companion: bear.combatant,
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: bear.modifiers,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        let hero = battle.hero
        battle.roster.mutateRuntime(for: hero) { $0.hasConsumedDeathsDoor = finallyDefeated }
        #expect(battle.roster.health(for: hero) * 2 >= battle.roster.maxHealth(for: hero))

        let hit = battle.recordingResult { context in context.resolveTestDamage(
            context.roster.maxHealth(for: hero) + 100,
            from: .enemy,
            to: .hero,
            options: .attack(accuracy: .unavoidable),
        ) }

        #expect(battle.roster.health(for: hero) == (finallyDefeated ? 0 : 1))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: hero)) == (finallyDefeated ? 0 : 6))
        #expect(hit.events.count(where: { $0.abilityName == "Grizzly Guard" }) == (finallyDefeated ? 0 : 1))
    }

    @Test(arguments: [false, true])
    func `Redline prepares the next Bleed after lethal survival but not a final defeat`(finallyDefeated: Bool) throws {
        let panther = try BattleTestFixtures.catalogBuild(combatantID: "panther", talents: "panther_bleed_t4_2")
        var battle = BattleStateTestFactory.makeBattle(
            companion: panther.combatant,
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: panther.modifiers,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        let companion = battle.companion
        battle.roster.mutateRuntime(for: companion) { $0.hasConsumedDeathsDoor = finallyDefeated }
        #expect(battle.roster.health(for: companion) * 2 >= battle.roster.maxHealth(for: companion))

        _ = battle.resolveTestDamage(
            battle.roster.maxHealth(for: companion) + 100,
            from: .enemy,
            to: .companion,
            options: .attack(accuracy: .unavoidable),
        )

        #expect(battle.roster.health(for: companion) == (finallyDefeated ? 0 : 1))
        #expect((battle.roster.companion.talents.pending.doubleNextBleedAttack != nil) == !finallyDefeated)
        if !finallyDefeated {
            let first = bleedAttack(from: companion, in: &battle)
            let second = bleedAttack(from: companion, in: &battle)

            #expect(first.healthLost == 20)
            #expect(second.healthLost == 10)
            #expect(battle.roster.companion.talents.pending.doubleNextBleedAttack == nil)
        }
    }

    private func bleedAttack(from source: Combatant, in battle: inout BattleState) -> CombatOutcome {
        battle.resolveTestDamage(
            10,
            to: battle.enemy,
            keyword: .bleed,
            sourceActorID: source.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
    }

    @Test(arguments: [false, true])
    func `Nullifying purges only when its Holy attacker survives Thorns`(lethal: Bool) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "nullifying"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        let buff = Effect.criticalChanceBonus(0.1, 2)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemyEffects: [
                ActiveEffect(id: 1, effect: .thorns(1), remainingTurns: 0),
                ActiveEffect(id: 2, effect: buff, remainingTurns: 2),
            ],
            heroHealth: lethal ? 1 : 2, heroModifiers: profile, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true

        let attack = battle.recordingResult { context in context.resolveTestDamage(
            1, keyword: .holy,
            options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) }

        #expect(attack.value.healthLost == 1)
        #expect(battle.health(of: battle.hero) == (lethal ? 0 : 1))
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == buff } == lethal)
        #expect(attack.events.contains { $0.effectKind == .purgeApplied } == !lethal)
    }

    @Test(arguments: [false, true])
    func `Leech preserves restoration feedback but stops rewards after lethal healing retaliation`(companionSource: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onHealDealHoly = 1
        profile.triggers.leechBlockChancePercent = 1
        profile.triggers.leechThornsWithoutThorns = 3
        profile.triggers.leechBlockBelowHalf = true
        profile.triggers.onLeechApplyPoison = 2
        profile.triggers.onLeechApplyBleed = 2
        profile.triggers.onLeechReduceEnemyStrength = 1
        profile.triggers.onLeechReduceEnemyStrengthTurns = 2
        profile.triggers.companionLeechSharePercent = 1
        profile.triggers.leechSharesToHeroPercent = 1
        profile.triggers.firstLeechRestorationShareAlly = true
        profile.triggers.onCompanionLeechRestoreHeroMana = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30, maxMana: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: companionSource ? 10 : 1,
            companionHealth: companionSource ? 1 : 10, heroMana: 0,
            heroModifiers: companionSource ? .zero : profile,
            companionModifiers: companionSource ? profile : .zero,
            enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 3 }, appliesFightPacing: false,
        )
        let source = companionSource ? battle.companion : battle.hero
        let ally = companionSource ? battle.hero : battle.companion
        battle.roster.mutateRuntime(for: source) { $0.hasConsumedDeathsDoor = true }
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)

        let result = battle.recordingResult { context in await HealingEngine.leechFromDamage(
            4, sourceActorID: source.id, target: context.enemy, abilityHasLeech: true, in: &context,
        ) }

        #expect(battle.health(of: source) == 0)
        #expect(battle.health(of: ally) == 10)
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(!battle.activeEffects(of: source).contains { $0.effect.kind == .thorns })
        #expect(result.value.healthRestored == 2)
        #expect(result.value.flags.contains(.leeched))
        #expect(result.events.contains { $0.effectKind == .leechHeal && $0.targetID == source.id && $0.amount == 2 })
        #expect(!result.events.contains { $0.effectKind == .thornsApplied })
        #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect.isRemovableDebuff })
    }

    @Test(arguments: ["Mana", "Gold", "Poison"])
    func `Leech followups stop at lethal Mana Gold and affliction reactions`(checkpoint: String) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30, maxMana: 10),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1, heroMana: 0,
            heroModifiers: .withTriggers {
                $0.criticalChanceBonus = -1
                $0.leechRestoreManaFlat = checkpoint == "Mana" ? 1 : 0
                $0.onGainManaHealFlat = checkpoint == "Mana" ? 1 : 0
                $0.leechGoldFlat = 1
                $0.leechGoldChancePercent = 1
                $0.gainGoldBonusHealSelf = checkpoint == "Gold" ? 1 : 0
                $0.onHealDealHoly = checkpoint == "Poison" ? 0 : 1
                $0.onLeechApplyPoison = 2
                $0.onLeechApplyBleed = 2
                $0.onLeechReduceEnemyStrength = 1
                $0.onLeechReduceEnemyStrengthTurns = 2
            }, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 2 }, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)

        CombatExecutor.run { await CombatTriggerEngine.afterLeech(by: battle.hero, target: battle.enemy, in: &battle) }

        #expect(battle.health(of: battle.hero) == 0)
        #expect(battle.gold == (checkpoint == "Mana" ? 0 : 1))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == (checkpoint == "Poison" ? 18 : 19))
        #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect.isRemovableDebuff })
    }

    private enum FirstShare: CaseIterable, Sendable {
        case symbiosis, companionShare, soulSharing
    }

    @Test(arguments: FirstShare.allCases)
    private func `lethal retaliation from a Leech share stops later shares and ally Mana`(firstShare: FirstShare) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30, maxMana: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10, companionHealth: 1, heroMana: 0,
            companionModifiers: .withTriggers {
                $0.criticalChanceBonus = -1
                $0.onHealDealHoly = 1
                $0.companionLeechSharePercent = firstShare == .symbiosis ? 1 : 0
                $0.leechSharesToHeroPercent = firstShare == .soulSharing ? 0 : 1
                $0.firstLeechRestorationShareAlly = true
                $0.onCompanionLeechRestoreHeroMana = 2
            }, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 3 }, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)

        let result = battle.recordingResult { context in await HealingEngine.leechFromDamage(
            8, sourceActorID: context.companion.id, target: context.enemy, abilityHasLeech: true, in: &context,
        ) }

        #expect(battle.health(of: battle.companion) == 0)
        #expect(battle.health(of: battle.hero) == 14)
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 18)
        #expect(result.value.healthRestored == 4)
        #expect(result.events.contains { $0.effectKind == .leechHeal && $0.amount == 4 })
    }
}
