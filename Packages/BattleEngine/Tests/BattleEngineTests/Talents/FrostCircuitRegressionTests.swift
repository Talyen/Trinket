import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct FrostCircuitRegressionTests {
    @Test(arguments: [false, true], [false, true])
    func `Freeze Critical Hits restore Mana once for cards and Knights Answer even when blocked`(
        counterattack: Bool,
        blocked: Bool,
    ) throws {
        let fixtures = UniqueCollectionTests()
        let basic = Ability(id: "freeze-basic", name: "Freeze Basic", tier: .basic, directDamage: 4, damageKeyword: .freeze)
        let profile = CombatantTalentCatalog.profile(for: ["wizard_mana_t4_1"])
        var battle = try fixtures.battle(
            counterattack ? ["the_knights_answer"] : [], extra: profile, heroBasic: basic,
        )
        if blocked {
            DefensePoolEngine.set(100, on: battle.enemy, in: &battle)
        }
        battle.insertEffect(.nextStrikeCritical, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        let events: [ActionEvent]
        if counterattack {
            fixtures.block(10, owner: .hero, in: &battle)
            events = battle.recordingResult { context in fixtures.enemyHit(1, in: &context) }.events
        } else {
            events = try fixtures.play(basic, in: &battle)
        }
        #expect(events.contains { $0.kind == .abilityDamage && $0.keyword == .freeze && $0.isCritical })
        #expect(battle.roster.hero.currentMana == 1)
        #expect(events.count { $0.abilityName == "Frost Circuit" && $0.effectKind == .resourceGain } == 1)
        #expect(battle.roster.enemy.currentHealth == (blocked ? 2000 : 1992))
    }

    @Test(arguments: [false, true])
    func `critical Freeze effects and periodic damage do not restore Frost Circuit Mana`(periodic: Bool) throws {
        var battle = try UniqueCollectionTests().battle(
            [], extra: CombatantTalentCatalog.profile(for: ["wizard_mana_t4_1"]),
        )
        var operation: DamageOperation = periodic ? .periodic : .effect()
        operation.guaranteedCritical = true
        let outcome = battle.recordingResult { context in context.resolveTestDamage(2, keyword: .freeze, options: operation) }
        #expect(outcome.value.flags.contains(.critical))
        #expect(battle.roster.hero.currentMana == 0)
        #expect(!outcome.events.contains { $0.abilityName == "Frost Circuit" })
    }

    @Test func `Ray of Frost restores Mana for each Critical Hit`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wizard_mana_t4_1"])
        profile.triggers.guaranteedCritWhileOnDeathsDoor = true
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.rayOfFrost], enemyMaxHealth: 100,
            heroMaxMana: 10, heroMana: 0, heroModifiers: profile, appliesFightPacing: false,
        )
        battle.insertEffect(.deathsDoor, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 2)
        let card = try #require(battle.hand.cards.first { $0.owner == .hero })
        let events = try battle.playCard(cardID: card.id).events
        let criticalHits = events.count {
            $0.kind == .abilityDamage && $0.abilityID == Ability.rayOfFrost.id && $0.isCritical
        }
        #expect(criticalHits == 2)
        #expect(battle.roster.hero.currentMana == 2)
    }
}
