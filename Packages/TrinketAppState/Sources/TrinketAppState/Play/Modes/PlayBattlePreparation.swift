import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

/// A resolved enemy plus the level it should fight at.
public typealias ScaledEncounter = (combatant: Combatant, level: Int)

/// Shared loot tail for battle modes: world seed, ownership, and astral bonus
/// read from the same save slice. Modes keep only their `resolveLoot`
/// selection; this removes the copied tail.
@MainActor
struct BattleLootContext {
    let worldSeed: UInt64
    let ownedTrinketIDs: Set<String>
    let ownedUniqueIDs: Set<String>
    let astralChanceBonusPercent: Int
    let ownership: RewardOwnership

    init(playerSave: PlayerSaveStore) {
        worldSeed = playerSave.worldSeed
        ownedTrinketIDs = playerSave.inventory.ownedTrinketIDs
        ownedUniqueIDs = playerSave.inventory.ownedUniqueIDs
        astralChanceBonusPercent = playerSave.homestead.effects.astralChanceBonusPercent
        ownership = RewardOwnership(playerSave.inventory)
    }
}

/// Keeps the combat, experience, and presentation views of one set of node
/// modifiers together when Spires, Labyrinth, or Voyage builds a battle.
struct ModeBattleModifiers {
    static let none = Self(definitions: [])

    let definitions: [NodeModifierDefinition]
    let experienceBonusPercent: Int
    let universalModifiers: [AffixModifier]

    init(definitions: [NodeModifierDefinition]) {
        self.definitions = definitions
        let effects = NodeModifierEffects.combining(definitions)
        experienceBonusPercent = effects.experienceEarnedPercent

        var modifiers: [AffixModifier] = effects.damageDealtBonus
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { .damageDealt($0.key, $0.value) }
        modifiers += effects.damageTakenReduction
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { .damageTakenPercent($0.key, Double($0.value) / 100) }
        if effects.blockGainedBonus != 0 {
            modifiers.append(.blockGained(effects.blockGainedBonus))
        }
        if effects.leechGainedPercent != 0 {
            modifiers.append(.leechGainedPercent(Double(effects.leechGainedPercent) / 100))
        }
        if effects.startBattleBlock != 0 {
            modifiers.append(.startBattleBlock(effects.startBattleBlock))
        }
        if effects.attackLeech {
            modifiers.append(.attackLeechPercent(Effect.abilityLeechPercent))
        }
        if effects.attackBlockRemoval != 0 {
            modifiers.append(.attackBlockRemoval(effects.attackBlockRemoval))
        }
        if effects.attackPurgeCount != 0 {
            modifiers.append(.attackPurgeCount(effects.attackPurgeCount))
        }
        universalModifiers = modifiers
    }
}

/// Shared roster + loot → launch-input tail for battle modes. Modes keep
/// only their `resolveLoot` selection plus any experience/modifier extras;
/// hero/companion lookup and reward plumbing stay single-owned here.
enum ModeBattleSpec {
    static func launchInput(
        origin: PlayBattleOrigin,
        encounter: ScaledEncounter,
        loot: BattleLootResult,
        roster: PlayerRosterState,
        stageRewardsAlreadyClaimed: Bool = false,
        experienceBonusPercent: Int = 0,
        victoryOnlyExperienceBonusPercent: Int = 0,
        modifiers: ModeBattleModifiers = .none,
        completionBonus: VoyageCompletionBonus? = nil,
        additionalRewardItems: [InventoryItem] = [],
    ) -> BattleLaunchInput {
        BattleLaunchInput(
            origin: origin,
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot.asStageReward,
            experienceBonusPercent: experienceBonusPercent + modifiers.experienceBonusPercent,
            victoryOnlyExperienceBonusPercent: victoryOnlyExperienceBonusPercent,
            pendingRewardItem: loot.item,
            additionalRewardItems: additionalRewardItems,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            universalModifiers: modifiers.universalModifiers,
            nodeModifiers: modifiers.definitions,
            completionBonus: completionBonus,
        )
    }
}

/// Preparation cache key for single-battle modes (Journey, Spires).
/// Both warm at most one run; the run key identifies the battle 1:1 with the
/// mode's battle origin (stage ID, spire + floor), so cache behavior is unchanged.
struct SingleBattlePreparationInputs: Equatable {
    let runKey: BattleRunKey
    let party: PlayBattlePartySnapshot
    let stageRewardsAlreadyClaimed: Bool
}

enum PlayBattlePreparation {
    static func scaledEncounter(
        enemyID: String?,
        level: Int,
    ) -> ScaledEncounter? {
        guard let enemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID)
        else { return nil }
        return (CombatantLevelScaler.scale(enemy: catalogEnemy, level: level), level)
    }

    /// One home for per-mode encounter math. The level curves stay distinct by
    /// design (contracts track party level, journey/labyrinth blend authored
    /// and party levels, spires stay fixed); only the lookup-and-scale tail
    /// is shared.
    static func contractEncounter(for offer: ContractOffer, partyAverageLevel: Int) -> ScaledEncounter? {
        scaledEncounter(
            enemyID: offer.enemyID,
            level: EncounterLevelResolver.contractEnemyLevel(
                difficulty: offer.difficulty,
                partyAverageLevel: partyAverageLevel,
            ),
        )
    }

    static func journeyEncounter(for stage: Stage, worldSeed: UInt64, partyAverageLevel: Int) -> ScaledEncounter? {
        guard let chapter = GameContent.chapters.first(where: { $0.id == stage.chapterID })
        else { return nil }
        return scaledEncounter(
            enemyID: stage.resolvedBattleEnemyID(worldSeed: worldSeed),
            level: EncounterLevelResolver.campaignAdjusted(
                EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter),
                partyAverageLevel: partyAverageLevel,
            ),
        )
    }

    static func labyrinthEncounter(for node: LabyrinthNode, partyAverageLevel: Int) -> ScaledEncounter? {
        scaledEncounter(
            enemyID: node.enemyID,
            level: EncounterLevelResolver.labyrinthAdjusted(
                EncounterLevelResolver.labyrinthEnemyLevel(for: node),
                partyAverageLevel: partyAverageLevel,
            ),
        )
    }

    static func spireEncounter(for floor: SpireFloor) -> ScaledEncounter? {
        scaledEncounter(
            enemyID: floor.enemyID,
            level: EncounterLevelResolver.spireEnemyLevel(for: floor),
        )
    }
}
