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
        #expect(context.uniques.owners[owner]?.wrenflightDodge == 0.1)
        _ = try context.withAutomaticPlay { context in
            try play(attack(id: "automatic"), owner: owner, in: &context)
        }
        // Automatic plays do not advance the wearer's ordinary card count.
        try #expect(context.uniques.owners[owner]?.cardsPlayed == 2)
        _ = UniqueCombatEngine.startTurn(in: &context)
        #expect(context.uniques.owners[owner]?.wrenflightDodge == 0)
        #expect(context.uniques.owners[owner]?.cardsPlayed == 0)
        // The Returning Gale third-card rule is retired; Dodge-triggered returns are covered
        // by ReturningGaleRegressionTests (ordinary vs automatic, non-damaging, FIFO, no duplicates).
    }

    // The Returning Flight turn-start recovery rule is retired (replaced by immediate
    // first-Physical return). Coverage survives in ReturningGaleRegressionTests
    // (`flight returns first physical once and moves without deck cycle`,
    // `gale and flight together do not duplicate`).

    // The Patient Edge partner-damage rule is retired (replaced by Block-prepares-Crit).
    // Coverage survives in KeywordCohesionMechanicsTests
    // (`patient edge block prepares crit and refreshes`).

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
        context.uniques.owners[.hero, default: .init()].wildheartReady = true
        let events: [ActionEvent] = if automatic {
            try context.withAutomaticPlay { context in try play(.cinderbloom, in: &context) }
        } else {
            try play(.cinderbloom, in: &context)
        }
        let hit = try #require(events.first { $0.kind == .abilityDamage && $0.abilityID == "cinderbloom" })
        #expect(context.uniques.owners[.hero]?.wildheartReady == (automatic || hit.keyword != .poison))
        if !automatic {
            #expect(hit.isCritical == (hit.keyword == .poison))
        }
    }

    @Test func `draw and play does not spend unique card allowances`() throws {
        var context = try battle(["wrenflight", "the_returning_gale"])
        context.heroDeck = CombatDeck(abilities: [attack(.holy, id: "auto")])
        let ability = Ability(id: "draw", name: "draw", tier: .basic, effects: [.drawAndPlayCards(1)])
        try play(ability, in: &context)
        #expect(context.uniques.owners[.hero]?.cardsPlayed == 1)
        #expect(context.hand.isEmpty)
    }
}
