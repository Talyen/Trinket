import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct UniqueCollectionTests {
    func battle(
        _ ids: [String],
        owner: BattleParticipant = .hero,
        extra: CombatModifierProfile = .zero,
        enemyExtra: CombatModifierProfile = .zero,
        other: CombatModifierProfile = .zero,
        heroBasic: Ability = .slash,
        companionBasic: Ability = .fangs,
    ) throws -> BattleState {
        var profile = extra
        for id in ids {
            let item = try #require(GameContent.unique(matching: id))
            let signature = try #require(item.affixPowers?.first)
            profile.merge(signature.modifiers)
            signature.triggers.apply(to: &profile)
        }
        return BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 200, maxMana: 12, abilities: [heroBasic]),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 200, maxMana: 12, abilities: [companionBasic]),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 2000),
            heroMana: 0,
            companionMana: 0,
            heroModifiers: owner == .hero ? profile : other,
            companionModifiers: owner == .companion ? profile : other,
            enemyModifiers: enemyExtra, appliesFightPacing: false,
        )
    }

    func attack(_ keyword: Keyword = .physical, amount: Int = 10, id: String = "strike") -> Ability {
        Ability(id: id, name: id, tier: .basic, directDamage: amount, damageKeyword: keyword, criticalChanceBonus: -1)
    }

    @discardableResult
    func play(
        _ ability: Ability,
        owner: BattleParticipant = .hero,
        critical: Bool = false,
        in context: inout BattleState,
    ) throws -> [ActionEvent] {
        if critical {
            let actor = context.roster[owner].combatant
            context.insertEffect(.nextStrikeCritical, to: actor, sourceID: actor.id, remainingTurns: 0)
        }
        let card = BattleCardCombatEngine.deal(ability, owner: owner, context: &context)
        return try context.recordingEvents { observation in _ = try await BattleCardCombatEngine.resolveDrawnCard(
            card,
            context: &observation,
        ) }
    }

    func block(_ amount: Int, owner: BattleParticipant, in context: inout BattleState) {
        DefensePoolEngine.set(amount, on: context.roster[owner].combatant, in: &context)
    }

    func blockAmount(_ owner: BattleParticipant, in context: BattleState) -> Int {
        DefensePoolEngine.blockPoints(in: context.roster[owner].activeEffects)
    }

    func enemyHit(_ amount: Int, target: BattleParticipant = .hero, in context: inout BattleState) -> CombatOutcome {
        context.resolveTestDamage(
            amount,
            to: context.roster[target].combatant,
            keyword: .physical,
            sourceActorID: context.roster.enemy.id,
            options: DamageOperation.attack(accuracy: .unavoidable),
        )
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Wrenflight Dodge is visible until its next turn`(owner: BattleParticipant) throws {
        var context = try battle(["wrenflight"], owner: owner)
        let actor = context.roster[owner].combatant
        _ = try play(.block, owner: owner, in: &context)
        _ = try play(.block, owner: owner, in: &context)
        #expect(context.effectSummaries(of: actor).contains { $0.keyword == .dodge && $0.text.contains("Wrenflight") })
        UniqueCombatEngine.startTurn(in: &context)
        #expect(!context.effectSummaries(of: actor).contains { $0.text.contains("Wrenflight") })
    }

    @Test(arguments: ["vipers_courtesy", "wildhearts_favor"])
    func `Unique Dodge preparation is visible until the qualifying hit`(id: String) throws {
        var context = try battle([id])
        let actor = context.hero
        context.insertEffect(.evadeNextHit, to: actor, sourceID: actor.id, remainingTurns: 0)
        _ = context.resolveTestDamage(1, from: .enemy, to: .hero, options: .attack(tier: .basic))
        let label = id == "vipers_courtesy" ? "Viper’s Courtesy" : "Wildheart’s Favor"
        #expect(context.effectSummaries(of: actor).contains { $0.keyword == .poison && $0.text.contains(label) })
        try play(attack(.poison), in: &context)
        #expect(!context.effectSummaries(of: actor).contains { $0.text.contains(label) })
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Crucible accumulated Holy damage is visible until spent`(owner: BattleParticipant) throws {
        var context = try battle(["the_golden_crucible"], owner: owner)
        let actor = context.roster[owner].combatant
        context.grantGoldEvent(3, to: actor, abilityName: "Gold")
        #expect(context.effectSummaries(of: actor).contains {
            $0.keyword == .holy && $0.text.contains("The Golden Crucible") && $0.text.contains("3")
        })
        try play(attack(.holy), owner: owner, in: &context)
        #expect(!context.effectSummaries(of: actor).contains { $0.text.contains("The Golden Crucible") })
    }
}
