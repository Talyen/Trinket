import Foundation
import TrinketCore

public enum LabyrinthCatalog {
    /// These combat entries set the original combat/reward category odds.
    private static let originalCombatIDs: Set<LabyrinthModifierID> = Set([
        "ironPressure", "ashTithe", "bloodMarket", "serpentBloom", "rimeTax", "sunTithe", "concussionToll",
        "bulwarkBargain", "vampiricLedger", "wardedFlesh", "frostboundWard",
    ].map { LabyrinthModifierID($0) })

    public static let modifiers: [LabyrinthModifierDefinition] = [
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("ironPressure"),
            title: "Iron Pressure",
            effect: .damageDealt(keyword: .physical, amount: 1),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("ashTithe"),
            title: "Ash Tithe",
            effect: .damageDealt(keyword: .burn, amount: 1),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("bloodMarket"),
            title: "Blood Market",
            effect: .damageDealt(keyword: .bleed, amount: 1),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("serpentBloom"),
            title: "Serpent Bloom",
            effect: .damageDealt(keyword: .poison, amount: 1),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("rimeTax"),
            title: "Rime Tax",
            effect: .damageDealt(keyword: .freeze, amount: 1),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("sunTithe"),
            title: "Sun Tithe",
            effect: .damageDealt(keyword: .holy, amount: 1),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("concussionToll"),
            title: "Concussion Toll",
            effect: .damageDealt(keyword: .stun, amount: 1),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("bulwarkBargain"),
            title: "Bulwark Bargain",
            effect: .blockGained(2),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("vampiricLedger"),
            title: "Vampiric Ledger",
            effect: .leechGainedPercent(5),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("wardedFlesh"),
            title: "Warded Flesh",
            effect: .damageTakenReduction(keyword: .physical, percent: 50),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("cinderWard"),
            title: "Cinder Ward",
            effect: .damageTakenReduction(keyword: .burn, percent: 50),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("venomWard"),
            title: "Venom Ward",
            effect: .damageTakenReduction(keyword: .poison, percent: 50),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("crimsonWard"),
            title: "Crimson Ward",
            effect: .damageTakenReduction(keyword: .bleed, percent: 50),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("sunward"),
            title: "Sunward",
            effect: .damageTakenReduction(keyword: .holy, percent: 50),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("frostboundWard"),
            title: "Frostbound Ward",
            effect: .damageTakenReduction(keyword: .freeze, percent: 50),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("thunderWard"),
            title: "Thunder Ward",
            effect: .damageTakenReduction(keyword: .stun, percent: 50),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("briarWard"),
            title: "Briar Ward",
            effect: .damageTakenReduction(keyword: .thorns, percent: 50),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("shieldedArrival"),
            title: "Shielded Arrival",
            effect: .startBattleBlock(6),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("bloodHunger"),
            title: "Blood Hunger",
            effect: .attackLeech,
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("sunderedGuard"),
            title: "Sundered Guard",
            effect: .attackBlockRemoval(2),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("unbindingStrike"),
            title: "Unbinding Strike",
            effect: .attackPurge(1),
            nodeTypes: [.battle, .boss],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("shopDiscount"),
            title: "Shop Discount",
            effect: .shopDiscountPercent(10),
            nodeTypes: [.shop],
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("appraisersEye"),
            title: "Appraiser's Eye",
            effect: .astralShopOffers,
            nodeTypes: [.shop],
        ),
    ] + RewardModifier.allCases.map { reward in
        LabyrinthModifierDefinition(
            id: rewardID(reward), title: reward.title, effect: .reward(reward),
            nodeTypes: [.gold, .experience, .materials].contains(reward) ? [.battle, .boss, .mystery] : [.battle, .boss],
        )
    }

    public static func rewardID(_ reward: RewardModifier) -> LabyrinthModifierID {
        switch reward {
        case .gold: LabyrinthModifierID("bountyMark")
        case .experience: LabyrinthModifierID("scholarsToll")
        case .materials: LabyrinthModifierID("scavengersLuck")
        default: LabyrinthModifierID("reward." + reward.rawValue)
        }
    }

    public static let modifiersByID: [LabyrinthModifierID: LabyrinthModifierDefinition] =
        Dictionary(uniqueKeysWithValues: modifiers.map { ($0.id, $0) })

    public static let trashEnemyIDs: [String] = GameContent.nonBossEnemyIDs
    public static let bossEnemyIDs: [String] = GameContent.bossEnemyIDs

    public static func modifier(id: LabyrinthModifierID) -> LabyrinthModifierDefinition? {
        modifiersByID[id]
    }

    public static func modifiers(
        ids: [LabyrinthModifierID], eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> [LabyrinthModifierDefinition] {
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

    public static func combatModifiers(
        for enemyID: String,
        nodeType: LabyrinthNodeType,
    ) -> [LabyrinthModifierDefinition] {
        guard nodeType.isCombat else { return [] }
        let keywords = enemyDamageKeywords(for: enemyID)
        return modifiers.filter { modifier in
            guard modifier.applies(to: nodeType) else { return false }
            guard let keyword = modifier.relevantKeyword else { return true }
            return keywords.contains(keyword)
        }
    }

    private static func applicableModifiers(
        for type: LabyrinthNodeType,
        enemyID: String?,
    ) -> [LabyrinthModifierDefinition] {
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
        excluding previousID: LabyrinthModifierID? = nil,
        using rng: inout some RandomNumberGenerator,
    ) -> LabyrinthModifierID? {
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
        let pool: [LabyrinthModifierDefinition]
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
    ) -> [LabyrinthModifierID] {
        var rng = SeededRandomNumberGenerator(seed: GameContent.encounterSeed(worldSeed, salt: "labyrinth-modifier-\(nodeID)"))
        return pickModifier(for: type, enemyID: enemyID, eligibleRewards: eligibleRewards, using: &rng).map { [$0] } ?? []
    }

    public static func pickBossEnemyID(
        excluding previousBossID: String?,
        using rng: inout some RandomNumberGenerator,
    ) -> String {
        let pool = bossEnemyIDs.filter { $0 != previousBossID }
        let choices = pool.isEmpty ? bossEnemyIDs : pool
        return choices.randomElement(using: &rng) ?? bossEnemyIDs[0]
    }

    public static func pickTrashEnemyID(using rng: inout some RandomNumberGenerator) -> String {
        trashEnemyIDs.randomElement(using: &rng) ?? trashEnemyIDs[0]
    }

    public static func resolvedModifierIDs(
        for type: LabyrinthNodeType,
        enemyID: String?,
        existingModifierIDs: [LabyrinthModifierID],
        worldSeed: UInt64,
        nodeID: String,
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> [LabyrinthModifierID] {
        let applicable = applicableModifiers(for: type, enemyID: enemyID)
        if let existing = existingModifierIDs.compactMap({ id in
            applicable.first { $0.id == id }
        }).first {
            return [existing.id]
        }
        return modifierIDs(for: type, enemyID: enemyID, worldSeed: worldSeed, nodeID: nodeID, eligibleRewards: eligibleRewards)
    }

    public static func fallbackBossEnemyID(worldSeed: UInt64, nodeID: String) -> String {
        let pool = bossEnemyIDs
        let index = Int(
            GameContent.encounterSeed(worldSeed, salt: "labyrinth-boss-\(nodeID)") % UInt64(pool.count),
        )
        return pool[index]
    }
}
