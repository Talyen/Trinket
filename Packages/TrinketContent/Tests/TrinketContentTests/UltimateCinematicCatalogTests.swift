import Foundation
import Testing
@testable import TrinketContent

struct UltimateCinematicCatalogTests {
    @Test func shadowstepResolvesOnlyForRogueActor() throws {
        let rogue = UltimateCinematicCatalog.reference(
            for: "rogue",
            abilityID: "shadowstep"
        )
        try #expect(rogue.videoName == "cinematic_rogue_shadowstep")
        try #expect(rogue.actorID == "rogue")
        try #expect(rogue.abilityID == "shadowstep")

        let panther = UltimateCinematicCatalog.reference(
            for: "panther",
            abilityID: "shadowstep"
        )
        try #expect(panther.videoName == nil)
        try #expect(panther.actorID == "panther")
        try #expect(panther.abilityID == "shadowstep")

        let fox = UltimateCinematicCatalog.reference(for: "fox", abilityID: "shadowstep")
        try #expect(fox.videoName == nil)
    }

    @Test func avatarOfJusticeResolvesOnlyForKnightActor() throws {
        let knight = UltimateCinematicCatalog.reference(
            for: "knight",
            abilityID: "avatar-of-justice"
        )
        try #expect(knight.videoName == "cinematic_avatar_of_justice")

        let wizard = UltimateCinematicCatalog.reference(
            for: "wizard",
            abilityID: "avatar-of-justice"
        )
        try #expect(wizard.videoName == nil)
    }

    @Test func unknownCastFallsBackWithNoVideo() throws {
        let unknown = UltimateCinematicCatalog.reference(
            for: "rogue",
            abilityID: "missing-ability"
        )
        try #expect(unknown.videoName == nil)
        try #expect(unknown.hasAudio == false)
    }
}
