import Testing
import TrinketContent
import TrinketContentTestSupport

@Suite("Content access")
struct ContentAccessPolicyTests {
    @Test func `boundaries keep the free game playable`() {
        #expect(ContentAccessPolicy.free.allowsChapter(3))
        #expect(!ContentAccessPolicy.free.allowsChapter(4))
        #expect(ContentAccessPolicy.free.allowsLabyrinthFloor(3))
        #expect(!ContentAccessPolicy.free.allowsLabyrinthFloor(4))
        #expect(ContentAccessPolicy.free.allowsSpireFloor(10))
        #expect(!ContentAccessPolicy.free.allowsSpireFloor(11))
        #expect(ContentAccessPolicy.fullGame.allowsChapter(99))
        #expect(ContentAccessPolicy.fullGame.allowsLabyrinthFloor(999))
        #expect(ContentAccessPolicy.fullGame.allowsSpireFloor(999))
    }

    /// Representative slice: every starting hero, one companion, one seed.
    /// The full hero x companion x seed matrix belongs in codegen validation
    /// if anywhere; the recruit chain is deterministic per seed.
    @Test(arguments: ContentAccessPolicy.freeHeroIDs)
    func `campaign recruits complete the free roster`(heroID: String) throws {
        let companionID = try #require(ContentAccessPolicy.freeCompanionIDs.first)
        let seed: UInt64 = CombatantFixtures.deterministicBattleSeed
        var heroes: Set<String> = [heroID]
        var companions: Set<String> = [companionID]
        for chapter in GameContent.chapters where chapter.number <= 3 {
            for stage in chapter.stages {
                guard case .recruit = stage.encounter else { continue }
                let resolution = GameContent.resolveRecruitEncounter(
                    configuredEventID: stage.encounter.recruitEventID,
                    encounterID: stage.id,
                    worldSeed: seed,
                    unlockedHeroIDs: heroes,
                    unlockedCompanionIDs: companions,
                    access: .free,
                )
                guard case let .recruit(event) = resolution else { continue }
                let id = try #require(event.unlockCombatantID)
                #expect(ContentAccessPolicy.free.allowsCombatant(id))
                let combatant = try #require(GameContent.combatant(matching: id))
                if combatant.role == .hero {
                    heroes.insert(id)
                } else {
                    companions.insert(id)
                }
            }
        }
        #expect(heroes == Set(ContentAccessPolicy.freeHeroIDs))
        #expect(companions == Set(ContentAccessPolicy.freeCompanionIDs))
    }

    @Test func `ordering keeps every free choice before premium choices`() {
        for roster in [GameContent.heroes, GameContent.companions] {
            let ordered = ContentAccessPolicy.freeFirst(roster)
            let freeCount = ordered.count(where: { ContentAccessPolicy.isFreeCombatant($0.id) })
            #expect(ordered.prefix(freeCount).allSatisfy { ContentAccessPolicy.isFreeCombatant($0.id) })
            #expect(ordered.dropFirst(freeCount).allSatisfy { !ContentAccessPolicy.isFreeCombatant($0.id) })
            #expect(Set(ordered.map(\.id)) == Set(roster.map(\.id)))
        }
    }
}
