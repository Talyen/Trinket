import Foundation
import Testing
@testable import TrinketContent

struct UltimateCinematicCatalogTests {
    private struct CinematicCase {
        let actorID: String
        let abilityID: String
        let expectedVideoName: String?

        static let rogueShadowstep = Self(
            actorID: "rogue",
            abilityID: "shadowstep",
            expectedVideoName: "cinematic_rogue_shadowstep",
        )
        static let pantherShadowstep = Self(actorID: "panther", abilityID: "shadowstep", expectedVideoName: nil)
        static let foxShadowstep = Self(actorID: "fox", abilityID: "shadowstep", expectedVideoName: nil)
        static let knightAvatar = Self(
            actorID: "knight",
            abilityID: "avatar-of-justice",
            expectedVideoName: "cinematic_avatar_of_justice",
        )
        static let wizardAvatar = Self(actorID: "wizard", abilityID: "avatar-of-justice", expectedVideoName: nil)
    }

    @Test(arguments: [
        Self.CinematicCase.rogueShadowstep,
        .pantherShadowstep,
        .foxShadowstep,
        .knightAvatar,
        .wizardAvatar,
    ])
    private func `cinematic resolves only for the owning actor`(_ testCase: CinematicCase) throws {
        let reference = UltimateCinematicCatalog.reference(
            for: testCase.actorID,
            abilityID: testCase.abilityID,
        )
        try #expect(reference.videoName == testCase.expectedVideoName)
        try #expect(reference.actorID == testCase.actorID)
        try #expect(reference.abilityID == testCase.abilityID)
    }

    @Test func `unknown cast falls back with no video`() throws {
        let unknown = UltimateCinematicCatalog.reference(
            for: "rogue",
            abilityID: "missing-ability",
        )
        try #expect(unknown.videoName == nil)
        try #expect(unknown.hasAudio == false)
    }
}
