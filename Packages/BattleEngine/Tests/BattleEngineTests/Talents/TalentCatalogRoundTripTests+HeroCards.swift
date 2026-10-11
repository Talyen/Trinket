import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test(arguments: ["wildcard_physical_t4_1", "rogue_gold_t4_1"], [Keyword.physical, .stun, .burn])
    func `theft prepares one attack bonus while Bounty Blade remains Physical only`(talentID: String, keyword: Keyword) {
        var profile = CombatantTalentCatalog.profile(for: [talentID])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 200, heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        for _ in 0 ..< 2 {
            _ = BattleTurnEngine.performAction(
                ability: .steal, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
            )
        }
        _ = battle.resolveDamage(.doTTick(amount: 1, target: battle.enemy, keyword: .burn, sourceActorID: battle.hero.id))
        let attack = Ability(
            id: "two-hit-theft-payoff", name: "Two Hit", tier: .basic,
            damageComponents: [DamageComponent(2, keyword: keyword), DamageComponent(2, keyword: keyword)],
        )
        let before = battle.health(of: battle.enemy)
        _ = BattleTurnEngine.performAction(
            ability: attack, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )

        let paidInFull = talentID == "wildcard_physical_t4_1"
        let expectedBonus = paidInFull ? 2 : (keyword == .physical ? 3 : 0)
        #expect(before - battle.health(of: battle.enemy) == 4 + expectedBonus)
        let after = battle.health(of: battle.enemy)
        _ = BattleTurnEngine.performAction(
            ability: .slash, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        let remainingBonus = !paidInFull && keyword != .physical ? 3 : 0
        #expect(after - battle.health(of: battle.enemy) == 3 + remainingBonus)
    }

    @Test func `grove accord rewards the pair once per turn`() throws {
        var battle = heroTalentBattle("druid_mana_t4_1")
        for _ in 0 ..< 2 {
            for owner in [BattleParticipant.hero, .companion, .hero, .companion] {
                try playHeroTalentCard(.kindling, owner: owner, in: &battle)
            }
            let expected = battle.turnCount + 1
            #expect(talentPoints(.thorns, on: .hero, in: battle) == expected)
            #expect(talentPoints(.thorns, on: .companion, in: battle) == expected)
            battle.turnCount += 1
            _ = CombatTriggerEngine.startHeroTalentTurn(in: &battle)
            battle.roster.hero.currentMana = 10
            battle.roster.companion.currentMana = 10
        }
    }

    @Test(arguments: [Ability.steal, .bountyShot, .blackjack, .tithe])
    func `authored theft cards preserve gilded claws through outcome resolution`(ability: Ability) throws {
        var battle = capstoneBattle(companion: ["lizard_scout_gold_t3_2"])
        var stolen = 0
        for _ in 0 ..< 8 {
            seedHeroTalentEffect(.controlMeter(.stun, 40, 40), on: .enemy, in: &battle)
            seedHeroTalentEffect(.marked(3, 6), on: .enemy, in: &battle)
            let events = try playHeroTalentCard(ability, owner: .companion, in: &battle)
            stolen = events.filter { $0.effectKind == .resourceGain && $0.keyword == .gold }.reduce(0) { $0 + $1.amount }
            if stolen > 0 {
                break
            }
        }
        #expect(stolen > 0)
        #expect(battle.heroTalents.history[battle.companion.id]?.stolenGoldDamage == stolen)
        ActiveEffectMutation.removeMatching(from: battle.enemy, in: &battle) { $0.kind == .marked }
        let next = try playHeroTalentCard(.stab, owner: .companion, in: &battle)
        let hit = try #require(next.first { $0.kind == .abilityDamage && $0.keyword == .physical })
        #expect(hit.amount == (2 + stolen) * (hit.isCritical ? 2 : 1))
    }

    @Test func `unstable culture rewards natural enemy poison expiry without accumulating multipliers`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["alchemist_poison_t3_2"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroModifiers: profile, dealOpeningHand: false)
        battle.appliesFightPacing = false
        for _ in 0 ..< 2 {
            seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle)
            _ = CombatExecutor.run { await EffectTurnEngine.advanceAll(context: &battle) }
        }
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 2)
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 3)
        let cleanseEnemy = Ability(id: "enemy-cleanse", name: "Cleanse Enemy", tier: .skill, targetedEffects: [
            TargetedEffect(.cleanse(.poison), target: .enemy),
        ])
        try playHeroTalentCard(cleanseEnemy, in: &battle)
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 1)
        ActiveEffectMutation.removeMatching(from: battle.enemy, in: &battle) { $0.kind == .poison }
        seedHeroTalentEffect(.poison(1), on: .hero, in: &battle)
        _ = CombatExecutor.run { await EffectTurnEngine.advanceAll(context: &battle) }
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 1)
    }
}
