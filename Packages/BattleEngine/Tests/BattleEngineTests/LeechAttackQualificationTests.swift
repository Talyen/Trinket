import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct LeechAttackQualificationTests {
    @Test(arguments: [false, true])
    func `Symbiotic Venom grants Leech to Poison attacks but not ticks`(attack: Bool) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "parasitic_bloom"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile)
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 1
        let operation: DamageOperation = attack
            ? .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1) : .periodic
        _ = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: .poison, sourceActorID: battle.hero.id, options: operation,
        ))
        #expect((battle.health(of: battle.hero) > 1) == attack)
    }

    @Test func `Taste for Blood recognizes Scarfeast before rolling Critical chance`() {
        var profile = CombatantTalentCatalog.profile(for: ["rogue_bleed_t2_1"])
        profile.triggers.physicalAttackLeechBelowHalfHealth = true
        profile.triggers.criticalChanceBonus = -0.1
        var criticals = 0
        for seed in 1 ... 32 {
            var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, seed: UInt64(seed))
            battle.appliesFightPacing = false
            battle.roster.hero.currentHealth = 10
            battle.appendEffect(.bleed(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)
            let result = battle.resolveDamage(DamageRequest(
                amount: 8, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
                options: .attack(accuracy: .unavoidable),
            ))
            criticals += result.isCritical ? 1 : 0
        }
        #expect(criticals > 0)
    }

    @Test(arguments: [false, true])
    func `Necrotic Bleed strengthens Bloodfire attacks against Bleeding enemies`(bloodfire: Bool) {
        var profile = CombatantTalentCatalog.profile(for: ["risen_skeleton_leech_t3_2"])
        profile.triggers.bleedDamageLeech = bloodfire
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleTestFixtures.makePipelineContext(companionModifiers: profile)
        battle.appliesFightPacing = false
        battle.appendEffect(.bleed(1), to: battle.enemy, sourceID: battle.companion.id, remainingTurns: 2)
        let result = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: .bleed, sourceActorID: battle.companion.id,
            options: .attack(accuracy: .unavoidable),
        ))
        #expect(result.healthLost == (bloodfire ? 10 : 8))
    }

    @Test(arguments: [false, true])
    func `Toxic Touch follows a Bloodfire Leech Critical Hit at full Health`(bloodfire: Bool) {
        var profile = CombatantTalentCatalog.profile(for: ["risen_skeleton_leech_t1_2"])
        profile.triggers.bleedDamageLeech = bloodfire
        var battle = BattleTestFixtures.makePipelineContext(companionModifiers: profile)
        battle.appliesFightPacing = false
        let before = battle.health(of: battle.enemy)
        let result = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.enemy, keyword: .bleed, sourceActorID: battle.companion.id,
            options: .attack(accuracy: .unavoidable, guaranteedCritical: true),
        ))
        #expect(result.healthLost == 8)
        #expect(before - battle.health(of: battle.enemy) == (bloodfire ? 11 : 8))
        #expect(result.events.contains { $0.abilityName == "Toxic Touch" } == bloodfire)
    }
}
