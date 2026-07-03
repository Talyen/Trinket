import Foundation

extension GameContent {
    static func encounterArtID(for stage: Stage) -> String? {
        stageEncounterArt[stage.id]?.id
    }

    static func encounterArtTitle(for stage: Stage) -> String? {
        stageEncounterArt[stage.id]?.title
    }

    private static let stageEncounterArt: [String: (id: String, title: String)] = [
        "chapter-1-stage-2": ("mystery-sunlight-breaks-canopy", "Sunlit Trail"),
        "chapter-1-stage-4": ("destination-merchant-shop", "Merchant's Shop"),
        "chapter-1-stage-6": ("destination-campfire", "Campfire"),
        "chapter-1-stage-8": ("mystery-vines-carpet-mosaic-floors", "Hidden Mosaic")
    ]
}
