import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct StunEquipmentOwnershipTests {
    @Test(arguments: [BattleParticipant?.none, .hero, .companion], [false, true])
    func `Knockout and Disrupting require the wearers Stun while Branding observes allies`(
        source: BattleParticipant?,
        purgeAll: Bool,
    ) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: .withTriggers {
                $0.stunDealPhysicalFlat = 3
                $0.enemyStunnedApplyMarked = true
                $0.enemyStunnedPurgeCount = purgeAll ? 0 : 1
                $0.enemyStunnedPurgeAll = purgeAll
            }, appliesFightPacing: false,
        )
        battle.insertEffect(.thorns(2), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        let sourceActorID = source.map { battle.roster[$0].id }

        _ = battle.chargeTestControl(
            ControlMeterEngine.threshold(for: battle.enemy, in: battle),
            keyword: .stun, to: battle.enemy, sourceActorID: sourceActorID, applyFightPacing: false,
        )

        #expect(battle.health(of: battle.enemy) == (source == .hero ? 97 : 100))
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == .thorns(2) } == (source != .hero))
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.kind == .marked && $0.sourceActorID == battle.hero.id })
    }

    @Test func `Knockout retaliation stops the defeated wearers remaining Stun reactions`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1, heroModifiers: .withTriggers {
                $0.stunDealPhysicalFlat = 3
                $0.enemyStunnedApplyMarked = true
                $0.enemyStunnedPurgeAll = true
            }, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 3 }, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)
        battle.insertEffect(.thorns(2), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)

        CombatExecutor.run { await CombatTriggerEngine.afterEnemyStunned(sourceActorID: battle.hero.id, in: &battle) }

        #expect(!battle.roster.hero.isAlive)
        #expect(battle.health(of: battle.enemy) == 100)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 17)
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == .thorns(2) })
        #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect.kind == .marked })
    }

    @Test func `Wardbreaker stops after a Purge reaction defeats its wearer`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1, heroModifiers: .withTriggers {
                $0.stunPurgeDealHolyPerEffect = 2
                $0.crownfall = true
            }, enemyModifiers: .withTriggers {
                $0.sealedSarcophagus = true
                $0.onBlockHitDealHoly = 3
            }, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)
        battle.insertEffect(.thorns(2), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)

        CombatExecutor.run { await CombatTriggerEngine.afterEnemyStunned(sourceActorID: battle.hero.id, in: &battle) }

        #expect(!battle.roster.hero.isAlive)
        #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect == .thorns(2) })
        // Crownfall's committed three damage resolves; Wardbreaker's later damage does not.
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 17)
    }
}
