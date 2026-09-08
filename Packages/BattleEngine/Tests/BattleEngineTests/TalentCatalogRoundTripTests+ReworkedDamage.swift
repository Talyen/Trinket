import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `interdict extends purifying light without duplicating its purge`() throws {
        var battle = capstoneBattle(companion: ["library_owl_holy_t3_2", "library_owl_holy_t4_1"])
        seedHeroTalentEffect(.nextStrikeDouble, on: .enemy, in: &battle, source: .enemy)
        seedHeroTalentEffect(.nextStrikeCritical, on: .enemy, in: &battle, source: .enemy)
        let events = try playHeroTalentCard(.smite, owner: .companion, in: &battle)
        #expect(events.count { $0.effectKind == .purgeApplied } == 2)
        for effect in [Effect.nextStrikeDouble, .nextStrikeCritical] {
            seedHeroTalentEffect(effect, on: .enemy, in: &battle, source: .enemy)
            #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect == effect })
        }
        seedHeroTalentEffect(.thorns(3), on: .enemy, in: &battle, source: .enemy)
        #expect(talentPoints(.thorns, on: .enemy, in: battle) == 3)
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        seedHeroTalentEffect(.nextStrikeDouble, on: .enemy, in: &battle, source: .enemy)
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == .nextStrikeDouble })
    }

    @Test(arguments: [Effect.purge(nil), .purgeRandom])
    func `interdict blocks purged block but permits healing and resource gains`(effect: Effect) throws {
        var battle = capstoneBattle(companion: ["library_owl_holy_t4_1"])
        seedHeroTalentEffect(.shield(.block, 6), on: .enemy, in: &battle, source: .enemy)
        let purge = Ability(id: "purge-block", name: "Purge", tier: .skill, targetedEffects: [TargetedEffect(effect, target: .enemy)])
        try playHeroTalentCard(purge, owner: .companion, in: &battle)
        #expect(battle.applyBlock(7, to: battle.enemy, source: battle.enemy, abilityName: "Block").isEmpty)
        #expect(DefensePoolEngine.add(7, to: battle.enemy, in: &battle) == 0)
        battle.roster.enemy.currentHealth = 100
        let healed = battle.resolveHeal(HealRequest(amount: 3, target: battle.enemy, sourceActorID: battle.enemy.id))
        #expect(healed.healthRestored == 3)
        let gold = battle.gold
        _ = battle.grantGoldEvent(2, to: battle.companion, abilityName: "Gold")
        #expect(battle.gold == gold + 2)
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(DefensePoolEngine.add(7, to: battle.enemy, in: &battle) == 7)
    }

    @Test func `redline follows detonation while rend flesh still extends undetonated bleed`() throws {
        var battle = capstoneBattle(companion: ["panther_bleed_t2_2", "panther_bleed_t4_1", "panther_bleed_t4_2"])
        seedHeroTalentEffect(.bleed(2), on: .enemy, in: &battle, source: .companion)
        let originalTurns = try #require(battle.activeEffects(of: battle.enemy).first { $0.effect.isBleed }?.remainingTurns)
        seedHeroTalentEffect(.nextStrikeCritical, on: .companion, in: &battle)
        try playHeroTalentCard(.smite, owner: .companion, in: &battle)
        #expect(battle.activeEffects(of: battle.enemy).first { $0.effect.isBleed }?.remainingTurns == originalTurns * 2)
        seedHeroTalentEffect(.nextStrikeCritical, on: .companion, in: &battle)
        let detonating = try playHeroTalentCard(.slash, owner: .companion, in: &battle)
        #expect(!detonating.contains { $0.kind == .abilityDamage && $0.keyword == .bleed })
        #expect(talentPoints(.bleed, on: .enemy, in: battle) == 0)
        let next = try playHeroTalentCard(.slash, owner: .companion, in: &battle)
        #expect(next.count { $0.kind == .abilityDamage && $0.keyword == .bleed } == 1)
        #expect(talentPoints(.bleed, on: .enemy, in: battle) == 2)
    }

    @Test func `subzero mist protects the recovery attack and expires at party turn start`() {
        var battle = capstoneBattle(companion: ["mana_moth_freeze_t2_2"])
        let threshold = ControlMeterEngine.threshold(for: battle.enemy, in: battle)
        seedHeroTalentEffect(.controlMeter(.freeze, threshold, threshold), on: .enemy, in: &battle)
        _ = BattleCardCombatEngine.resolveEnemyTurn(context: &battle)
        #expect(!battle.roster.companion.subzeroMistActive)
        _ = BattleCardCombatEngine.resolveEnemyTurn(context: &battle)
        #expect(battle.roster.companion.subzeroMistActive)
        #expect(abs(DamagePipeline.dodgeChance(for: battle.companion, attackerID: battle.enemy.id, in: battle) - 0.30) < 0.0001)
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(DamagePipeline.dodgeChance(for: battle.companion, attackerID: battle.enemy.id, in: battle) == 0.10)
    }

    @Test func `flash freeze empowers repeated freeze cards at the normal mana cost`() throws {
        var battle = capstoneBattle(companion: ["mana_moth_freeze_t3_1"])
        for remainingMana in [7, 4] {
            let events = try playHeroTalentCard(.frostbolt, owner: .companion, in: &battle)
            let hit = try #require(events.first { $0.kind == .abilityDamage && $0.keyword == .freeze })
            #expect(hit.amount == (hit.isCritical ? 12 : 6))
            #expect(battle.roster.companion.currentMana == remainingMana)
        }
    }

    @Test func `flash freeze increases only freeze for every repeated empowerment`() {
        var battle = capstoneBattle(companion: ["mana_moth_freeze_t3_1"])
        battle.roster.companion.currentMana = 9
        var ability = Ability(
            id: "mixed-empowerment", name: "Mixed", tier: .skill,
            damageComponents: [DamageComponent(2, keyword: .burn), DamageComponent(3, keyword: .freeze)],
            repeatsManaEmpowerment: true,
        )
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(for: &ability, actor: battle.companion, context: &battle)
        #expect(ability.damageComponents.map(\.amount) == [5, 12])
        #expect(battle.roster.companion.currentMana == 0)
    }

    @Test func `gilded claws banks actual theft without scaling from carried gold`() throws {
        var battle = capstoneBattle(companion: ["lizard_scout_gold_t3_2", "lizard_scout_gold_t4_1"])
        battle.gold = 10000
        try playHeroTalentCard(.goldenPlate, owner: .companion, in: &battle)
        let plain = try playHeroTalentCard(.stab, owner: .companion, in: &battle)
        let plainHit = try #require(plain.first { $0.kind == .abilityDamage })
        #expect(plainHit.amount == (plainHit.isCritical ? 4 : 2))
        try playHeroTalentCard(.steal, owner: .companion, in: &battle)
        for _ in 0 ..< 7 {
            _ = battle.resolveDamage(.doTTick(amount: 1, target: battle.enemy, keyword: .poison, sourceActorID: battle.companion.id))
        }
        let next = try playHeroTalentCard(.stab, owner: .companion, in: &battle)
        let nextHit = try #require(next.first { $0.kind == .abilityDamage })
        #expect(nextHit.amount == (nextHit.isCritical ? 22 : 11))
        let spent = try playHeroTalentCard(.stab, owner: .companion, in: &battle)
        let spentHit = try #require(spent.first { $0.kind == .abilityDamage })
        #expect(spentHit.amount == (spentHit.isCritical ? 4 : 2))
    }

    @Test func `blinding light reduces one whole attack and leaves damage over time unchanged`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 40,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(dodge: DodgeTriggers(dodgeChanceBonus: -1))),
            companionModifiers: CombatantTalentCatalog.profile(for: ["library_owl_holy_t2_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let holy = try playHeroTalentCard(.smite, owner: .companion, in: &battle)
        let holyHit = try #require(holy.first { $0.kind == .abilityDamage })
        let reduction = CombatRounding.scaled(holyHit.amount, multiplier: 0.5)
        let dot = battle.resolveDamage(.doTTick(amount: 2, target: battle.hero, keyword: .burn, sourceActorID: battle.enemy.id))
        #expect(dot.healthLost == 2)
        let attack = Ability(id: "two-hits", name: "Two Hits", tier: .basic, damageComponents: [DamageComponent(4), DamageComponent(4)])
        for expected in [8 - reduction, 8] {
            let before = battle.roster.hero.currentHealth
            _ = BattleTurnEngine.performAction(ability: attack, actor: battle.enemy, abilityTarget: battle.hero, context: &battle)
            #expect(before - battle.roster.hero.currentHealth == expected)
        }
    }

    @Test func `serrated blades ticks existing bleeds without shortening or refilling poison`() {
        var battle = capstoneBattle(hero: ["rogue_bleed_t1_1", "rogue_poison_t2_1", "rogue_bleed_t2_2"])
        battle.appendEffect(.bleed(2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 10)
        battle.appendEffect(.bleed(3), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 4)
        seedHeroTalentEffect(.poison(6), on: .enemy, in: &battle)
        let health = battle.roster.enemy.currentHealth
        _ = DoTApplicator.applyBleed(
            potency: 1, to: battle.enemy, sourceActorID: battle.hero.id,
            dealImmediateDamage: false, in: &battle,
        )
        #expect(health - battle.roster.enemy.currentHealth == 10)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 1)
        let durations = battle.activeEffects(of: battle.enemy).filter(\.effect.isBleed).map(\.remainingTurns)
        #expect(durations == [10, 4, Effect.bleedDoTTurnCount])
        _ = DoTApplicator.applyBleed(
            potency: 1, to: battle.enemy, sourceActorID: battle.hero.id,
            dealImmediateDamage: false, in: &battle,
        )
        #expect(health - battle.roster.enemy.currentHealth == 17)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 0)
        #expect(battle.gold == 0)
    }

    @Test(arguments: [false, true])
    func `blood money rewards only the lethal hit including consumed bleed`(detonates: Bool) {
        var battle = capstoneBattle(hero: ["rogue_bleed_t2_2"])
        battle.roster.enemy.currentHealth = 6
        battle.appendEffect(.bleed(2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 3)
        _ = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.hero.id, options: .flatReaction,
        ))
        #expect(battle.gold == 0)
        if detonates {
            _ = CombatTriggerEngine.detonateBleed(on: battle.enemy, sourceActorID: battle.hero.id, in: &battle)
        } else {
            _ = battle.resolveDamage(DamageRequest(
                amount: 4, target: battle.enemy, keyword: .physical,
                sourceActorID: battle.hero.id, options: .flatReaction,
            ))
        }
        #expect(battle.roster.enemy.currentHealth == 0)
        #expect(battle.gold == 5)
        _ = battle.resolveDamage(.doTTick(
            amount: 4, target: battle.enemy, keyword: .bleed, sourceActorID: battle.hero.id,
        ))
        #expect(battle.gold == 5)
    }

    @Test(arguments: [false, true])
    func `blood money requires bleeding and the talent owner to defeat the enemy`(companionKill: Bool) {
        var battle = capstoneBattle(hero: ["rogue_bleed_t2_2"])
        if companionKill {
            seedHeroTalentEffect(.bleed(2), on: .enemy, in: &battle)
        }
        _ = battle.resolveDamage(DamageRequest(
            amount: 200, target: battle.enemy, keyword: .physical,
            sourceActorID: companionKill ? battle.companion.id : battle.hero.id, options: .flatReaction,
        ))
        #expect(battle.gold == 0)
    }

    @Test(arguments: [false, true])
    func `noxious reaction consumes the live poison pool in either tick order`(poisonFirst: Bool) {
        var battle = capstoneBattle(hero: ["rogue_poison_t2_1"])
        let effects: [Effect] = poisonFirst ? [.poison(6), .bleed(4)] : [.bleed(4), .poison(6)]
        for effect in effects {
            battle.appendEffect(effect, to: battle.enemy, sourceID: battle.hero.id, remainingTurns: effect.isBleed ? 2 : 0)
        }
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.enemy.currentHealth == (poisonFirst ? 187 : 191))
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 1)
        #expect(battle.activeEffects(of: battle.enemy).first { $0.effect.isBleed }?.remainingTurns == 1)
    }
}
