import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CombatGoldBalanceTests {
    /// Protect currency issuance: failed rolls grant nothing; blocked damage keeps its theft basis.
    @Test(arguments: [Ability.bountyShot, .tithe], [false, true])
    func `card theft rolls once and reports only actual Gold`(ability: Ability, succeeds: Bool) throws {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: .withTriggers { $0.criticalChanceBonus = -1 }, appliesFightPacing: false,
        )
        let targeted = try #require(ability.targetedEffects.first)
        battle.rng = try BattleTestFixtures.rngSelectingChance(0.10, succeeds: succeeds)
        var expectedRNG = battle.rng
        _ = BattleChance.succeeds(probability: targeted.chance, using: &expectedRNG)

        let events = battle.performTestAction(ability)
        guard case let .resourceGain(.gold, amount) = targeted.effect else {
            Issue.record("Expected a Gold effect")
            return
        }
        #expect(battle.gold == (succeeds ? amount : 0))
        #expect(events.contains { $0.keyword == .gold } == succeeds)
        #expect(battle.rng == expectedRNG)
        #expect(battle.health(of: battle.enemy) == 100 - ability.damageComponents[0].amount)
    }

    @Test(arguments: [0, 2, 20], [false, true])
    func `Cutpurse Knife steals the whole Bleed packet including Block`(block: Int, succeeds: Bool) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "cutpurse_knife"))
        var profile = CombatModifierProfile.zero
        affix.astral.triggers.apply(to: &profile)
        profile.triggers.goldStealFlatBonus = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile, appliesFightPacing: false,
        )
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        battle.rng = try BattleTestFixtures.rngSelectingChance(0.10, succeeds: succeeds)

        _ = battle.resolveTestDamage(7, keyword: .bleed, options: .resolvedPeriodic)

        #expect(battle.health(of: battle.enemy) == 100 - max(0, 7 - block))
        #expect(battle.gold == (succeeds ? 9 : 0))
    }

    @Test(arguments: [false, true])
    func `Blood Price rolls independently on each Leech`(succeeds: Bool) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "blood_price"))
        var profile = CombatModifierProfile.zero
        affix.astral.triggers.apply(to: &profile)
        var battle = BattleStateTestFactory.makeMinimalBattle(heroModifiers: profile, appliesFightPacing: false)
        for _ in 0 ..< 2 {
            battle.rng = try BattleTestFixtures.rngSelectingChance(0.10, succeeds: succeeds)
            CombatExecutor.run { await CombatTriggerEngine.afterLeech(by: battle.hero, target: battle.enemy, in: &battle) }
        }
        #expect(battle.gold == (succeeds ? 4 : 0))
    }

    @Test(arguments: [false, true])
    func `Flawless Bounty rolls only for remaining Leech overflow`(succeeds: Bool) throws {
        var profile = CombatantTalentCatalog.profile(for: ["lizard_scout_gold_t3_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            companionModifiers: profile, appliesFightPacing: false,
        )
        battle.rng = try BattleTestFixtures.rngSelectingChance(0.10, succeeds: succeeds)
        CombatExecutor.run { _ = await HealingEngine.leechFromDamage(
            20, sourceActorID: battle.companion.id, target: battle.enemy, abilityHasLeech: true, in: &battle,
        ) }
        #expect(battle.gold == (succeeds ? 10 : 0))
        #expect(battle.health(of: battle.companion) == 100)
    }

    @Test func `saved Gold affixes adopt chance rules and preserve rolled Blood Price amounts`() throws {
        for id in ["blood_price", "cutpurse_knife"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            var triggers = CombatTraitTriggers()
            if id == "blood_price" {
                triggers.leechGoldFlat = 7
            } else {
                triggers.bleedDamageGoldFlat = 3
            }
            let base = try #require(GameContent.itemBaseTypes.first { $0.slot == affix.slot })
            let item = InventoryItem(
                id: "saved-\(id)", baseType: base, rarity: .astral, displayName: base.name,
                affixes: [affix.resolved(for: .astral)],
                affixPowers: [.init(description: "Old power", modifiers: [], triggers: triggers)],
            )
            let power = try #require(item.resolvedPower(at: 0))
            if id == "blood_price" {
                #expect(power.triggers.leechGoldFlat == 7)
                #expect(power.triggers.leechGoldChancePercent == 0.10)
                #expect(power.description.contains("7 Gold"))
            } else {
                #expect(power.triggers.bleedDamageGoldFlat == 0)
                #expect(power.triggers.bleedDamageGoldStealChancePercent == 0.10)
            }
        }
    }

    @Test func `effect chance survives transformations and appears in every language`() {
        let targeted = TargetedEffect(.burn(2), chance: 0.10)
        let transformed = AbilityOperation.effect(targeted).empowered(by: 3).targetedEffect
        #expect(transformed?.effect == .burn(5))
        #expect(transformed?.chance == 0.10)
        let ability = Ability(id: "chance-transform", name: "Chance", tier: .skill, operations: [.effect(targeted)])
        let empowered = ability.replacingOperations(ability.operations.map { $0.empowered(by: 3) })
        #expect(empowered.targetedEffects.first?.chance == 0.10)
        for language in ["en", "ja", "ko", "de", "zh-Hant", "fr", "es", "pt-BR"] {
            let summary = Ability.bountyShot.localizedSummary(locale: Locale(identifier: language))
            #expect(summary.values["part_1_chance"] == 10)
            #expect(summary.values["part_1_gold"] == 3)
            #expect(!summary.text.contains("%1$"))
        }
    }
}
