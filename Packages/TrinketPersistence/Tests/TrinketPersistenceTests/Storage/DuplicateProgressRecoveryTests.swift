import SwiftData
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct DuplicateProgressRecoveryTests {
    @Test func `duplicate XP ranking uses canonical repair without hiding the damaged row`() throws {
        let save = PlayerSave.testSeed
        let heroID = save.roster.activeHeroID
        let damaged = CombatantProgression(level: -9, currentXP: 20, requiredXP: -1)
        let root = try PlayerSaveRoot(save: save)
        root.roster?.progressions = [
            CombatantProgressionModel(combatantID: heroID, progression: .initial.addingExperience(9)),
            CombatantProgressionModel(combatantID: heroID, progression: damaged),
        ]
        let decoded = root.toPlayerSave()
        #expect(decoded.roster.progressions[heroID] == damaged)
        let sanitized = PlayerSaveSanitizer.sanitize(decoded)
        #expect(sanitized.roster.progressions[heroID] == .initial.addingExperience(20))
    }

    @Test(arguments: [false, true], [false, true]) @MainActor
    func `duplicate XP and Spire rows preserve greatest progress through repair and reload`(
        reverseRows: Bool, sameLevel: Bool,
    ) throws {
        let context = try PersistenceTestContext()
        let save = PlayerSave.testSeed
        let heroID = save.roster.activeHeroID
        let expected = CombatantProgression.at(level: 4000000).addingExperience(7)
        let stale = CombatantProgression.at(level: sameLevel ? expected.level : expected.level - 1).addingExperience(2)
        #expect(expected.totalEarnedExperience == Int.max)
        #expect(stale.totalEarnedExperience == Int.max)
        let spire = try #require(GameContent.spires.first)
        let root = try PlayerSaveRoot(save: save)
        let roster = try #require(root.roster)
        let spires = try #require(root.spires)
        var progressionRows = [
            CombatantProgressionModel(combatantID: heroID, progression: expected),
            CombatantProgressionModel(combatantID: heroID, progression: stale),
        ]
        var floorRows = [
            SpireFloorProgressModel(spireID: spire.id.rawValue, highestClearedFloor: 3),
            SpireFloorProgressModel(spireID: spire.id.rawValue, highestClearedFloor: 1),
        ]
        if reverseRows {
            progressionRows.reverse()
            floorRows.reverse()
        }
        roster.progressions = (roster.progressions ?? []).filter { $0.combatantID != heroID } + progressionRows
        spires.floors = floorRows
        let decoded = root.toPlayerSave()
        #expect(decoded.roster.progressions[heroID] == expected)
        #expect(decoded.spires.highestClearedFloor(for: spire.id.rawValue) == 3)
        let repairs = root.repairSlices(for: decoded)
        #expect(repairs.contains(.roster) && repairs.contains(.spires))
        let modelContext = try ModelContext(context.makeContainer())
        modelContext.insert(root)
        try modelContext.save()

        let store = try context.makeReloadedStore()
        #expect(store.roster.progressions[heroID] == expected)
        #expect(store.spires.highestClearedFloor(for: spire.id.rawValue) == 3)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.progressions[heroID] == expected)
        #expect(reloaded.spires.highestClearedFloor(for: spire.id.rawValue) == 3)
        let repairedContext = try context.makeSideContext()
        let progressionModels = try repairedContext.fetch(FetchDescriptor<CombatantProgressionModel>())
        let floorModels = try repairedContext.fetch(FetchDescriptor<SpireFloorProgressModel>())
        #expect(progressionModels.count { $0.combatantID == heroID } == 1)
        #expect(floorModels.count { $0.spireID == spire.id.rawValue } == 1)
    }
}
