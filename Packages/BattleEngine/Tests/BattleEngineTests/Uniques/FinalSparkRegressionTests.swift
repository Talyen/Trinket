import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct FinalSparkRegressionTests {
    @Test func `repeat does not consume the Burn newly attached after Backdraft`() throws {
        let fixtures = UniqueCollectionTests()
        var extra = CombatModifierProfile.zero
        extra.triggers.backdraft = true
        var battle = try fixtures.battle(["the_final_spark"], extra: extra)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 3 }
        battle.appendEffect(.burn(4), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)

        let events = try fixtures.play(fixtures.attack(.burn), critical: true, in: &battle)
        let original = try #require(events.first { $0.kind == .abilityDamage && $0.abilityName == "strike" })
        let repeated = try #require(events.first { $0.abilityName == "The Final Spark" })

        #expect(original.amount == 26)
        #expect(repeated.amount == original.amount)
        let burn = try #require(battle.activeEffects(of: battle.enemy).first { $0.keyword == .burn })
        #expect(burn.effect.potency == original.amount + repeated.amount)
    }

    @Test(arguments: [Keyword.poison, .freeze])
    func `resolved repeat leaves newly readied source preparations for the next attack`(keyword: Keyword) throws {
        var battle = try UniqueCollectionTests().battle([])
        battle.roster.mutateRuntime(for: battle.hero) {
            $0.talents.pending.doubleNextPoisonDamage = true
            $0.talents.pending.nextFreezeIgnoresBlock = true
        }
        DefensePoolEngine.set(4, on: battle.enemy, in: &battle)
        var options = DamageOperation.attack(scaling: .resolved, accuracy: .unavoidable)
        options.capturesCardRepeat = true
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: keyword, sourceActorID: battle.hero.id,
            options: options,
        ))

        #expect(outcome.healthLost == 6)
        #expect(battle.roster.hero.talents.pending.doubleNextPoisonDamage)
        #expect(battle.roster.hero.talents.pending.nextFreezeIgnoresBlock)
    }

    @Test func `repeat preserves one use damage bonuses and current block`() throws {
        let fixtures = UniqueCollectionTests()
        var battle = try fixtures.battle(["the_final_spark"])
        battle.roster.mutateRuntime(for: battle.hero) {
            $0.currentMana = 3
            $0.talents.pending.cardDamageBonus = 7
            $0.talents.pending.damageAfterDodge = 5
        }
        DefensePoolEngine.set(4, on: battle.enemy, in: &battle)

        let events = try fixtures.play(fixtures.attack(.freeze), in: &battle)
        let original = try #require(events.first { $0.kind == .abilityDamage && $0.abilityName == "strike" })
        let repeated = try #require(events.first { $0.abilityName == "The Final Spark" })

        #expect(original.amount == 19)
        #expect(repeated.amount == 23)
        #expect(battle.roster.hero.currentMana == 0)
        #expect(battle.roster.hero.talents.pending.cardDamageBonus == 0)
        #expect(battle.roster.hero.talents.pending.damageAfterDodge == 0)
    }

    @Test func `repeat keeps the original random critical result`() throws {
        let fixtures = UniqueCollectionTests()
        var battle = try fixtures.battle(["the_final_spark"])
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 3 }
        battle.rng = SeededRandomNumberGenerator(seed: 1)
        let ability = Ability(
            id: "critical_spell", name: "critical_spell", tier: .basic,
            directDamage: 10, damageKeyword: .freeze, criticalChanceBonus: 0.4,
        )

        let events = try fixtures.play(ability, in: &battle)
        let original = try #require(events.first { $0.kind == .abilityDamage && $0.abilityName == ability.name })
        let repeated = try #require(events.first { $0.abilityName == "The Final Spark" })

        #expect(repeated.isCritical == original.isCritical)
        #expect(repeated.amount == original.amount)
    }

    @Test func `repeat includes critical flat and percent bonuses`() throws {
        let fixtures = UniqueCollectionTests()
        let extra = CombatModifierProfile(criticalDamagePercent: 0.5, criticalDamageBonus: 3)
        var battle = try fixtures.battle(["the_final_spark"], extra: extra)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 3 }

        let events = try fixtures.play(fixtures.attack(.freeze), critical: true, in: &battle)
        let original = try #require(events.first { $0.kind == .abilityDamage && $0.abilityName == "strike" })
        let repeated = try #require(events.first { $0.abilityName == "The Final Spark" })

        #expect(original.amount == 38)
        #expect(repeated.amount == original.amount)
        #expect(repeated.isCritical)
    }

    @Test func `repeat preserves recurring initial pulse outgoing multipliers`() throws {
        let fixtures = UniqueCollectionTests()
        var extra = CombatModifierProfile.zero
        extra.triggers.manaEmpowerBurnFreezeDamageMultiplier = 2
        var ordinary = try fixtures.battle([], extra: extra)
        var spark = try fixtures.battle(["the_final_spark"], extra: extra)
        ordinary.roster.mutateRuntime(for: ordinary.hero) { $0.currentMana = 3 }
        spark.roster.mutateRuntime(for: spark.hero) { $0.currentMana = 3 }

        try fixtures.play(.blizzard, in: &ordinary)
        let events = try fixtures.play(.blizzard, in: &spark)
        let initialDamage = 2000 - ordinary.roster.enemy.currentHealth

        #expect(2000 - spark.roster.enemy.currentHealth == initialDamage * 2)
        #expect(events.count { $0.abilityName == "The Final Spark" } == 1)
        #expect(spark.roster.enemy.activeEffects.filter { $0.effect.kind == .recurringDamage }.map(\.effect)
            == ordinary.roster.enemy.activeEffects.filter { $0.effect.kind == .recurringDamage }.map(\.effect))
    }
}
