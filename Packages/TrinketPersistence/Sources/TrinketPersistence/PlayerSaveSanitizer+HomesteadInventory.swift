import os
import TrinketContent
import TrinketCore

extension PlayerSaveSanitizer {
    static func sanitizeHomestead(_ homestead: PlayerHomesteadState) -> PlayerHomesteadState {
        var sanitized = homestead
        if let remainders = homestead.rewardRemainders {
            let valid = HomesteadRewardRemainders(gold: remainders.gold, gems: remainders.gems)
            sanitized.rewardRemainders = valid == .zero ? nil : valid
        }
        let beforePending = homestead.pendingProduction.count
        sanitized.pendingProduction = homestead.validPendingProduction
        if let gold = sanitized.pendingProduction[.gold] {
            sanitized.pendingProduction[.gold] = PlayerRosterState.cappedPendingGold(gold)
        }
        if sanitized.pendingProduction.count != beforePending {
            logger.info("Sanitized homestead: dropped invalid pending production")
        }
        let hadGoldResource = homestead.resources[.gold] != nil
        sanitized.resources = homestead.resources.mapValues { max(0, $0) }
        sanitized.resources.removeValue(forKey: .gold)
        if hadGoldResource {
            logger.notice("Sanitized homestead: dropped gold from resources (roster owns gold)")
        }
        var tiers: [HomesteadNodeID: Int] = [:]
        tiers.reserveCapacity(homestead.nodeTiers.count)
        for (nodeID, tier) in homestead.nodeTiers {
            guard let maxTier = HomesteadNodeCatalog.maxTierByNodeID[nodeID] else { continue }
            tiers[nodeID] = min(max(tier, 0), maxTier)
        }
        sanitized.nodeTiers = tiers
        return sanitized
    }

    static func sanitizeInventory(_ inventory: PlayerInventoryState) -> PlayerInventoryState {
        let uniqueItems = InventoryDuplicatePolicy.deduplicated(inventory.items)
        if uniqueItems.count != inventory.items.count {
            logger
                .notice("Sanitized inventory: dropped \(inventory.items.count - uniqueItems.count, privacy: .public) duplicate items")
        }
        return PlayerInventoryState(items: uniqueItems.map(ItemResolution.removingRetiredAffixes(from:)))
    }
}
