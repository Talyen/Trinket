import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct AllyBlockProtectionRegressionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Stalwart Oath uses the Block owners Health when protecting either partner`(target: BattleParticipant) throws {
        var battle = try makeBattle(talents: ["knight_block_t2_1", "knight_block_t4_1"])
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 40 }
        DefensePoolEngine.set(10, on: battle.hero, in: &battle)
        let outcome = hit(12, target: target, in: &battle)
        #expect(outcome.healthLost == 0)
        #expect(block(for: .hero, in: battle) == 2)
        #expect(battle.roster.companion.currentHealth == 100)
        #expect(battle.roster.hero.currentHealth == 40)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Patient Edge readies the wearer when its Block protects either partner`(target: BattleParticipant) throws {
        var battle = try makeBattle(uniques: ["the_patient_edge"])
        DefensePoolEngine.set(10, on: battle.hero, in: &battle)
        _ = hit(5, target: target, in: &battle)
        #expect(battle.roster[.hero].uniques.patientEdgeReady == true)
        #expect(battle.roster[.companion].uniques.patientEdgeReady != true)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Knights Answer belongs to the wearer whose Block absorbed the attack`(target: BattleParticipant) throws {
        let basic = Ability(id: "answer", name: "Answer", tier: .basic, effects: [.shield(.block, 3), .instantHeal(.health, 5)])
        var battle = try makeBattle(uniques: ["the_knights_answer"], basic: basic)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 40 }
        DefensePoolEngine.set(10, on: battle.hero, in: &battle)
        let first = battle.recordingResult { context in hit(5, target: target, in: &context) }
        #expect(first.events.contains { $0.kind == .ability && $0.actorID == battle.hero.id && $0.abilityID == basic.id })
        #expect(block(for: .hero, in: battle) == 8)
        #expect(battle.roster.hero.currentHealth == 45)
        #expect(battle.roster[.hero].uniques.turn.answeredBlock == true)
        #expect(battle.roster[.companion].uniques.turn.answeredBlock != true)
        let second = battle.recordingResult { context in hit(1, target: target, in: &context) }
        #expect(!second.events.contains { $0.kind == .ability && $0.abilityID == basic.id })
        #expect(block(for: .hero, in: battle) == 7)
    }

    @Test func `borrowed Block leaves the recipients Knights Answer available for their own absorption`() throws {
        let basic = Ability(id: "answer", name: "Answer", tier: .basic, effects: [.shield(.block, 3)])
        var battle = try UniqueCollectionTests().battle(
            ["the_knights_answer"], owner: .companion,
            other: CombatantTalentCatalog.profile(for: ["knight_block_t2_1"]), companionBasic: basic,
        )
        DefensePoolEngine.set(10, on: battle.hero, in: &battle)
        let borrowed = battle.recordingResult { context in hit(5, target: .companion, in: &context) }
        #expect(!borrowed.events.contains { $0.kind == .ability && $0.abilityID == basic.id })
        #expect(battle.roster[.companion].uniques.turn.answeredBlock != true)

        DefensePoolEngine.set(0, on: battle.hero, in: &battle)
        DefensePoolEngine.set(10, on: battle.companion, in: &battle)
        let own = battle.recordingResult { context in hit(5, target: .companion, in: &context) }
        #expect(own.events.contains { $0.kind == .ability && $0.actorID == battle.companion.id && $0.abilityID == basic.id })
        #expect(block(for: .companion, in: battle) == 8)
    }

    private func makeBattle(
        talents: Set<String> = ["knight_block_t2_1"],
        uniques: [String] = [],
        basic: Ability = .slash,
    ) throws -> BattleState {
        var profile = CombatantTalentCatalog.profile(for: talents)
        for id in uniques {
            let power = try #require(GameContent.unique(matching: id)?.affixPowers?.first)
            profile.merge(power.modifiers)
            power.triggers.apply(to: &profile)
        }
        return BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(id: "knight", maxHealth: 100, abilities: [basic]),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000),
            heroModifiers: profile, appliesFightPacing: false,
        )
    }

    private func hit(_ amount: Int, target: BattleParticipant, in battle: inout BattleState) -> CombatOutcome {
        battle.resolveTestDamage(
            amount,
            to: battle.roster[target].combatant,
            keyword: .physical,
            sourceActorID: battle.enemy.id,
            options: .attack(scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
    }

    private func block(for owner: BattleParticipant, in battle: BattleState) -> Int {
        DefensePoolEngine.blockPoints(in: battle.roster[owner].activeEffects)
    }
}
