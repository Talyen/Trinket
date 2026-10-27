import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct GeneratedSaveRecoveryTests {
    /// The argument is the entire reproducer: keep this mapping stable when adding cases.
    @Test(arguments: GeneratedCaseSeeds.values(defaultCount: 64))
    func `damaged save combinations preserve independent progress`(seed: UInt64) throws {
        var generator = RecoveryGenerator(state: seed)
        let amounts = [Int.min, -1, 0, 1, 42, PlayerRosterState.maxGoldBalance, Int.max]
        let gold = amounts[generator.index(upperBound: amounts.count)]
        let wood = amounts[generator.index(upperBound: amounts.count)]
        let cooldown = amounts[generator.index(upperBound: amounts.count)]
        let level = generator.index(upperBound: 1000) + 1
        let claim = "contract-\(seed)"

        // Malformed offers must not erase independent Contracts progress.
        let contractsPayload = Data("""
        {"offers":"damaged-\(seed)","refreshAvailable":true,
         "highestWonEncounterLevel":\(level),"completedOfferIDs":["\(claim)"]}
        """.utf8)
        let voyagePayload = if seed.isMultiple(of: 2) {
            Data([0xFF, UInt8(truncatingIfNeeded: seed), 0x00])
        } else {
            Data("{\"version\":2,\"offers\":[],\"activeRun\":null,\"case\":\(seed)}".utf8)
        }

        var save = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 0))
        save.roster.gold = gold
        save.roster.unlockedHeroIDs.insert("missing-hero-\(seed)")
        save.homestead.resources[.wood] = wood
        save.corruptionAltarCooldownRemaining = cooldown
        save.journey.completedStageIDs.insert("chapter-1-stage-1")
        save.journey.claimedRewardStageIDs.insert("chapter-1-stage-1")
        save.contracts = PlayerContractsState.decodePayload(contractsPayload)
        save.voyage = PlayerVoyageState.decodePayload(voyagePayload)

        let repaired = try PlayerSaveSanitizer.sanitizeAndValidate(save)

        #expect(repaired.worldSeed == save.worldSeed)
        #expect(repaired.roster.gold == min(max(gold, 0), PlayerRosterState.maxGoldBalance))
        #expect(!repaired.roster.unlockedHeroIDs.contains("missing-hero-\(seed)"))
        #expect(repaired.homestead.resources[.wood] == max(wood, 0))
        #expect(repaired.corruptionAltarCooldownRemaining == max(cooldown, 0))
        #expect(repaired.journey.completedStageIDs.contains("chapter-1-stage-1"))
        #expect(repaired.journey.claimedRewardStageIDs.contains("chapter-1-stage-1"))
        #expect(repaired.contracts.offers.isEmpty)
        #expect(repaired.contracts.refreshAvailable)
        #expect(repaired.contracts.highestWonEncounterLevel == level)
        #expect(repaired.contracts.completedOfferIDs == [claim])
        #expect(repaired.voyage.isUnreadable)
        #expect(repaired.voyage.encodedPayload == voyagePayload)
        #expect(PlayerSaveSanitizer.sanitize(repaired) == repaired)
    }
}

private struct RecoveryGenerator {
    var state: UInt64

    mutating func index(upperBound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 32) % UInt64(upperBound))
    }
}
