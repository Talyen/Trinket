import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentMigrationTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `stored impact converts either allies blocked damage into the next hero attack`(recipient: BattleParticipant) {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers { $0.storedImpact = true })
        let target = battle.roster[recipient].combatant
        battle.roster.setActiveEffects([ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)], for: target)
        _ = battle.resolveTestDamage(10, from: .enemy, to: recipient, options: .reaction())
        #expect(battle.roster[recipient].talents.battle.storedBlockedDamage > 0)
        let outcome = battle.resolveTestDamage(10)
        #expect(outcome.healthLost > 10)
        if recipient == .companion {
            #expect(BattleParticipant.party.allSatisfy { battle.roster[$0].talents.battle.storedBlockedDamage == 0 })
        }
    }

    @Test(arguments: [(BattleParticipant.hero, 6), (.companion, 2)])
    func `stun block rewards go to their talent owner`(owner: BattleParticipant, amount: Int) {
        let triggers = CombatTraitTriggers { $0.onStunEnemyGainBlock = amount }
        var battle = makeBattle(
            heroTriggers: owner == .hero ? triggers : .init(),
            companionTriggers: owner == .companion ? triggers : .init(),
        )
        battle.appliesFightPacing = false
        _ = battle.resolveTestDamage(20, from: owner, keyword: .stun)
        if owner == .hero {
            #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.roster[owner].combatant, in: battle) == amount)
    }

    @Test func `slip away dodges the first attack each combat`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers { $0.dodgeFirstAttackEachCombat = true })
        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(battle.activeEffects(of: battle.companion).contains { $0.effect == .evadeNextHit })
    }

    @Test(arguments: [0, 10])
    func `golden guard grants block while carrying enough gold`(gold: Int) {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers {
                $0.blockWhileGoldThreshold = 10
                $0.blockWhileGoldAmount = 2
            },
            initialGold: gold,
        )
        let events = battle.recordingEvents { battle in await CombatTriggerEngine.turnBlock(for: battle.hero, in: &battle) }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == (gold == 10 ? 2 : 0))
        if gold == 10 {
            #expect(events.contains { $0.abilityName == "Golden Guard" })
        }
    }

    @Test func `vanish guarantees critical after dodge`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers { $0.onDodgeNextAttackGuaranteedCritical = true })
        CombatExecutor.run { await CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant, attackerID: battle.roster.enemy.id, in: &battle,
        ) }
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.talents.pending.guaranteedCriticalAfterDodge == true)
    }

    @Test func `scorched earth weakens burning attackers`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers { $0.burningEnemyDamageReductionFlat = 1 })
        battle.appliesFightPacing = false
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
        )
        let outcome = battle.resolveTestDamage(5, from: .enemy, to: .hero)
        #expect(outcome.healthLost == 4)
    }

    @Test func `plated hide grants block when hit`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers { $0.onHitGainBlock = 2 })
        battle.appliesFightPacing = false
        _ = battle.resolveTestDamage(3, from: .enemy, to: .companion)
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 2)
    }

    @Test(arguments: [
        (CombatTraitTriggers { $0.retainedBlockGainThornsPercent = 0.5 }, 8, true, 2),
        (CombatTraitTriggers { $0.blockRetainsHalf = true }, 50, false, 25),
    ])
    func `companion block decay honors retention and thorns talents`(
        triggers: CombatTraitTriggers, initialBlock: Int, checksThorns: Bool, expected: Int,
    ) {
        var battle = makeBattle(companionTriggers: triggers)
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, initialBlock), remainingTurns: 0)],
            for: battle.companion,
        )
        DefensePoolEngine.decayBlock(on: battle.companion, in: &battle)
        let amount = checksThorns ? battle.activeEffects(of: battle.companion).reduce(0) { sum, active in
            guard case let .thorns(stacks) = active.effect else { return sum }
            return sum + stacks
        } : BattleTestFixtures.shieldPoints(for: battle.companion, in: battle)
        #expect(amount == expected)
    }
}
