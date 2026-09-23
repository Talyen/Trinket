import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HeroTalentReworkRegressionTests {
    @Test(arguments: [Keyword.physical, .bleed, .holy])
    func `leech armor pierce applies across attack damage types`(keyword: Keyword) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["warlock_leech_t1_2"]),
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: keyword, sourceActorID: battle.hero.id,
            options: DamageOperation.attack(
                tier: .skill, scaling: .items, accuracy: .unavoidable,
                abilityCriticalChanceBonus: -1, abilityHasLeech: true,
            ),
        ))
        #expect(outcome.healthLost == 3)
    }

    @Test func `holy revive allowance waits until companion is defeated`() {
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: .init(triggers: .init(
            revival: RevivalTriggers(holyDamageReviveCompanionChancePercent: 1),
        )))
        _ = battle.resolution.beginCard(actorID: battle.hero.id)
        _ = CombatTriggerEngine.afterHolyDamageDealt(to: battle.enemy, source: battle.hero, in: &battle)
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 0 }
        let events = CombatTriggerEngine.afterHolyDamageDealt(to: battle.enemy, source: battle.hero, in: &battle)
        #expect(battle.roster.companion.currentHealth == 1)
        #expect(events.contains { $0.abilityName == "Divine Blessing" && $0.effectKind == .instantHeal })
    }

    @Test func `poison critical prepares one bleed critical hit`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["rogue_poison_t2_1"]),
        )
        battle.appliesFightPacing = false
        let serial = battle.resolution.beginCard(actorID: battle.hero.id)
        let poison = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: .poison, sourceActorID: battle.hero.id,
            options: .attack(tier: .basic, origin: .card, scaling: .items, accuracy: .unavoidable, guaranteedCritical: true),
        ))
        #expect(poison.isCritical)
        #expect(battle.roster.hero.talents.pending.guaranteedBleedCritical)
        battle.resolution.endCard(serial)
        let bleed = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: .bleed, sourceActorID: battle.hero.id,
            options: .attack(tier: .basic, scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(bleed.isCritical)
        #expect(!battle.roster.hero.talents.pending.guaranteedBleedCritical)
    }

    @Test func `taste for blood increases leech critical chance against bleeding enemies`() {
        var leechCriticals = 0
        var ordinaryCriticals = 0
        for seed in UInt64(1) ... 64 {
            func critical(hasLeech: Bool) -> Bool {
                var battle = BattleTestFixtures.makePipelineContext(
                    targetEffects: [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)],
                    heroModifiers: CombatantTalentCatalog.profile(for: ["rogue_bleed_t2_1"]), seed: seed,
                )
                battle.appliesFightPacing = false
                return battle.resolveDamage(DamageRequest(
                    amount: 2, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
                    options: .attack(
                        tier: .skill, scaling: .items, accuracy: .unavoidable, abilityHasLeech: hasLeech,
                    ),
                )).isCritical
            }
            leechCriticals += critical(hasLeech: true) ? 1 : 0
            ordinaryCriticals += critical(hasLeech: false) ? 1 : 0
        }
        #expect(leechCriticals > ordinaryCriticals)
    }

    @Test func `shared prescription transfers only available excess healing`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["alchemist_health_t3_1", "alchemist_health_t1_1"]),
        )
        battle.appliesFightPacing = false
        battle.roster.companion.currentHealth = 1
        _ = battle.healEmitting(amount: 3, target: battle.hero, source: battle.hero, abilityName: "Heal")
        #expect(battle.roster.companion.currentHealth == 4)
    }
}
