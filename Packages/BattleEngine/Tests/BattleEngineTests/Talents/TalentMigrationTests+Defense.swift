import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension TalentMigrationTests {
    @Test func `storedImpact stores blocked and empowers next physical`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(block: BlockTriggers(storedImpact: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.hero.combatant,
            )
        }
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.hero.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.enemy.id,
                options: .reaction(),
            ))
        }
        let heroID = battle.hero.id
        let stored = battle.withEngineContext { $0.storedBlockedDamageByActorID[heroID] ?? 0 }
        #expect(stored > 0)
        let second = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(second.healthLost > 10)
    }

    @Test func `seismicReversal returns blocked as stun`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(block: BlockTriggers(seismicReversal: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 8), remainingTurns: 0)],
                for: ctx.roster.hero.combatant,
            )
        }
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.hero.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.enemy.id,
                options: .reaction(),
            ))
        }
        #expect(battle.health(of: battle.enemy) < enemyHealthBefore)
    }

    @Test func `sunwall grants companion block equal to holy health damage`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(block: BlockTriggers(sunwallChancePercent: 1)))
        battle.appliesFightPacing = false
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 9,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.holy,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(
                    tier: .skill, scaling: .statsAndItems, accuracy: .unavoidable,
                    abilityCriticalChanceBonus: -1,
                ),
            ))
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 0)
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 9)
    }

    @Test func `storedImpact cross-owner companion block empowers hero`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(block: BlockTriggers(storedImpact: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.companion.combatant,
            )
        }
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.companion.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.enemy.id,
                options: .reaction(),
            ))
        }
        let companionID = battle.companion.id
        let storedCompanion = battle.withEngineContext { $0.storedBlockedDamageByActorID[companionID] ?? 0 }
        #expect(storedCompanion > 0)
        let outcome = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(outcome.healthLost > 10)
        #expect(battle.withEngineContext { $0.storedBlockedDamageByActorID.isEmpty })
    }

    @Test func `stalwart oath grants 6 block on stun`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(block: BlockTriggers(onStunEnemyGainBlock: 6)))
        battle.appliesFightPacing = false
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 20,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.stun,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 6)
    }

    @Test func `gilded carapace grants 2 block on stun`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(block: BlockTriggers(onStunEnemyGainBlock: 2)))
        battle.appliesFightPacing = false
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 20,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.stun,
                sourceActorID: ctx.roster.companion.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 2)
    }

    @Test func `slip away dodges the first attack each combat`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(dodge: DodgeTriggers(dodgeFirstAttackEachCombat: true)))
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(battle.roster.activeEffects(for: battle.companion).contains {
            if case .evadeNextHit = $0.effect {
                return true
            }
            return false
        })
    }

    @Test func `golden guard grants block while carrying enough gold`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(block: BlockTriggers(blockWhileGoldThreshold: 10, blockWhileGoldAmount: 2)),
            initialGold: 10,
        )
        let events = CombatTriggerEngine.turnBlock(for: battle.hero, in: &battle)
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 2)
        #expect(events.contains(where: { $0.abilityName == "Golden Guard" }))

        var poor = makeBattle(
            heroTriggers: CombatTraitTriggers(block: BlockTriggers(blockWhileGoldThreshold: 10, blockWhileGoldAmount: 2)),
        )
        _ = CombatTriggerEngine.turnBlock(for: poor.hero, in: &poor)
        #expect(BattleTestFixtures.shieldPoints(for: poor.hero, in: poor) == 0)
    }

    @Test func `rimewind deals freeze damage on dodge`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(control: ControlTriggers(dodgeDealFreezeFlat: 2)))
        battle.appliesFightPacing = false
        let before = battle.health(of: battle.enemy)
        _ = CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant, attackerID: battle.roster.enemy.id, in: &battle,
        )
        #expect(before - battle.health(of: battle.enemy) == 2)
    }

    @Test func `vanish guarantees critical after dodge`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(dodge: DodgeTriggers(onDodgeNextAttackGuaranteedCritical: true)))
        _ = CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant, attackerID: battle.roster.enemy.id, in: &battle,
        )
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.talents.pending.guaranteedCriticalAfterDodge == true)
    }

    @Test func `scorched earth weakens burning attackers`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(mitigation: MitigationTriggers(burningEnemyDamageReductionFlat: 1)))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let outcome = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 5,
                target: ctx.roster.hero.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.enemy.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(outcome.healthLost == 4)
    }

    @Test func `plated hide grants block when hit`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(onHit: OnHitTriggers(onHitGainBlock: 2)))
        battle.appliesFightPacing = false
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 3,
                target: ctx.roster.companion.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.enemy.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 2)
    }

    @Test func `spiked shell grows thorns from retained block`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(block: BlockTriggers(retainedBlockGainThornsPercent: 0.5)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 8), remainingTurns: 0)],
                for: ctx.roster.companion.combatant,
            )
            _ = DefensePoolEngine.decayBlock(on: ctx.roster.companion.combatant, in: &ctx)
        }
        let thorns = battle.activeEffects(of: battle.companion).reduce(0) { sum, active in
            guard case let .thorns(stacks) = active.effect else { return sum }
            return sum + stacks
        }
        #expect(thorns == 2)
    }

    @Test func `enduring shell retains half block`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(block: BlockTriggers(blockRetainsHalf: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 50), remainingTurns: 0)],
                for: ctx.roster.companion.combatant,
            )
            _ = DefensePoolEngine.decayBlock(on: ctx.roster.companion.combatant, in: &ctx)
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 25)
    }
}
