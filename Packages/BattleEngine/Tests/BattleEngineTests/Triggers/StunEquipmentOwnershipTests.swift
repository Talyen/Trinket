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
        var profile = CombatModifierProfile.zero
        profile.triggers.stunDealPhysicalFlat = 3
        profile.triggers.enemyStunnedApplyMarked = true
        profile.triggers.enemyStunnedPurgeCount = purgeAll ? 0 : 1
        profile.triggers.enemyStunnedPurgeAll = purgeAll
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile, appliesFightPacing: false,
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
        var profile = CombatModifierProfile.zero
        profile.triggers.stunDealPhysicalFlat = 3
        profile.triggers.enemyStunnedApplyMarked = true
        profile.triggers.enemyStunnedPurgeAll = true
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.onBlockHitDealHoly = 3
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1, heroModifiers: profile, enemyModifiers: enemyProfile, appliesFightPacing: false,
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
        var profile = CombatModifierProfile.zero
        profile.triggers.stunPurgeDealHolyPerEffect = 2
        profile.triggers.crownfall = true
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.sealedSarcophagus = true
        enemyProfile.triggers.onBlockHitDealHoly = 3
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1, heroModifiers: profile, enemyModifiers: enemyProfile, appliesFightPacing: false,
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
