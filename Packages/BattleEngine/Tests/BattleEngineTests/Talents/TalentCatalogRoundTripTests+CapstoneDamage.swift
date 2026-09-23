import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test(arguments: [("warlock_leech_t4_1", Keyword.burn)])
    func `elemental leech works on ticks without doubling existing leech`(talent: String, keyword: Keyword) {
        var battle = capstoneBattle(companion: [talent])
        battle.roster.companion.currentHealth = 1
        var alreadyLeeches = battle
        var options = DamageOperation.periodic
        options.abilityHasLeech = true
        let normal = battle.resolveDamage(.doTTick(
            amount: 8, target: battle.enemy, keyword: keyword, sourceActorID: battle.companion.id,
        ))
        _ = alreadyLeeches.resolveDamage(DamageRequest(
            amount: 8, target: alreadyLeeches.enemy, keyword: keyword,
            sourceActorID: alreadyLeeches.companion.id, options: options,
        ))
        #expect(normal.healthLost == 8)
        #expect(battle.roster.companion.currentHealth > 1)
        #expect(battle.roster.companion.currentHealth == alreadyLeeches.roster.companion.currentHealth)
        let health = battle.roster.companion.currentHealth
        _ = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: .holy,
            sourceActorID: battle.companion.id, options: .reaction(),
        ))
        #expect(battle.roster.companion.currentHealth == health)
    }

    @Test func `killing grace uses current dodge chance and respects critical cap`() {
        var battle = capstoneBattle(companion: ["panther_dodge_t4_1", "panther_dodge_t2_1"])
        let healthy = CriticalChanceEngine.chance(actorID: battle.companion.id, defender: battle.enemy, in: battle)
        #expect(abs(healthy - 0.15) < 0.0001)
        battle.roster.companion.currentHealth = 1
        let injured = CriticalChanceEngine.chance(actorID: battle.companion.id, defender: battle.enemy, in: battle)
        #expect(abs(injured - 0.25) < 0.0001)
        seedHeroTalentEffect(.criticalChanceBonus(1, 2), on: .companion, in: &battle)
        #expect(CriticalChanceEngine.chance(actorID: battle.companion.id, defender: battle.enemy, in: battle) == 0.75)
    }

    @Test func `ghostfrost deals health damage and builds freeze without consuming block`() {
        var battle = capstoneBattle(companion: ["mana_moth_freeze_t4_1"])
        seedHeroTalentEffect(.shield(.block, 10), on: .enemy, in: &battle)
        let result = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.enemy, keyword: .freeze,
            sourceActorID: battle.companion.id, options: .reaction(),
        ))
        #expect(result.healthLost == 4)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 10)
        #expect(battle.roster.enemy.activeEffects.contains {
            if case let .controlMeter(.freeze, amount, _) = $0.effect {
                return amount == 4
            }
            return false
        })
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

    @Test func `interdict prevents purged avatar from dealing damage or granting block`() throws {
        var battle = capstoneBattle(companion: ["library_owl_holy_t4_1"])
        let avatar = Effect.avatar(holyDamage: 6, blockPerTurn: 4, turns: 1)
        seedHeroTalentEffect(avatar, on: .enemy, in: &battle, source: .enemy)
        let purge = Ability(id: "purge-avatar", name: "Purge", tier: .skill, targetedEffects: [TargetedEffect(.purge(nil), target: .enemy)])
        try playHeroTalentCard(purge, owner: .companion, in: &battle)
        let heroHealth = battle.roster.hero.currentHealth
        let companionHealth = battle.roster.companion.currentHealth
        let blocked = EffectHandlersTestSupport.dispatch(
            avatar, ability: .avatarOfJustice, source: battle.enemy, target: battle.enemy, battle: &battle,
        )
        #expect(!blocked.didApply)
        #expect(blocked.events.isEmpty)
        #expect(battle.roster.hero.currentHealth == heroHealth)
        #expect(battle.roster.companion.currentHealth == companionHealth)
        #expect(battle.activeEffects(of: battle.enemy).isEmpty)
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        let applied = EffectHandlersTestSupport.dispatch(
            avatar, ability: .avatarOfJustice, source: battle.enemy, target: battle.enemy, battle: &battle,
        )
        #expect(applied.didApply)
        #expect(applied.events.contains { $0.effectKind == .avatarApplied })
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.kind == .avatar })
        #expect(battle.roster.hero.currentHealth < heroHealth || battle.roster.companion.currentHealth < companionHealth)
    }

    @Test func `gilded claws banks actual theft without scaling from carried gold`() throws {
        var battle = capstoneBattle(companion: ["lizard_scout_gold_t3_2"])
        battle.gold = 10000
        _ = battle.grantGoldEvent(3, to: battle.companion, abilityName: "Steal", isTheft: true)
        let next = try playHeroTalentCard(.stab, owner: .companion, in: &battle)
        let nextHit = try #require(next.first { $0.kind == .abilityDamage })
        #expect(nextHit.amount == (nextHit.isCritical ? 10 : 5))
        let spent = try playHeroTalentCard(.stab, owner: .companion, in: &battle)
        let spentHit = try #require(spent.first { $0.kind == .abilityDamage })
        #expect(spentHit.amount == (spentHit.isCritical ? 4 : 2))
    }

    @Test func `blinding light reserves one attack miss roll and leaves damage over time unchanged`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 40,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(dodge: DodgeTriggers(dodgeChanceBonus: -1))),
            companionModifiers: CombatantTalentCatalog.profile(for: ["library_owl_holy_t2_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        try playHeroTalentCard(.smite, owner: .companion, in: &battle)
        #expect(battle.roster.enemy.talents.pending.nextAttackMissChance == 0.20)
        let dot = battle.resolveDamage(.doTTick(amount: 2, target: battle.hero, keyword: .burn, sourceActorID: battle.enemy.id))
        #expect(dot.healthLost == 2)
        #expect(battle.roster.enemy.talents.pending.nextAttackMissChance == 0.20)
        battle.roster.enemy.talents.pending.nextAttackMissChance = 1
        let attack = Ability(id: "two-hits", name: "Two Hits", tier: .basic, damageComponents: [DamageComponent(4), DamageComponent(4)])
        let avoided = CombatTriggerEngine.enemyAttackAvoidance(in: &battle)
        #expect(avoided.cancelled)
        let before = battle.roster.hero.currentHealth
        _ = BattleTurnEngine.performAction(ability: attack, actor: battle.enemy, abilityTarget: battle.hero, context: &battle)
        #expect(before - battle.roster.hero.currentHealth == 8)
        #expect(battle.roster.enemy.talents.pending.nextAttackMissChance == 0)
    }

    @Test(arguments: [false, true])
    func `blood money rewards only the lethal hit including consumed bleed`(detonates: Bool) {
        var battle = capstoneBattle(hero: ["rogue_bleed_t2_2"])
        battle.roster.enemy.currentHealth = 6
        battle.appendEffect(.bleed(2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 3)
        _ = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.hero.id, options: .reaction(),
        ))
        #expect(battle.gold == 0)
        if detonates {
            _ = CombatTriggerEngine.detonateBleed(on: battle.enemy, sourceActorID: battle.hero.id, in: &battle)
        } else {
            _ = battle.resolveDamage(DamageRequest(
                amount: 4, target: battle.enemy, keyword: .physical,
                sourceActorID: battle.hero.id, options: .reaction(),
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
            sourceActorID: companionKill ? battle.companion.id : battle.hero.id, options: .reaction(),
        ))
        #expect(battle.gold == 0)
    }
}
