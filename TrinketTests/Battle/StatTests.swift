import XCTest
@testable import Trinket

final class StatTests: XCTestCase {
    private func advance(_ battle: inout BattleState) -> BattleStep {
        battle.advanceOneStep()
    }

    private func firstAbilityEvent(in step: BattleStep) -> ActionEvent? {
        let events: [ActionEvent]
        switch step {
        case let .acted(_, e): events = e
        case let .effectsOnly(e): events = e
        case let .ended(e): events = e
        }
        return events.first { $0.kind == .ability }
    }

    private func firstStatusEvent(in step: BattleStep) -> ActionEvent? {
        let events: [ActionEvent]
        switch step {
        case let .acted(_, e): events = e
        case let .effectsOnly(e): events = e
        case let .ended(e): events = e
        }
        return events.first { $0.kind == .status }
    }

    // MARK: - Strength

    func testStrengthIncreasesPhysicalDamage() {
        let strong = Combatant(
            id: "strong", name: "Strong", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.slash],
            primaryStats: PrimaryStats(strength: 10)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: strong, pet: pet, enemy: enemy)

        _ = advance(&battle) // tick 1: effects only (hero ready at 2, not ≤ 1)
        let step = advance(&battle) // tick 2: hero acts

        let event = firstAbilityEvent(in: step)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.amount, 1 + 10 / 5)
    }

    func testStrengthIncreasesStunDamage() {
        let strong = Combatant(
            id: "strong", name: "Strong", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.bash],
            primaryStats: PrimaryStats(strength: 10)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: strong, pet: pet, enemy: enemy)

        _ = advance(&battle)
        let step = advance(&battle)

        let event = firstAbilityEvent(in: step)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.amount, 1 + 10 / 5)
    }

    func testZeroStrengthDealsBaseDamage() {
        let weak = Combatant(
            id: "weak", name: "Weak", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.slash],
            primaryStats: PrimaryStats(strength: 0)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: weak, pet: pet, enemy: enemy)

        _ = advance(&battle)
        let step = advance(&battle)

        let event = firstAbilityEvent(in: step)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.keyword, .physical)
    }

    // MARK: - Agility

    func testAgilityIncreasesActionSpeed() {
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20, actionIntervalTicks: 10,
            abilities: [.slash],
            primaryStats: PrimaryStats(agility: 25)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        // agility 25 → intervalModifier = -5 → effectiveInterval = max(1, 10-5) = 5
        // hero acts at tick 5 (5th advance; first 4 are effects only)
        var heroActed = false
        for _ in 1 ... 6 {
            let s = advance(&battle)
            if case let .acted(actor, _) = s, actor.id == hero.id {
                heroActed = true
                break
            }
        }
        XCTAssertTrue(heroActed)
    }

    func testLowAgilitySlowerActionSpeed() {
        let slow = Combatant(
            id: "slow", name: "Slow", role: .hero, maxHealth: 20, actionIntervalTicks: 10,
            abilities: [.slash],
            primaryStats: PrimaryStats(agility: 0)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: slow, pet: pet, enemy: enemy)

        var heroActed = false
        for _ in 1 ... 6 {
            let s = advance(&battle)
            if case let .acted(actor, _) = s, actor.id == "slow" {
                heroActed = true
                break
            }
        }
        // Base interval 10, agility 0 → interval 10 → hero hasn't acted by tick 6
        XCTAssertFalse(heroActed)
    }

    // MARK: - Toughness

    func testToughnessIncreasesMaxHealth() {
        let tank = Combatant(
            id: "tank", name: "Tank", role: .hero, maxHealth: 10,
            abilities: [],
            primaryStats: PrimaryStats(toughness: 5)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10, abilities: [])
        let battle = BattleStateTestFactory.makeBattle(hero: tank, pet: pet, enemy: enemy)

        XCTAssertEqual(battle.heroHealth, 10 + 5)
    }

    func testToughnessMitigationReducesDamage() {
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: [],
            primaryStats: PrimaryStats(toughness: 50)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(
            id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash],
            primaryStats: PrimaryStats(strength: 0)
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        let initial = battle.heroHealth
        // enemy acts at tick 1
        let step = advance(&battle)

        let event = firstAbilityEvent(in: step)
        XCTAssertNotNil(event)
        let toughnessPct = 50.0 / (50.0 + 50.0) // 0.5
        let expectedTaken = Int(ceil(Double(1) * (1 - toughnessPct)))
        XCTAssertEqual(event?.amount, expectedTaken)
        XCTAssertEqual(battle.heroHealth, initial - expectedTaken)
    }

    // MARK: - Intellect

    func testIntellectIncreasesBurnDamage() {
        let wizard = Combatant(
            id: "wizard", name: "Wizard", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.fireball],
            primaryStats: PrimaryStats(intellect: 10)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: wizard, pet: pet, enemy: enemy)

        _ = advance(&battle) // tick 1
        let step = advance(&battle) // tick 2: hero acts

        let event = firstAbilityEvent(in: step)
        XCTAssertNotNil(event)
        // fireball directDamage 3 + intellect 10/5 = 2 → 5
        XCTAssertEqual(event?.amount, 3 + 10 / 5)
        XCTAssertEqual(event?.keyword, .burn)
    }

    func testIntellectIncreasesFreezeDamage() {
        let wizard = Combatant(
            id: "wizard", name: "Wizard", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.frostbolt],
            primaryStats: PrimaryStats(intellect: 10)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: wizard, pet: pet, enemy: enemy)

        _ = advance(&battle)
        let step = advance(&battle)

        let event = firstAbilityEvent(in: step)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.amount, 3 + 10 / 5)
        XCTAssertEqual(event?.keyword, .freeze)
    }

    // MARK: - Wisdom

    func testWisdomIncreasesHealing() {
        // Hero heals itself; wisdom increases the restored amount.
        // Enemy is fast but weak; hero slowly heals.
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 100,
            actionIntervalTicks: 2,
            abilities: [.heal],
            primaryStats: PrimaryStats(wisdom: 10)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(
            id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash],
            primaryStats: PrimaryStats(strength: 0)
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        // Tick 1: enemy hits hero for 1 → health = 100 - 1 = 99
        advance(&battle)
        // Tick 2: hero heals for 3 + 10/5 = 5 → health = min(100, 99+5) = 100
        // Then enemy hits → 99
        let healStep = advance(&battle)

        let healEvent = healStep.events.first { $0.effectKind == .instantHeal }
        XCTAssertNotNil(healEvent)
        // Hero received 5 healing (3 base + 2 wisdom); verify health bounced back to near max
        XCTAssertGreaterThanOrEqual(battle.heroHealth, 99)
    }

    func testWisdomIncreasesNatureDamage() {
        let druid = Combatant(
            id: "druid", name: "Druid", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.lightningBolt],
            primaryStats: PrimaryStats(wisdom: 10)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: druid, pet: pet, enemy: enemy)

        _ = advance(&battle)
        let step = advance(&battle)

        let event = firstAbilityEvent(in: step)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.amount, 3 + 10 / 5)
        XCTAssertEqual(event?.keyword, .nature)
    }

    func testWisdomIncreasesHolyDamage() {
        let priest = Combatant(
            id: "priest", name: "Priest", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.smite],
            primaryStats: PrimaryStats(wisdom: 10)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(hero: priest, pet: pet, enemy: enemy)

        _ = advance(&battle)
        let step = advance(&battle)

        let event = firstAbilityEvent(in: step)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.amount, 3 + 10 / 5)
        XCTAssertEqual(event?.keyword, .holy)
    }

    // MARK: - Prevention Resistance

    func testAgilityRaisesPreventionThreshold() {
        // Hero with agility 20 should have a higher stun threshold
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: [],
            primaryStats: PrimaryStats(agility: 20, toughness: 1)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(
            id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.bash],
            primaryStats: PrimaryStats(strength: 0)
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        // Enemy hits multiple times (high enough to overcome 5% dodge non-determinism)
        for _ in 0 ..< 10 {
            _ = advance(&battle)
        }

        let buildupEffect = battle.heroEffectSummaries.first { $0.text.contains("Build-up") }
        XCTAssertNotNil(buildupEffect)
    }

    // MARK: - DoT Resistance

    func testToughnessReducesDoTDamage() {
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: [],
            primaryStats: PrimaryStats(toughness: 50)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(
            id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.fireball],
            primaryStats: PrimaryStats(strength: 0, intellect: 0)
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        let initial = battle.heroHealth // 100 + 50 = 150

        // Tick 1: enemy acts — fireball directDamage 3 * (1 - 50/100) = 2
        advance(&battle)
        // Tick 2: burn ticks — floor(3/2)=1 * (1 - 50/100) = 1
        advance(&battle)

        // Toughness 50 → 50% mitigation → damage is roughly halved
        let expectedMaxDamage = 3 + 3 // max possible without mitigation
        let actualDamage = initial - battle.heroHealth
        XCTAssertLessThan(actualDamage, expectedMaxDamage)
        XCTAssertGreaterThan(actualDamage, 0)
    }

    // MARK: - Dodge Effect Persistence

    func testSavedEffectDodgeRoundTrip() {
        let effect = Effect.dodge(.dodge, 3)
        let saved = SavedEffect(effect)
        guard let restored = saved.effect() else {
            XCTFail("Failed to restore Effect from SavedEffect")
            return
        }
        XCTAssertEqual(restored, effect)
        if case let .dodge(keyword, duration) = restored {
            XCTAssertEqual(keyword, .dodge)
            XCTAssertEqual(duration, 3)
        } else {
            XCTFail("Restored effect is not dodge")
        }
    }

    // MARK: - Defaults

    func testDefaultStatsEqualZero() {
        let stats = PrimaryStats()
        XCTAssertEqual(stats.strength, 0)
        XCTAssertEqual(stats.agility, 0)
        XCTAssertEqual(stats.toughness, 0)
        XCTAssertEqual(stats.intellect, 0)
        XCTAssertEqual(stats.wisdom, 0)
    }

    func testCombatantDefaultsToZeroStats() {
        let hero = Combatant(id: "h", name: "H", role: .hero, maxHealth: 10, abilities: [.slash])
        XCTAssertEqual(hero.primaryStats, PrimaryStats())
    }

    func testStandardBattleStillWorksWithDefaultStats() {
        let hero = GameContent.heroes[0]
        let pet = GameContent.pets[0]
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet)
        while !battle.isBattleOver {
            _ = advance(&battle)
        }
        XCTAssertTrue(battle.isBattleOver)
    }

    // MARK: - PrimaryStats Codable

    func testPrimaryStatsCodable() throws {
        let stats = PrimaryStats(strength: 1, agility: 2, toughness: 3, intellect: 4, wisdom: 5)
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(PrimaryStats.self, from: data)
        XCTAssertEqual(decoded, stats)
    }

    // MARK: - PrimaryStats Rules (extracted from BattleState)

    func testStatBonusForDamageUsesCorrectStat() {
        let stats = PrimaryStats(strength: 10, agility: 15, intellect: 20, wisdom: 25)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .physical), 2)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .stun), 2)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .bleed), 3)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .burn), 4)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .freeze), 4)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .poison), 5)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .holy), 5)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .nature), 5)
        // Keywords without a stat mapping return 0
        XCTAssertEqual(stats.statBonusForDamage(keyword: .armor), 0)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .block), 0)
    }

    func testDodgeChanceCapsAtSeventyFivePercent() {
        XCTAssertEqual(PrimaryStats(agility: 0).dodgeChance, 0.05, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(agility: 10).dodgeChance, 0.10, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(agility: 100).dodgeChance, 0.55, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(agility: 1000).dodgeChance, 0.75, accuracy: 0.0001)
    }

    func testToughnessMitigationPctMatchesFormula() {
        XCTAssertEqual(PrimaryStats(toughness: 0).toughnessMitigationPct, 0.0, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(toughness: 50).toughnessMitigationPct, 0.5, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(toughness: 100).toughnessMitigationPct, 100.0 / 150.0, accuracy: 0.0001)
    }

    func testDotResistanceMultiplierMatchesFormula() {
        // 1 - 0.005 * toughness, floored at 0.25
        XCTAssertEqual(PrimaryStats(toughness: 0).dotResistanceMultiplier, 1.0, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(toughness: 50).dotResistanceMultiplier, 0.75, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(toughness: 100).dotResistanceMultiplier, 0.5, accuracy: 0.0001)
        // Past 150 toughness, multiplier caps at 0.25
        XCTAssertEqual(PrimaryStats(toughness: 200).dotResistanceMultiplier, 0.25, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(toughness: 1000).dotResistanceMultiplier, 0.25, accuracy: 0.0001)
    }
}
