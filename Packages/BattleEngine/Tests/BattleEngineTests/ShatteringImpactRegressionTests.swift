import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ShatteringImpactRegressionTests {
    @Test(arguments: [
        (BattleParticipant.enemy, BattleParticipant.hero, true),
        (.enemy, .companion, true),
        (.hero, .enemy, true),
        (.enemy, .enemy, false),
        (.hero, .companion, false),
    ])
    func `Shattering Impact damages only an opponent after breaking their Block`(
        attacker: BattleParticipant,
        defender: BattleParticipant,
        triggersImpact: Bool,
    ) throws {
        let trait = try #require(GameContent.trait(id: "shattering_impact"))
        var profile = CombatModifierProfile.zero
        trait.apply(to: &profile)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20),
            heroModifiers: profile, companionModifiers: profile, enemyModifiers: profile, appliesFightPacing: false,
        )
        let target = battle.roster[defender].combatant
        DefensePoolEngine.set(2, on: target, in: &battle)

        _ = battle.resolveTestDamage(
            2, from: attacker, to: defender,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )

        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: target)) == 0)
        #expect(battle.health(of: target) == (triggersImpact ? 19 : 20))
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Shattering Impact damages the attacked recipient when it breaks borrowed Block`(
        recipient: BattleParticipant,
    ) throws {
        let trait = try #require(GameContent.trait(id: "shattering_impact"))
        var attackerProfile = CombatModifierProfile.zero
        trait.apply(to: &attackerProfile)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20),
            heroModifiers: .withTriggers { $0.blockAbsorbsCompanionDamage = true },
            companionModifiers: .withTriggers { $0.companionBlockAbsorbsHeroDamage = true },
            enemyModifiers: attackerProfile, appliesFightPacing: false,
        )
        let owner: BattleParticipant = recipient == .hero ? .companion : .hero
        let protector = battle.roster[owner].combatant
        let target = battle.roster[recipient].combatant
        DefensePoolEngine.set(2, on: protector, in: &battle)

        _ = battle.resolveTestDamage(
            2, from: .enemy, to: recipient,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )

        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: protector)) == 0)
        #expect(battle.health(of: target) == 19)
        #expect(battle.health(of: protector) == 20)
    }

    @Test func `committed Shattering Impact survives lethal Block reflection`() throws {
        let trait = try #require(GameContent.trait(id: "shattering_impact"))
        var profile = CombatModifierProfile.zero
        trait.apply(to: &profile)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20),
            heroHealth: 1, heroModifiers: profile, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 3 }, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(2, on: battle.enemy, in: &battle)

        _ = battle.resolveTestDamage(
            2, from: .hero, to: .enemy,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )

        #expect(battle.health(of: battle.hero) == 0)
        #expect(battle.health(of: battle.enemy) == 19)
    }
}
