import Foundation

/// Central registry for `retrySaveAction` keys. Keys must stay stable across
/// launches (the retry queue persists), so add cases — never rename — and keep
/// the raw strings unchanged.
enum SaveRetryKey {
    static func victory(_ configurationID: UUID) -> String {
        "victory-\(configurationID)"
    }

    static func defeat(_ configurationID: UUID) -> String {
        "defeat-\(configurationID)"
    }

    static func stage(_ stageID: String) -> String {
        "stage-\(stageID)"
    }

    static func labyrinthNode(_ nodeID: String) -> String {
        "node-\(nodeID)"
    }

    static func shopPurchase(_ offerID: String) -> String {
        "shop-purchase-\(offerID)"
    }

    static let shopOpen = "shop-open"
    static let shopLeave = "shop-leave"
    static let contractsEnter = "contracts-enter"
    static let contractsRefresh = "contracts-refresh"
    static let mysteryOpen = "mystery-open"
    static let mysteryResolution = "mystery-resolution"
}
