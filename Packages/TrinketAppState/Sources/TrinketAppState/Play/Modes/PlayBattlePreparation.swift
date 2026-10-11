import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

/// The enemy build shared by inspection, preparation, activation, and Retry.
/// Resolve the power curve here so launch cannot select a different one.
public struct ScaledEncounter: Equatable {
    public let level: Int

    public var combatant: Combatant {
        build.combatant
    }

    let build: CombatBuild
    let faction: EnemyFaction

    init(combatant: Combatant, level: Int, profile: EnemyPowerCurve.Profile = .standard) {
        self.level = level
        if let enemy = GameContent.enemy(matching: combatant.id) {
            build = CombatBuildResolver.build(enemy: enemy, level: level, profile: profile)
            faction = enemy.faction
        } else {
            var modifiers = CombatModifierProfile.zero
            modifiers.outgoingDamagePercent = EnemyPowerCurve.rawDamagePercent(level: level, isBoss: false, profile: profile)
            build = CombatBuild(combatant: combatant, modifiers: modifiers)
            faction = .mortal
        }
    }
}

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

        universalModifiers = effects.combatModifiers
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
            encounter: encounter,
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

enum PlayBattlePreparation {
    static func scaledEncounter(
        enemyID: String?,
        level: Int,
        profile: EnemyPowerCurve.Profile = .standard,
    ) -> ScaledEncounter? {
        guard let enemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID)
        else { return nil }
        return ScaledEncounter(combatant: catalogEnemy.combatant, level: level, profile: profile)
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
            profile: offer.difficulty == .easy ? .recovery : .standard,
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
            profile: .spire,
        )
    }
}
