import os
import TrinketContent

extension PlayerSaveSanitizer {
    static func sanitizeHomestead(_ homestead: PlayerHomesteadState) -> PlayerHomesteadState {
        var sanitized = homestead
        let beforePending = homestead.pendingProduction.count
        sanitized.pendingProduction = Dictionary(
            uniqueKeysWithValues: homestead.validPendingProduction.map { resource, quantity in
                if resource == .gold {
                    return (resource, PlayerRosterState.cappedPendingGold(quantity))
                }
                return (resource, quantity)
            },
        )
        if sanitized.pendingProduction.count != beforePending {
            logger.info("Sanitized homestead: dropped invalid pending production")
        }
        let hadGoldResource = homestead.resources[.gold] != nil
        sanitized.resources = Dictionary(
            uniqueKeysWithValues: homestead.resources.compactMap { resource, quantity in
                guard resource != .gold else { return nil }
                return (resource, max(0, quantity))
            },
        )
        if hadGoldResource {
            logger.notice("Sanitized homestead: dropped gold from resources (roster owns gold)")
        }
        sanitized.nodeTiers = Dictionary(
            uniqueKeysWithValues: homestead.nodeTiers.compactMap { nodeID, tier in
                guard let maxTier = HomesteadNodeCatalog.maxTierByNodeID[nodeID] else { return nil }
                return (nodeID, min(max(tier, 0), maxTier))
            },
        )
        return sanitized
    }

    static func sanitizeInventory(_ inventory: PlayerInventoryState) -> PlayerInventoryState {
        let uniqueItems = InventoryDuplicatePolicy.deduplicated(inventory.items)
        if uniqueItems.count != inventory.items.count {
            logger
                .notice("Sanitized inventory: dropped \(inventory.items.count - uniqueItems.count, privacy: .public) duplicate items")
        }
        return PlayerInventoryState(items: uniqueItems)
    }
}
