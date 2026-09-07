import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `winter credit pays shortfall before mana rewards and triggers final spark`(owner: BattleParticipant) throws {
        var extra = CombatModifierProfile.zero
        extra.triggers.spendManaBlockFlat = 2
        extra.triggers.blockBrokenBlockFlat = 50
        var context = try battle(["winters_credit", "the_final_spark", "the_knights_answer"], owner: owner, extra: extra)
        context.roster.mutateRuntime(for: context.roster[owner].combatant) { $0.currentMana = 2 }
        block(3, owner: owner, in: &context)
        let events = try play(attack(.freeze), owner: owner, in: &context)
        #expect(context.roster[owner].currentMana == 0)
        #expect(blockAmount(owner, in: context) == 2)
        #expect(context.roster.enemy.currentHealth == 1978)
        #expect(events.count(where: { $0.abilityName == "The Final Spark" }) == 1)
        #expect(context.uniques.owners[owner]?.answeredBlock != true)
    }

    @Test func `block only empowerment does not spend mana allowances or draw opposite element`() throws {
        var extra = CombatModifierProfile.zero
        extra.triggers.spendManaBlockFlat = 2
        extra.triggers.drawOnSpendMana = 1
        extra.triggers.blockBrokenBlockFlat = 50
        var context = try battle(["winters_credit", "the_final_spark", "twin_casting"], extra: extra)
        context.heroDeck = CombatDeck(abilities: [attack(.burn, id: "opposite")])
        block(9, owner: .hero, in: &context)
        let events = try play(attack(.freeze), in: &context)
        #expect(context.roster.hero.currentMana == 0)
        #expect(blockAmount(.hero, in: context) == 0)
        #expect(context.roster.enemy.currentHealth == 1989)
        #expect(context.hand.isEmpty)
        #expect(!events.contains { $0.abilityName == "The Final Spark" })
        #expect(context.uniques.owners[.hero]?.usedFinalSpark != true)
        #expect(context.turnCadence.spendManaDrawOwners.isEmpty)
    }

    @Test(arguments: [Keyword.freeze, .burn])
    func `unavailable empowerment preserves both resources and still plays card`(keyword: Keyword) throws {
        var context = try battle(["winters_credit", "the_final_spark"])
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 2 }
        block(keyword == .freeze ? 2 : 100, owner: .hero, in: &context)
        let before = blockAmount(.hero, in: context)
        try play(attack(keyword), in: &context)
        #expect(context.roster.hero.currentMana == 2)
        #expect(blockAmount(.hero, in: context) == before)
        #expect(context.roster.enemy.currentHealth == 1990)
        #expect(context.uniques.owners[.hero]?.usedFinalSpark != true)
    }

    @Test func `final spark qualifies before refunds and does not repeat utility`() throws {
        var extra = CombatModifierProfile.zero
        extra.triggers.spendManaRefundChancePercent = 1
        var context = try battle(["the_final_spark"], extra: extra)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 3 }
        let spell = Ability(
            id: "spell",
            name: "spell",
            tier: .basic,
            directDamage: 10,
            damageKeyword: .burn,
            effects: [.shield(.block, 3)],
            criticalChanceBonus: -1,
        )
        let first = try play(spell, in: &context)
        #expect(context.roster.hero.currentMana == 3)
        #expect(blockAmount(.hero, in: context) == 3)
        #expect(context.roster.enemy.currentHealth == 1978)
        #expect(first.count(where: { $0.abilityName == "The Final Spark" }) == 1)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 3 }
        let second = try play(spell, in: &context)
        #expect(!second.contains { $0.abilityName == "The Final Spark" })
        #expect(context.roster.enemy.currentHealth == 1967)
        _ = UniqueCombatEngine.startTurn(in: &context)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 3 }
        let third = try play(spell, in: &context)
        #expect(third.count(where: { $0.abilityName == "The Final Spark" }) == 1)
    }

    @Test func `free empowerment cannot trigger mana spend rewards or final spark`() throws {
        var extra = CombatModifierProfile.zero
        extra.triggers.empowermentCostReduction = 3
        extra.triggers.spendManaBlockFlat = 2
        var context = try battle(["the_final_spark"], extra: extra)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 3 }
        try play(attack(.burn), in: &context)
        #expect(context.roster.hero.currentMana == 3)
        #expect(blockAmount(.hero, in: context) == 0)
        #expect(context.roster.enemy.currentHealth == 1989)
        #expect(context.uniques.owners[.hero]?.usedFinalSpark != true)
    }

    @Test func `final spark and everkeen do not recursively repeat`() throws {
        var context = try battle(["the_final_spark", "everkeen"])
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 3 }
        let events = try play(attack(.freeze), critical: true, in: &context)
        #expect(events.count(where: { $0.abilityName == "Everkeen" }) == 1)
        #expect(events.count(where: { $0.abilityName == "The Final Spark" }) == 1)
        #expect(context.roster.hero.currentMana == 0)
        #expect(context.uniques.reactionDepth == 0)
    }

    @Test func `crucible stores actual gains but not starting gold or other owners gold`() throws {
        var context = try battle(["the_golden_crucible"], extra: CombatModifierProfile(goldGainedBonus: 2))
        context.gold = 100
        try play(attack(.holy), in: &context)
        #expect(context.roster.enemy.currentHealth == 1990)
        _ = context.grantGoldEvent(3, to: context.roster.companion.combatant, abilityName: "Other")
        #expect(context.uniques.owners[.hero]?.goldDamage == 0)
        _ = context.grantGoldEvent(3, to: context.roster.hero.combatant, abilityName: "Grant")
        #expect(context.uniques.owners[.hero]?.goldDamage == 5)
        _ = context.resolveDamage(DamageRequest(
            amount: 1,
            target: context.roster.enemy.combatant,
            keyword: .holy,
            sourceActorID: context.roster.hero.id,
            options: .flatReaction,
        ))
        #expect(context.uniques.owners[.hero]?.goldDamage == 5)
        try play(attack(.holy), in: &context)
        #expect(context.roster.enemy.currentHealth == 1974)
        #expect(context.uniques.owners[.hero]?.goldDamage == 0)
    }

    @Test func `crucible gold from holy hit prepares next hit`() throws {
        var extra = CombatModifierProfile.zero
        extra.triggers.onAttackStealGold = 2
        var context = try battle(["the_golden_crucible"], extra: extra)
        _ = context.grantGoldEvent(5, to: context.roster.hero.combatant, abilityName: "Grant")
        try play(attack(.holy), in: &context)
        #expect(context.roster.enemy.currentHealth == 1985)
        #expect(context.uniques.owners[.hero]?.goldDamage == 2)
        try play(attack(.holy), in: &context)
        #expect(context.roster.enemy.currentHealth == 1973)
        #expect(context.uniques.owners[.hero]?.goldDamage == 2)
    }
}
