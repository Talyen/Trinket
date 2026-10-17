import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `wrenflight counts only wearers ordinary cards`(owner: BattleParticipant) throws {
        var context = try battle(["wrenflight"], owner: owner)
        let other: BattleParticipant = owner == .hero ? .companion : .hero
        let draw = attack(id: "drawn")
        if owner == .hero {
            context.heroDeck = CombatDeck(abilities: [draw])
        } else {
            context.companionDeck = CombatDeck(abilities: [draw])
        }
        try play(attack(id: "first"), owner: owner, in: &context)
        try play(attack(id: "other"), owner: other, in: &context)
        let second = try play(attack(id: "second"), owner: owner, in: &context)
        #expect(second.contains { $0.abilityName == "Wrenflight" && $0.effectKind == .cardsDrawn })
        #expect(context.roster[owner].uniques.wrenflightDodge == 0.1)
        _ = try context.withAutomaticPlay { context in
            try play(attack(id: "automatic"), owner: owner, in: &context)
        }
        // Automatic plays do not advance the wearer's ordinary card count.
        try #expect(context.roster[owner].uniques.cardsPlayed == 2)
        UniqueCombatEngine.startTurn(in: &context)
        #expect(context.roster[owner].uniques.wrenflightDodge == 0)
        #expect(context.roster[owner].uniques.cardsPlayed == 0)
        // The Returning Gale third-card rule is retired; Dodge-triggered returns are covered
        // by ReturningGaleRegressionTests (ordinary vs automatic, non-damaging, FIFO, no duplicates).
    }

    // The Returning Flight turn-start recovery rule is retired (replaced by immediate
    // first-Physical return). Coverage survives in ReturningGaleRegressionTests
    // (`flight returns first physical once and moves without deck cycle`,
    // `gale and flight together do not duplicate`).

    @Test(
        arguments: [
            CombatantFixtures.deterministicBattleSeed,
            CombatantFixtures.deterministicBattleSeedVariant(1),
        ],
        [false, true],
    )
    func `cinderbloom uses its resolved element for Wildheart`(seed: UInt64, automatic: Bool) throws {
        var context = try battle(["wildhearts_favor"])
        context.rng = SeededRandomNumberGenerator(seed: seed)
        context.roster[.hero].uniques.wildheartReady = true
        let events: [ActionEvent] = if automatic {
            try context.withAutomaticPlay { context in try play(.cinderbloom, in: &context) }
        } else {
            try play(.cinderbloom, in: &context)
        }
        let hit = try #require(events.first { $0.kind == .abilityDamage && $0.abilityID == "cinderbloom" })
        #expect(context.roster[.hero].uniques.wildheartReady == (automatic || hit.keyword != .poison))
        if !automatic {
            #expect(hit.isCritical == (hit.keyword == .poison))
        }
    }

    @Test func `draw and play does not spend unique card allowances`() throws {
        var context = try battle(["wrenflight", "the_returning_gale"])
        context.heroDeck = CombatDeck(abilities: [attack(.holy, id: "auto")])
        let ability = Ability(id: "draw", name: "draw", tier: .basic, effects: [.drawAndPlayCards(1)])
        try play(ability, in: &context)
        #expect(context.roster[.hero].uniques.cardsPlayed == 1)
        #expect(context.hand.isEmpty)
    }

    @Test func `Paid in Full cannot strengthen the later hit that triggered its theft`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_physical_t4_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = try battle(["saintfall_plate", "golden_verdict"], extra: profile)
        let threshold = ControlMeterEngine.threshold(for: battle.enemy, in: battle)
        battle.insertEffect(
            .controlMeter(.stun, threshold - 6, threshold), to: battle.enemy,
            sourceID: battle.hero.id, remainingTurns: 0,
        )
        battle.insertEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        block(1, owner: .hero, in: &battle)

        // Consolation Prize can grant Wildcard Ray of Frost. Its first hit breaks
        // the caster's Block on Thorns; Saintfall's Holy response steals via Golden Verdict.
        let events = try play(.rayOfFrost, in: &battle)
        let hits = events.filter { $0.kind == .abilityDamage && $0.abilityID == Ability.rayOfFrost.id }
        #expect(hits.map(\.amount) == [1, 1])
        #expect(battle.gold == 1)
        #expect(battle.roster.hero.talents.pending.nextAttackDamageBonus?.value == 2)

        let next = try play(.slash, in: &battle)
        #expect(next.first { $0.kind == .abilityDamage && $0.abilityID == Ability.slash.id }?.amount == 5)
        #expect(battle.roster.hero.talents.pending.nextAttackDamageBonus == nil)
    }
}
