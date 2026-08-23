import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

/// Bounded downward party scaling must reach Labyrinth combat rewards: the level
/// actually fought drives both loot resolution and experience grants.
@Suite("LabyrinthEncounterLevelOverride")
struct LabyrinthEncounterLevelOverrideTests {
    @Test func combatLootResolvesAtProvidedEncounterLevelInsteadOfNodeDepth() throws {
        let node = LabyrinthNode(
            id: "level-override-node",
            type: .battle,
            enemyID: "goblin",
            depth: 2,
            clusterID: "labyrinth-test"
        )
        let atDepth = try #require(
            LabyrinthCompletion.resolveCombatLoot(
                for: node,
                effects: .zero,
                worldSeed: 5,
                ownedTrinketIDs: [],
                ownedUniqueIDs: []
            )
        )
        let explicit = try #require(
            LabyrinthCompletion.resolveCombatLoot(
                for: node,
                effects: .zero,
                encounterLevel: 2,
                worldSeed: 5,
                ownedTrinketIDs: [],
                ownedUniqueIDs: []
            )
        )
        #expect(explicit.gold == atDepth.gold)
        #expect(explicit.materials == atDepth.materials)

        // quantityRange bands never overlap between these levels, so every roll shifts up.
        let raised = try #require(
            LabyrinthCompletion.resolveCombatLoot(
                for: node,
                effects: .zero,
                encounterLevel: 40,
                worldSeed: 5,
                ownedTrinketIDs: [],
                ownedUniqueIDs: []
            )
        )
        for (boosted, base) in zip(raised.materials, atDepth.materials) {
            #expect(boosted.resource == base.resource)
            #expect(boosted.quantity > base.quantity)
        }
        #expect(raised.gold > atDepth.gold)
    }

    @Test func combatCompletionHonorsOverriddenEncounterLevelForExperience() {
        func grantedHeroXP(enemyEncounterLevel: Int?) -> Int {
            var save = PlayerSave.fresh
            save.labyrinth.ensureMap(seed: 31)
            let deepID = "labyrinth-scaling-battle"
            save.labyrinth.nodes[deepID] = LabyrinthNode(
                id: deepID,
                type: .battle,
                enemyID: "goblin",
                depth: 20,
                clusterID: "labyrinth-test",
                isRevealed: true
            )
            let hero = save.roster.activeHero
            save.roster.progressions[hero.id] = CombatantProgression(level: 20, currentXP: 0, requiredXP: 500)
            let before = save.roster.progression(for: hero)
            LabyrinthCompletion.complete(
                nodeID: deepID,
                hero: hero,
                companion: save.roster.activeCompanion,
                enemyEncounterLevel: enemyEncounterLevel,
                save: &save
            )
            return save.roster.progression(for: hero).currentXP - before.currentXP
        }

        let authored = grantedHeroXP(enemyEncounterLevel: nil)
        let scaled = grantedHeroXP(enemyEncounterLevel: 13)

        #expect(authored > 0)
        #expect(scaled > 0)
        #expect(scaled < authored)
    }
}
