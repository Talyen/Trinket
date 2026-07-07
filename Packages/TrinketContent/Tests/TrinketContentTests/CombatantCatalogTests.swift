import Testing
import TrinketContent

@Suite
struct CombatantCatalogTests {
    @Test func heroIDsAreUnique() {
        let ids = GameContent.heroes.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func petIDsAreUnique() {
        let ids = GameContent.pets.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func enemyIDsAreUnique() {
        let ids = GameContent.enemies.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func battleStagesReferenceKnownEnemies() throws {
        for chapter in GameContent.chapters {
            for stage in chapter.stages {
                if let enemyID = stage.encounter.battleEnemyID {
                    _ = try #require(
                        GameContent.enemy(matching: enemyID),
                        "Stage \(stage.id) references unknown enemy \(enemyID)"
                    )
                }
            }
        }
    }

    @Test func homesteadNodeIDsAreUnique() {
        let ids = GameContent.homesteadNodes.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func homesteadPrerequisitesReferenceKnownNodes() {
        let knownIDs = Set(GameContent.homesteadNodes.map(\.id))
        for node in GameContent.homesteadNodes {
            for requirement in node.prerequisites {
                #expect(
                    knownIDs.contains(requirement.nodeID),
                    "Node \(node.id) references unknown prerequisite \(requirement.nodeID)"
                )
            }
        }
    }

    @Test func homesteadNodeCatalogMatchesDefinitions() {
        for node in GameContent.homesteadNodes {
            #expect(HomesteadNodeCatalog.maxTierByNodeID[node.id] == node.maxTier)
        }
    }

    @Test func eachHeroHasBasicSkillUltimateChoices() throws {
        for hero in GameContent.heroes {
            #expect(!(hero.abilityChoices.basics.isEmpty, "\(hero.name)) should have basic choices")
            #expect(!(hero.abilityChoices.skills.isEmpty, "\(hero.name)) should have skill choices")
            #expect(!(hero.abilityChoices.ultimates.isEmpty, "\(hero.name)) should have ultimate choices")
            _ = try #require(hero.abilityLoadout.basic, "\(hero.name) should have a selected basic")
            _ = try #require(hero.abilityLoadout.skill, "\(hero.name) should have a selected skill")
            _ = try #require(hero.abilityLoadout.ultimate, "\(hero.name) should have a selected ultimate")
        }
    }

    @Test func eachPetHasBasicSkillUltimateChoices() throws {
        for pet in GameContent.pets {
            #expect(!(pet.abilityChoices.basics.isEmpty, "\(pet.name)) should have basic choices")
            #expect(!(pet.abilityChoices.skills.isEmpty, "\(pet.name)) should have skill choices")
            #expect(!(pet.abilityChoices.ultimates.isEmpty, "\(pet.name)) should have ultimate choices")
            _ = try #require(pet.abilityLoadout.basic, "\(pet.name) should have a selected basic")
            _ = try #require(pet.abilityLoadout.skill, "\(pet.name) should have a selected skill")
            _ = try #require(pet.abilityLoadout.ultimate, "\(pet.name) should have a selected ultimate")
        }
    }
}
