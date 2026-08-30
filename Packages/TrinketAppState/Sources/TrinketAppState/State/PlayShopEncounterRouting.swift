import Foundation
import TrinketFeatureContracts

enum PlayShopEncounterRouting {
    @MainActor
    static func handle(
        encounters: EncounterPlayMode,
        origin: PlayEncounterOrigin,
        identifier: String,
        onAutoComplete: () -> StageMapMessage?,
    ) -> StageMapMessage? {
        switch encounters.beginShopEncounter(origin: origin) {
        case .autoCompleted:
            if let failure = onAutoComplete() {
                return failure
            }
            return encounters.emptyShopClosedMessage(identifier: identifier)
        case .opened, .unavailable:
            return nil
        }
    }
}
