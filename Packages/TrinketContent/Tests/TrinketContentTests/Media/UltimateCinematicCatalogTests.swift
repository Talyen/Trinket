import Foundation
import Testing
@testable import TrinketContent

struct UltimateCinematicCatalogTests {
    @Test(arguments: [
        ("rogue", "shadowstep", "cinematic_rogue_shadowstep"),
        ("panther", "shadowstep", nil),
        ("fox", "shadowstep", nil),
        ("knight", "avatar-of-justice", "cinematic_avatar_of_justice"),
        ("wizard", "avatar-of-justice", nil),
    ] as [(String, String, String?)])
    func `cinematic resolves only for the owning actor`(actorID: String, abilityID: String, videoName: String?) {
        #expect(UltimateCinematicCatalog.reference(for: actorID, abilityID: abilityID).videoName == videoName)
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
