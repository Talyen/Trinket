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

    /// Catalog enemies are immutable; bound this index to their authored IDs rather
    /// than retaining arbitrary encounter requests in a growing runtime cache.
    private static let enemyKeywordsByID: [String: Set<Keyword>] = Dictionary(
        uniqueKeysWithValues: GameContent.enemies.map { enemy in
            let keywords = enemy.combatant.abilities.reduce(into: Set<Keyword>()) { result, ability in
                result.formUnion(ability.keywords)
            }
            return (enemy.id, keywords)
        },
    )

    private static let modifiersByNodeType: [LabyrinthNodeType: [NodeModifierDefinition]] = Dictionary(
        uniqueKeysWithValues: LabyrinthNodeType.allCases.map { type in
            (type, modifiers.filter { $0.applies(to: type) })
        },
    )

    public static func enemyDamageKeywords(for enemyID: String) -> Set<Keyword> {
        enemyKeywordsByID[enemyID] ?? []
    }

    private static func matchingCombatModifiers(
        for nodeType: LabyrinthNodeType,
        matching predicate: (NodeModifierDefinition) -> Bool,
    ) -> [NodeModifierDefinition] {
        guard nodeType.isCombat else { return [] }
        return (modifiersByNodeType[nodeType] ?? []).filter(predicate)
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
            modifiersByNodeType[type] ?? []
        case .recruit, .entrance:
            []
        }
    }

    public static func pickModifier(
        for type: LabyrinthNodeType,
        enemyID: String?,
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
        affinityKeywords: Set<Keyword> = [],
        excluding previousID: NodeModifierID? = nil,
        using rng: inout some RandomNumberGenerator,
    ) -> NodeModifierID? {
        let applicable = applicableModifiers(for: type, enemyID: enemyID)
        var rewards: [NodeModifierDefinition] = []
        var combat: [NodeModifierDefinition] = []
        for modifier in applicable {
            if case let .reward(reward) = modifier.effect {
                if eligibleRewards.contains(reward) {
                    rewards.append(modifier)
                }
            } else {
                combat.append(modifier)
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
            let rewardPool = affinityBiasedRewards(rewards, affinityKeywords: affinityKeywords, using: &rng)
            pool = Int.random(in: 0 ..< originalCombatCount + 3, using: &rng) < 3 ? rewardPool : combat
        } else {
            pool = combat + rewards
        }
        let different = pool.filter { $0.id != previousID }
        return (different.isEmpty ? pool : different).randomElement(using: &rng)?.id
    }

    /// Favor reward modifiers whose keyword belongs to the chapter affinity set.
    /// Matching is by `RewardModifier.requiredKeyword`, so future reward
    /// modifiers for an affinity keyword are included without catalog edits.
    /// Non-keyword rewards (gold, materials) never match and stay in the shared
    /// fallback pool. Empty affinities consume no extra RNG, preserving legacy
    /// sequences for non-voyage callers.
    private static func affinityBiasedRewards(
        _ rewards: [NodeModifierDefinition],
        affinityKeywords: Set<Keyword>,
        using rng: inout some RandomNumberGenerator,
    ) -> [NodeModifierDefinition] {
        guard !affinityKeywords.isEmpty else { return rewards }
        let affinity = rewards.filter {
            if case let .reward(reward) = $0.effect, let keyword = reward.requiredKeyword {
                affinityKeywords.contains(keyword)
            } else {
                false
            }
        }
        guard !affinity.isEmpty else { return rewards }
        return Int.random(in: 0 ..< 4, using: &rng) < 3 ? affinity : rewards
    }

    public static func modifierIDs(
        for type: LabyrinthNodeType,
        enemyID: String?,
        worldSeed: UInt64,
        nodeID: String,
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
        affinityKeywords: Set<Keyword> = [],
    ) -> [NodeModifierID] {
        var rng = SeededRandomNumberGenerator(seed: GameContent.encounterSeed(worldSeed, salt: "labyrinth-modifier-\(nodeID)"))
        return pickModifier(
            for: type, enemyID: enemyID, eligibleRewards: eligibleRewards, affinityKeywords: affinityKeywords, using: &rng,
        ).map { [$0] } ?? []
    }

    public static func resolvedModifierIDs(
        for type: LabyrinthNodeType,
        enemyID: String?,
        existingModifierIDs: [NodeModifierID],
        worldSeed: UInt64,
        nodeID: String,
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
        affinityKeywords: Set<Keyword> = [],
    ) -> [NodeModifierID] {
        let applicableIDs = Set(applicableModifiers(for: type, enemyID: enemyID).map(\.id))
        if let existing = existingModifierIDs.first(where: applicableIDs.contains) {
            return [existing]
        }
        return modifierIDs(
            for: type, enemyID: enemyID, worldSeed: worldSeed, nodeID: nodeID, eligibleRewards: eligibleRewards,
            affinityKeywords: affinityKeywords,
        )
    }
}
