import Testing
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct HeroTalentReworkRegressionTests {
    @Test(arguments: [Keyword.physical, .bleed, .holy])
    func `leech armor pierce applies across attack damage types`(keyword: Keyword) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["warlock_leech_t1_2"]), appliesFightPacing: false,
        )
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        let outcome = battle.resolveTestDamage(
            8,
            keyword: keyword,
            options: DamageOperation.attack(scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1, abilityHasLeech: true),
        )
        #expect(outcome.healthLost == 3)
    }

    @Test func `holy revive allowance waits until companion is defeated`() {
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: .init(triggers: .init(
            revival: RevivalTriggers { $0.holyDamageReviveCompanionChancePercent = 1 },
        )))
        _ = battle.resolution.beginCard(actorID: battle.hero.id)
        CombatExecutor.run { await CombatTriggerEngine.afterHolyDamageDealt(to: battle.enemy, source: battle.hero, in: &battle) }
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 0 }
        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterHolyDamageDealt(
            to: battle.enemy,
            source: battle.hero,
            in: &battle,
        ) }
        #expect(battle.roster.companion.currentHealth == 1)
        #expect(events.contains { $0.abilityName == "Divine Blessing" && $0.effectKind == .instantHeal })
    }

    @Test func `poison critical prepares one bleed critical hit`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["rogue_poison_t2_1"]), appliesFightPacing: false,
        )
        let serial = battle.resolution.beginCard(actorID: battle.hero.id)
        let poison = battle.resolveTestDamage(
            2,
            keyword: .poison,
            options: .attack(tier: .basic, origin: .card, scaling: .items, accuracy: .unavoidable, guaranteedCritical: true),
        )
        #expect(poison.isCritical)
        #expect(battle.roster.hero.talents.pending.guaranteedBleedCritical?.value == true)
        battle.resolution.endCard(serial)
        let bleed = battle.resolveTestDamage(
            2,
            keyword: .bleed,
            options: .attack(tier: .basic, scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
        #expect(bleed.isCritical)
        #expect(battle.roster.hero.talents.pending.guaranteedBleedCritical == nil)
    }

    @Test(arguments: [false, true], [(false, false), (true, false), (false, true)])
    func `taste for blood requires a bleeding target and a leech attack`(
        bleeding: Bool, leech: (ability: Bool, talent: Bool),
    ) throws {
        // A roll between the ordinary 10% and talented 35% chances distinguishes eligibility in one hit.
        let seed = try #require((UInt64(1) ... 64).first { seed in
            var rng = SeededRandomNumberGenerator(seed: seed)
            return (0.10 ..< 0.35).contains(Double.random(in: 0 ..< 1, using: &rng))
        })
        var profile = CombatantTalentCatalog.profile(for: ["rogue_bleed_t2_1"])
        profile.triggers.attackLeechPercent = leech.talent ? 0.5 : 0
        var battle = BattleTestFixtures.makePipelineContext(
            targetEffects: bleeding ? [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)] : [],
            heroModifiers: profile, appliesFightPacing: false,
        )
        battle.rng = SeededRandomNumberGenerator(seed: seed)
        let outcome = battle.resolveTestDamage(2, options: .attack(
            scaling: .items, accuracy: .unavoidable, abilityHasLeech: leech.ability,
        ))
        #expect(outcome.isCritical == (bleeding && (leech.ability || leech.talent)))
    }

    @Test func `shared prescription transfers only available excess healing`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["alchemist_health_t3_1", "alchemist_health_t1_1"]),
            appliesFightPacing: false,
        )
        battle.roster.companion.currentHealth = 1
        battle.healEmitting(amount: 3, target: battle.hero, source: battle.hero, abilityName: "Heal")
        #expect(battle.roster.companion.currentHealth == 4)
    }
}
