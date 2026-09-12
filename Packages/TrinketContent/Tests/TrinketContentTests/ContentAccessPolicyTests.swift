import Testing
import TrinketContent

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

    @Test func `every spire has A free party`() {
        let heroes = GameContent.heroes.filter { ContentAccessPolicy.free.allowsCombatant($0.id) }
        let companions = GameContent.companions.filter { ContentAccessPolicy.free.allowsCombatant($0.id) }
        for spire in GameContent.spires {
            #expect(SpireAttunement.canEnter(spire, heroes: heroes, companions: companions), "\(spire.title)")
        }
    }

    @Test func `conditional and unselected abilities count for attunement`() throws {
        let frostWhelp = Combatant(id: "frost_whelp", name: "Frost Whelp", role: .companion, maxHealth: 20, abilities: [.iceShot])
        let spire = try #require(GameContent.spire(id: .ironVein))
        #expect(!frostWhelp.keywordProfile.contains(.physical))
        #expect(SpireAttunement.matches(frostWhelp, spire: spire))
        let knight = try #require(GameContent.combatant(matching: "knight"))
        let holy = try #require(GameContent.spire(id: .aureateChoir))
        #expect(SpireAttunement.matches(knight, spire: holy))
    }

    @Test(arguments: ContentAccessPolicy.freeHeroIDs)
    func `campaign recruits complete the free roster`(heroID: String) throws {
        for companionID in ContentAccessPolicy.freeCompanionIDs {
            for seed: UInt64 in [1, 1772, 9999] {
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
        }
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
