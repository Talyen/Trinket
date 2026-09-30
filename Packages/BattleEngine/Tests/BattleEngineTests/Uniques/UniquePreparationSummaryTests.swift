import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension UniqueCollectionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Wrenflight Dodge is visible until its next turn`(owner: BattleParticipant) throws {
        var context = try battle(["wrenflight"], owner: owner)
        let actor = context.roster[owner].combatant
        _ = try play(.block, owner: owner, in: &context)
        _ = try play(.block, owner: owner, in: &context)
        #expect(context.effectSummaries(of: actor).contains { $0.keyword == .dodge && $0.text.contains("Wrenflight") })
        _ = UniqueCombatEngine.startTurn(in: &context)
        #expect(!context.effectSummaries(of: actor).contains { $0.text.contains("Wrenflight") })
    }

    @Test(arguments: ["vipers_courtesy", "wildhearts_favor"])
    func `Unique Dodge preparation is visible until the qualifying hit`(id: String) throws {
        var context = try battle([id])
        let actor = context.hero
        context.appendEffect(.evadeNextHit, to: actor, sourceID: actor.id, remainingTurns: 0)
        _ = context.resolveDamage(DamageRequest(
            amount: 1, target: actor, keyword: .physical, sourceActorID: context.enemy.id,
            options: .attack(tier: .basic),
        ))
        let label = id == "vipers_courtesy" ? "Viper’s Courtesy" : "Wildheart’s Favor"
        #expect(context.effectSummaries(of: actor).contains { $0.keyword == .poison && $0.text.contains(label) })
        try play(attack(.poison), in: &context)
        #expect(!context.effectSummaries(of: actor).contains { $0.text.contains(label) })
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Crucible accumulated Holy damage is visible until spent`(owner: BattleParticipant) throws {
        var context = try battle(["the_golden_crucible"], owner: owner)
        let actor = context.roster[owner].combatant
        _ = context.grantGoldEvent(3, to: actor, abilityName: "Gold")
        #expect(context.effectSummaries(of: actor).contains {
            $0.keyword == .holy && $0.text.contains("The Golden Crucible") && $0.text.contains("3")
        })
        try play(attack(.holy), owner: owner, in: &context)
        #expect(!context.effectSummaries(of: actor).contains { $0.text.contains("The Golden Crucible") })
    }
}
