import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct LeechAttackQualificationTests {
    @Test(arguments: [false, true])
    func `Symbiotic Venom grants Leech to Poison attacks but not ticks`(attack: Bool) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "parasitic_bloom"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, appliesFightPacing: false)
        battle.roster.hero.currentHealth = 1
        let operation: DamageOperation = attack
            ? .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1) : .periodic
        _ = battle.resolveTestDamage(8, keyword: .poison, options: operation)
        #expect((battle.health(of: battle.hero) > 1) == attack)
    }

    @Test func `Taste for Blood recognizes equipment Leech before rolling Critical chance`() {
        var profile = CombatantTalentCatalog.profile(for: ["rogue_bleed_t2_1"])
        profile.triggers.attackLeechPercent = 0.1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, seed: 9, appliesFightPacing: false)
        battle.roster.hero.currentHealth = 10
        battle.insertEffect(.bleed(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)

        let result = battle.resolveTestDamage(10, options: .attack(scaling: .flat, accuracy: .unavoidable))

        // Seed 9 rolls above ordinary Critical chance and below Taste for Blood's bonus.
        #expect(result.isCritical)
        #expect(result.healthLost == 20)
    }

    @Test func `Taste for Blood recognizes Scarfeast before rolling Critical chance`() {
        var profile = CombatantTalentCatalog.profile(for: ["rogue_bleed_t2_1"])
        profile.triggers.physicalAttackLeechBelowHalfHealth = true
        profile.triggers.criticalChanceBonus = -0.1
        var criticals = 0
        for seed in 1 ... 32 {
            var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, seed: UInt64(seed), appliesFightPacing: false)
            battle.roster.hero.currentHealth = 10
            battle.insertEffect(.bleed(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)
            let result = battle.resolveTestDamage(8, options: .attack(accuracy: .unavoidable))
            criticals += result.isCritical ? 1 : 0
        }
        #expect(criticals > 0)
    }

    @Test(arguments: [false, true])
    func `Necrotic Bleed strengthens Bloodfire attacks against Bleeding enemies`(bloodfire: Bool) {
        var profile = CombatantTalentCatalog.profile(for: ["risen_skeleton_leech_t3_2"])
        profile.triggers.bleedDamageLeech = bloodfire
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleTestFixtures.makePipelineContext(companionModifiers: profile, appliesFightPacing: false)
        battle.insertEffect(.bleed(1), to: battle.enemy, sourceID: battle.companion.id, remainingTurns: 2)
        let result = battle.resolveTestDamage(8, from: .companion, keyword: .bleed, options: .attack(accuracy: .unavoidable))
        #expect(result.healthLost == (bloodfire ? 10 : 8))
    }

    @Test(arguments: [false, true])
    func `Toxic Touch recognizes a full Health Leech Critical Hit but waits for a later Poison attack`(bloodfire: Bool) {
        var profile = CombatantTalentCatalog.profile(for: ["risen_skeleton_leech_t1_2"])
        profile.triggers.bleedDamageLeech = bloodfire
        var battle = BattleTestFixtures.makePipelineContext(companionModifiers: profile, appliesFightPacing: false)
        let before = battle.health(of: battle.enemy)
        let serial = battle.resolution.beginCard(actorID: battle.companion.id)
        _ = battle.resolution.beginAction(BattleActionContext(actor: battle.companion, in: battle), origin: .card)
        let result = battle.recordingResult { context in context.resolveTestDamage(
            4,
            from: .companion,
            keyword: .bleed,
            options: .attack(accuracy: .unavoidable, guaranteedCritical: true),
        ) }
        #expect(result.value.healthLost == 8)
        #expect(before - battle.health(of: battle.enemy) == 8)
        #expect(!result.events.contains { $0.abilityName == "Toxic Touch" })
        #expect(battle.roster.companion.talents.pending.nextLeechCriticalPoisonAttackBonus?.value == (bloodfire ? 3 : nil))
        let attack = DamageOperation.attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1)
        #expect(battle.resolveTestDamage(1, from: .companion, keyword: .poison, options: attack).healthLost == 1)
        battle.resolution.endAction()
        battle.resolution.endCard(serial)
        #expect(battle.resolveTestDamage(1, from: .companion, keyword: .poison, options: attack).healthLost == (bloodfire ? 4 : 1))
        #expect(battle.roster.companion.talents.pending.nextLeechCriticalPoisonAttackBonus == nil)
    }
}
