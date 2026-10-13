import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentMigrationTests {
    @Test func `shatterpoint doubles the next bleed damage after stun`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.shatterpoint = true })
        battle.roster.setActiveEffects([ActiveEffect(id: 1, effect: .bleed(6), remainingTurns: 2)], for: battle.roster.enemy.combatant)
        _ = CombatExecutor.run { await CombatTriggerEngine.afterEnemyStunned(sourceActorID: battle.roster.hero.id, in: &battle) }
        let first = battle.resolveTestDamage(4, keyword: .bleed, options: .reaction())
        let second = battle.resolveTestDamage(4, keyword: .bleed, options: .reaction())
        #expect(first.healthLost == 8)
        #expect(second.healthLost == 4)
    }

    @Test(arguments: [(true, BattleParticipant.enemy), (false, .enemy), (true, .hero)])
    func `cryostasis preserves frozen enemy bleed only when equipped`(equipped: Bool, target: BattleParticipant) {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.cryostasis = equipped })
        let combatant = battle.roster[target].combatant
        battle.roster.setActiveEffects([
            ActiveEffect(id: 1, effect: .controlMeter(Keyword.freeze, 100, 10), remainingTurns: 0),
            ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
        ], for: combatant)
        let outcome = EffectHandlersTestSupport.dispatchTick(
            ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1), target: combatant, battle: &battle,
        )
        let preserved = equipped && target == .enemy
        #expect((outcome.currentEffect?.remainingTurns ?? 0) == (preserved ? 1 : 0))
        #expect((outcome.currentEffect != nil) == preserved)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `crownfall purge deals holy from either living party owner`(owner: BattleParticipant) {
        let triggers = CombatTraitTriggers.configured { $0.crownfall = true }
        var battle = makeBattle(
            heroTriggers: owner == .hero ? triggers : .init(),
            companionTriggers: owner == .companion ? triggers : .init(),
        )
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)], for: battle.enemy,
        )
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = EffectHandlersTestSupport.dispatch(
            .purge(nil),
            ability: Ability(id: "test-purge", name: "purge", tier: .basic, targetedEffects: [TargetedEffect(.purge(nil))]),
            target: battle.enemy, battle: &battle,
        )
        #expect(battle.health(of: battle.enemy) < enemyHealthBefore)
    }

    @Test func `crownfall does not damage when enemy purges ally buff`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.crownfall = true })
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
            for: battle.roster.hero.combatant,
        )
        let heroHealthBefore = battle.health(of: battle.hero)
        _ = EffectHandlersTestSupport.dispatch(
            .purge(nil),
            ability: Ability(id: "test-enemy-purge", name: "enemy-purge", tier: .basic, targetedEffects: [TargetedEffect(.purge(nil))]),
            source: battle.roster.enemy.combatant,
            battle: &battle,
        )
        #expect(battle.health(of: battle.hero) == heroHealthBefore)
    }

    @Test func `searing bind extends stun against burning enemies`() {
        for burning in [false, true] {
            var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.stunExtendVsBurning = true })
            battle.appliesFightPacing = false
            if burning {
                battle.roster.setActiveEffects(
                    [ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)],
                    for: battle.roster.enemy.combatant,
                )
            }
            _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
                20, keyword: .stun, to: battle.roster.enemy.combatant,
                sourceActorID: battle.roster.hero.id, applyFightPacing: false, in: &battle,
            ) }
            #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
            _ = CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: battle.enemy, context: &battle) }
            #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .stun) == burning)
            if burning {
                _ = CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: battle.enemy, context: &battle) }
                #expect(!battle.roster.hasPendingActionSkip(for: battle.enemy))
            }
        }
    }

    @Test func `blizzard triggers at three cards without refreezing on later cards`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.freezeCardsPlayedThisTurnFreezeAll = 3 })
        let card = Ability(id: "freeze", name: "Freeze", tier: .basic, directDamage: 1, damageKeyword: .freeze)
        for _ in 0 ..< 3 {
            _ = cardReactions(card, in: &battle)
        }
        #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .freeze))
        battle.roster.setActiveEffects([], for: battle.enemy)
        _ = cardReactions(card, in: &battle)
        #expect(!battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .freeze))
    }
}
