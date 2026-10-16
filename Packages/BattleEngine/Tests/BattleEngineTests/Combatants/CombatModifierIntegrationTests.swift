import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CombatModifierIntegrationTests {
    @Test(arguments: [0.0, 0.25, 1.0])
    func `shredding ignores only its share of mitigation`(ignored: Double) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            heroModifiers: .withTriggers { $0.ignoreEnemyMitigationPercent = ignored },
            enemyModifiers: .init(incomingDamageReductionPercent: 0.8), appliesFightPacing: false,
        )
        let outcome = battle.resolveTestDamage(100, options: .reaction())
        #expect(outcome.healthLost == CombatRounding.scaled(100, multiplier: 1 - 0.8 * (1 - ignored)))
    }

    @Test(arguments: [(4, 0.0, 0), (4, 0.5, 0), (14, 0.5, 9), (4, 1.0, 4)])
    func `shredding scales flat defenses before clamping damage`(damage: Int, ignored: Double, expected: Int) {
        var attacker = CombatModifierProfile.zero
        attacker.triggers.ignoreEnemyMitigationPercent = ignored
        var passive = CombatModifierProfile.zero
        passive.triggers.passiveMitigationFlat = 10
        for defender in [CombatModifierProfile(damageTakenFlat: [.physical: 10]), passive] {
            var battle = BattleStateTestFactory.makeMinimalBattle(
                enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
                heroModifiers: attacker,
                enemyModifiers: defender, appliesFightPacing: false,
            )
            let outcome = battle.resolveTestDamage(damage, options: .reaction())
            #expect(outcome.healthLost == expected)
        }
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `beastbond strengthens companion from either wearer`(owner: BattleParticipant) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "beastbond"))
        let item = try ItemFixtures.makeBareItem("ruby_ring", affixes: [affix.resolved(for: .basic)])
        let hero = CombatantFixtures.passiveHero()
        let companion = CombatantFixtures.passiveCompanion()
        let build = CombatBuildResolver.build(
            combatant: owner == .hero ? hero : companion,
            equipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.accessory: item.id]),
            inventory: [item],
        )
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: hero, companion: companion,
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            heroModifiers: owner == .hero ? build.modifiers : .zero,
            companionModifiers: owner == .companion ? build.modifiers : .zero, appliesFightPacing: false,
        )
        let outcome = battle.resolveTestDamage(
            10,
            to: battle.enemy,
            keyword: .physical,
            sourceActorID: companion.id,
            options: DamageOperation.effect(scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
        #expect(outcome.healthLost == 11)
    }

    @Test func `leech armor pierce bypasses mitigation only for leech abilities`() {
        func makeBattle(leechPierce: Bool) -> BattleState {
            BattleStateTestFactory.makeMinimalBattle(
                enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
                heroModifiers: .withTriggers { $0.leechIgnoresMitigation = leechPierce },
                enemyModifiers: .init(incomingDamageReductionPercent: 0.8), appliesFightPacing: false,
            )
        }
        func dealDamage(leechAbility: Bool, in battle: inout BattleState) -> Int {
            var options: DamageOperation = .reaction()
            options.abilityHasLeech = leechAbility
            return battle.resolveTestDamage(100, options: options).healthLost
        }
        var bypass = makeBattle(leechPierce: true)
        #expect(dealDamage(leechAbility: true, in: &bypass) == 100)
        var noLeechFlag = makeBattle(leechPierce: true)
        #expect(dealDamage(leechAbility: false, in: &noLeechFlag) == CombatRounding.scaled(100, multiplier: 0.2))
        var noTrigger = makeBattle(leechPierce: false)
        #expect(dealDamage(leechAbility: true, in: &noTrigger) == CombatRounding.scaled(100, multiplier: 0.2))
    }

    @Test func `outermost damage drains every out-of-turn queue`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200), appliesFightPacing: false,
        )
        battle.uniques.pendingCounterAttackActorIDs = [battle.hero.id]
        battle.uniques.pendingBlockAnswerOwners = [.hero]
        _ = battle.resolveTestDamage(10, options: .reaction())
        #expect(battle.uniques.pendingCounterAttackActorIDs.isEmpty)
        #expect(battle.uniques.pendingBlockAnswerOwners.isEmpty)
        #expect(battle.uniques.isDrainingOutOfTurnAttacks == false)
    }
}
