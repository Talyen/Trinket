import Foundation
import TrinketCore

public enum NodeModifierCatalog {
    /// These combat entries set the original combat/reward category odds.
    private static let originalCombatIDs: Set<NodeModifierID> = Set([
        "ironPressure", "ashTithe", "bloodMarket", "serpentBloom", "rimeTax", "sunTithe", "concussionToll",
        "bulwarkBargain", "vampiricLedger", "wardedFlesh", "frostboundWard",
    ].map { NodeModifierID($0) })

    private static func combat(_ id: String, _ title: String, _ effect: NodeModifierEffect) -> NodeModifierDefinition {
        NodeModifierDefinition(id: NodeModifierID(id), title: title, effect: effect, nodeTypes: [.battle, .boss])
    }

    private static func shop(_ id: String, _ title: String, _ effect: NodeModifierEffect) -> NodeModifierDefinition {
        NodeModifierDefinition(id: NodeModifierID(id), title: title, effect: effect, nodeTypes: [.shop])
    }

    public static let modifiers: [NodeModifierDefinition] = [
        combat("ironPressure", "Iron Pressure", .damageDealt(keyword: .physical, amount: 1)),
        combat("ashTithe", "Ash Tithe", .damageDealt(keyword: .burn, amount: 1)),
        combat("bloodMarket", "Blood Market", .damageDealt(keyword: .bleed, amount: 1)),
        combat("serpentBloom", "Serpent Bloom", .damageDealt(keyword: .poison, amount: 1)),
        combat("rimeTax", "Rime Tax", .damageDealt(keyword: .freeze, amount: 1)),
        combat("sunTithe", "Sun Tithe", .damageDealt(keyword: .holy, amount: 1)),
        combat("concussionToll", "Concussion Toll", .damageDealt(keyword: .stun, amount: 1)),
        combat("bulwarkBargain", "Bulwark Bargain", .blockGained(2)),
        combat("vampiricLedger", "Vampiric Ledger", .leechGainedPercent(5)),
        combat("wardedFlesh", "Warded Flesh", .damageTakenReduction(keyword: .physical, percent: 50)),
        combat("cinderWard", "Cinder Ward", .damageTakenReduction(keyword: .burn, percent: 50)),
        combat("venomWard", "Venom Ward", .damageTakenReduction(keyword: .poison, percent: 50)),
        combat("crimsonWard", "Crimson Ward", .damageTakenReduction(keyword: .bleed, percent: 50)),
        combat("sunward", "Sunward", .damageTakenReduction(keyword: .holy, percent: 50)),
        combat("frostboundWard", "Frostbound Ward", .damageTakenReduction(keyword: .freeze, percent: 50)),
        combat("thunderWard", "Thunder Ward", .damageTakenReduction(keyword: .stun, percent: 50)),
        combat("briarWard", "Briar Ward", .damageTakenReduction(keyword: .thorns, percent: 50)),
        combat("shieldedArrival", "Shielded Arrival", .startBattleBlock(6)),
        combat("bloodHunger", "Blood Hunger", .attackLeech),
        combat("sunderedGuard", "Sundered Guard", .attackBlockRemoval(2)),
        combat("unbindingStrike", "Unbinding Strike", .attackPurge(1)),
        shop("shopDiscount", "Shop Discount", .shopDiscountPercent(10)),
        shop("appraisersEye", "Appraiser's Eye", .astralShopOffers),
    ] + RewardModifier.allCases.map { reward in
        NodeModifierDefinition(
            id: rewardID(reward), title: reward.title, effect: .reward(reward),
            nodeTypes: [.gold, .experience, .materials].contains(reward) ? [.battle, .boss, .mystery] : [.battle, .boss],
        )
    }

    public static func rewardID(_ reward: RewardModifier) -> NodeModifierID {
        switch reward {
        case .gold: NodeModifierID("bountyMark")
        case .experience: NodeModifierID("scholarsToll")
        case .materials: NodeModifierID("scavengersLuck")
        default: NodeModifierID("reward." + reward.rawValue)
        }
    }

    public static let modifiersByID: [NodeModifierID: NodeModifierDefinition] =
        Dictionary(uniqueKeysWithValues: modifiers.map { ($0.id, $0) })

    public static func modifier(id: NodeModifierID) -> NodeModifierDefinition? {
        modifiersByID[id]
    }

    public static func modifiers(
        ids: [NodeModifierID], eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> [NodeModifierDefinition] {
        ids.compactMap { id in
            guard let definition = modifiersByID[id] else { return nil }
            if case let .reward(reward) = definition.effect, !eligibleRewards.contains(reward) {
                return modifiersByID[rewardID(.gold)]
            }
            return definition
        }
    }

    public static func enemyDamageKeywords(for enemyID: String) -> Set<Keyword> {
        guard let enemy = GameContent.enemy(matching: enemyID) else { return [] }
        return Set(enemy.combatant.abilities.flatMap(\.keywords))
    }

    private static func matchingCombatModifiers(
        for nodeType: LabyrinthNodeType,
        matching predicate: (NodeModifierDefinition) -> Bool,
    ) -> [NodeModifierDefinition] {
        guard nodeType.isCombat else { return [] }
        return modifiers.filter { $0.applies(to: nodeType) && predicate($0) }
    }

    public static func combatModifiers(
        for enemyID: String,
        nodeType: LabyrinthNodeType,
    ) -> [NodeModifierDefinition] {
        let keywords = enemyDamageKeywords(for: enemyID)
        return matchingCombatModifiers(for: nodeType) { modifier in
            guard let keyword = modifier.relevantKeyword else { return true }
            return keywords.contains(keyword)
        }
    }

    public static func keywordModifiers(
        for keyword: Keyword,
        nodeType: LabyrinthNodeType,
    ) -> [NodeModifierDefinition] {
        matchingCombatModifiers(for: nodeType) { modifier in
            switch modifier.effect {
            case let .damageDealt(effectKeyword, _), let .damageTakenReduction(effectKeyword, _):
                effectKeyword == keyword
            case let .reward(reward):
                reward == .keyword(keyword)
            default:
                false
            }
        }
    }

    private static func applicableModifiers(
        for type: LabyrinthNodeType,
        enemyID: String?,
    ) -> [NodeModifierDefinition] {
        switch type {
        case .battle, .boss:
            enemyID.map { combatModifiers(for: $0, nodeType: type) } ?? []
        case .shop, .mystery:
            modifiers.filter { $0.applies(to: type) }
        case .recruit, .entrance:
            []
        }
    }

    public static func pickModifier(
        for type: LabyrinthNodeType,
        enemyID: String?,
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
        excluding previousID: NodeModifierID? = nil,
        using rng: inout some RandomNumberGenerator,
    ) -> NodeModifierID? {
        let applicable = applicableModifiers(for: type, enemyID: enemyID)
        let rewards = applicable.filter {
            if case let .reward(reward) = $0.effect {
                eligibleRewards.contains(reward)
            } else {
                false
            }
        }
        let combat = applicable.filter {
            if case .reward = $0.effect {
                false
            } else {
                true
            }
        }
        let pool: [NodeModifierDefinition]
        if type.isCombat, !rewards.isEmpty {
            // Keep the category odds from the original pool as new combat rules arrive.
            // Its Physical and Freeze wards were eligible only for matching enemies.
            let enemyKeywords = enemyID.map { enemyDamageKeywords(for: $0) } ?? []
            let originalCombatCount = combat.count { modifier in
                guard originalCombatIDs.contains(modifier.id) else { return false }
                return switch modifier.id.rawValue {
                case "wardedFlesh": enemyKeywords.contains(.physical)
                case "frostboundWard": enemyKeywords.contains(.freeze)
                default: true
                }
            }
            pool = Int.random(in: 0 ..< originalCombatCount + 3, using: &rng) < 3 ? rewards : combat
        } else {
            pool = combat + rewards
        }
        let different = pool.filter { $0.id != previousID }
        return (different.isEmpty ? pool : different).randomElement(using: &rng)?.id
    }

    public static func modifierIDs(
        for type: LabyrinthNodeType,
        enemyID: String?,
        worldSeed: UInt64,
        nodeID: String,
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> [NodeModifierID] {
        var rng = SeededRandomNumberGenerator(seed: GameContent.encounterSeed(worldSeed, salt: "labyrinth-modifier-\(nodeID)"))
        return pickModifier(for: type, enemyID: enemyID, eligibleRewards: eligibleRewards, using: &rng).map { [$0] } ?? []
    }

    public static func resolvedModifierIDs(
        for type: LabyrinthNodeType,
        enemyID: String?,
        existingModifierIDs: [NodeModifierID],
        worldSeed: UInt64,
        nodeID: String,
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> [NodeModifierID] {
        let applicable = applicableModifiers(for: type, enemyID: enemyID)
        if let existing = existingModifierIDs.compactMap({ id in
            applicable.first { $0.id == id }
        }).first {
            return [existing.id]
        }
        return modifierIDs(for: type, enemyID: enemyID, worldSeed: worldSeed, nodeID: nodeID, eligibleRewards: eligibleRewards)
    }
}
