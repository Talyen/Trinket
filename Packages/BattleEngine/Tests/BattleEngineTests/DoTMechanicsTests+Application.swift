import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension DoTMechanicsTests {
    @Test(arguments: [Keyword.burn, .poison], [0, 2, 6])
    func `attack stacks equal health damage for both sides`(keyword: Keyword, block: Int) throws {
        for enemyAttacks in [false, true] {
            let profile = CombatModifierProfile(
                damageDealtBonus: [keyword: 2],
                triggers: CombatTraitTriggers(
                    damage: DamageTriggers(criticalChanceBonus: -1), dodge: DodgeTriggers(dodgeChanceBonus: -1),
                ),
            )
            var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, enemyModifiers: profile)
            battle.appliesFightPacing = false
            let actor = enemyAttacks ? battle.enemy : battle.hero
            let target = enemyAttacks ? battle.hero : battle.enemy
            DefensePoolEngine.set(block, on: target, in: &battle)
            let ability = Ability(id: "dot-hit", name: "DoT Hit", tier: .basic, directDamage: 4, damageKeyword: keyword)
            let before = battle.health(of: target)

            _ = BattleTurnEngine.performAction(ability: ability, actor: actor, abilityTarget: target, context: &battle)

            let expected = 6 - block
            #expect(before - battle.health(of: target) == expected)
            let active = battle.activeEffects(of: target).first { $0.keyword == keyword }
            #expect(active?.effect.potency ?? 0 == expected)
            if let active {
                let handler = try #require(EffectHandlers.all[active.effect.kind])
                let tickBefore = battle.health(of: target)
                _ = handler.advanceTurn(active, on: target, in: &battle)
                #expect(tickBefore - battle.health(of: target) == active.effect.potencyAfterTurn())
            }
        }
    }

    @Test(arguments: [Keyword.burn, .poison], [0, 6])
    func `damaging effects and reactions attach only health damage`(keyword: Keyword, block: Int) {
        for application in [DoTApplication.ability, .reaction] {
            var battle = BattleTestFixtures.makePipelineContext(heroModifiers: .init(damageDealtBonus: [keyword: 2]))
            battle.appliesFightPacing = false
            let target = battle.enemy
            DefensePoolEngine.set(block, on: target, in: &battle)
            let before = battle.health(of: target)

            _ = DoTApplicator.applyDecayingDoT(
                keyword: keyword, potency: 4, to: target, sourceActorID: battle.hero.id,
                application: application, in: &battle,
            )

            #expect(before - battle.health(of: target) == 6 - block)
            #expect(battle.activeEffects(of: target).first { $0.keyword == keyword }?.effect.potency ?? 0 == 6 - block)
        }
    }

    @Test(arguments: [Keyword.burn, .poison])
    func `critical scaled hits store final damage and ticks still respect defenses`(keyword: Keyword) throws {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(damageDealtBonus: [keyword: 2], outgoingDamagePercent: 0.5),
            enemyModifiers: .init(damageTakenFlat: [keyword: 1]),
        )
        battle.appliesFightPacing = false
        let target = battle.enemy
        battle.appendEffect(.nextStrikeCritical, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        let ability = Ability(id: "critical-dot", name: "Critical DoT", tier: .skill, directDamage: 4, damageKeyword: keyword)
        _ = BattleTurnEngine.performAction(ability: ability, actor: battle.hero, abilityTarget: target, context: &battle)
        let active = try #require(battle.activeEffects(of: target).first { $0.keyword == keyword })
        #expect(active.effect.potency == 14)
        DefensePoolEngine.set(2, on: target, in: &battle)
        let before = battle.health(of: target)
        let handler = try #require(EffectHandlers.all[active.effect.kind])

        _ = handler.advanceTurn(active, on: target, in: &battle)

        #expect(before - battle.health(of: target) == active.effect.potencyAfterTurn() - 1 - 2)
        #expect(battle.activeEffects(of: target).first { $0.keyword == keyword }?.effect.potency == active.effect.potencyAfterTurn())
    }

    @Test(arguments: [Keyword.burn, .poison])
    func `repeated attacks cannot attach stacks through block or dodge`(keyword: Keyword) {
        for dodged in [false, true] {
            var battle = BattleTestFixtures.makePipelineContext()
            battle.appliesFightPacing = false
            let target = battle.hero
            if dodged {
                battle.appendEffect(.evadeNextHit, to: target, sourceID: target.id, remainingTurns: 0)
            } else {
                DefensePoolEngine.set(20, on: target, in: &battle)
            }
            let request = DamageRequest(amount: 4, target: target, keyword: keyword, sourceActorID: battle.enemy.id)

            _ = UniqueCombatEngine.repeatHit(request, actor: battle.enemy, name: "Repeat", attachDoT: true, in: &battle)

            #expect(!battle.activeEffects(of: target).contains { $0.keyword == keyword })
        }
    }

    @Test(arguments: [Keyword.burn, .poison])
    func `detonation consumes stored potency without outgoing bonuses`(keyword: Keyword) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(damageDealtBonus: [keyword: 4], outgoingDamagePercent: 1),
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.decayingDoT(keyword: keyword, potency: 6), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        let before = battle.health(of: battle.enemy)

        _ = EffectHandlersTestSupport.dispatch(
            .detonateDoT(keyword, 1), source: battle.hero, target: battle.enemy, battle: &battle,
        )

        #expect(before - battle.health(of: battle.enemy) == (keyword == .burn ? 4 : 15))
        #expect(!battle.roster.hasAffliction(keyword, on: battle.enemy))
    }

    @Test func `combustion detonates fresh health damage without counting bonuses twice`() {
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: .init(
            damageDealtBonus: [.burn: 2], triggers: CombatTraitTriggers(damage: DamageTriggers(criticalChanceBonus: -1)),
        ))
        battle.appliesFightPacing = false
        let before = battle.health(of: battle.enemy)

        _ = BattleTurnEngine.performAction(ability: .combustion, actor: battle.hero, abilityTarget: battle.enemy, context: &battle)

        #expect(before - battle.health(of: battle.enemy) == 15)
        #expect(!battle.roster.hasAffliction(.burn, on: battle.enemy))
    }
}
