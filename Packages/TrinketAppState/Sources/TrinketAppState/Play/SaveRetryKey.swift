import Foundation

/// Keys deduplicate in-memory action retries within the current save generation.
enum SaveRetryKey {
    static func victory(_ configurationID: UUID) -> String {
        "victory-\(configurationID)"
    }

    static func defeat(_ configurationID: UUID) -> String {
        "defeat-\(configurationID)"
    }

    static func shopPurchase(_ offerID: String) -> String {
        "shop-purchase-\(offerID)"
    }

    static func voyageEmbark(_ offerID: String) -> String {
        "voyage-embark-\(offerID)"
    }

    static func voyageAbandon(_ runID: String) -> String {
        "voyage-abandon-\(runID)"
    }

    static func voyageNode(runID: String, nodeID: String) -> String {
        "voyage-node-\(runID)-\(nodeID)"
    }

    static let shopOpen = "shop-open"
    static let shopLeave = "shop-leave"
    static let contractsEnter = "contracts-enter"
    static let contractsRefresh = "contracts-refresh"
    static let mysteryOpen = "mystery-open"
    static let mysteryResolution = "mystery-resolution"
    static let voyageEnter = "voyage-enter"
    static let voyageRefresh = "voyage-refresh"
    static let voyageCompleted = "voyage-completed"
}
