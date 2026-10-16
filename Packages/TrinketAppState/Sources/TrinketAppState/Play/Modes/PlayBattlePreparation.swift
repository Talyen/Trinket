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

extension BattleLootContext {
    @MainActor
    init(playerSave: PlayerSaveStore) {
        self.init(
            worldSeed: playerSave.worldSeed,
            ownership: RewardOwnership(playerSave.inventory),
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent,
            claimedJourneyRewardStageIDs: playerSave.journey.claimedRewardStageIDs,
        )
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
        scaling: EncounterScaling,
        partyAverageLevel: Int,
    ) -> ScaledEncounter? {
        guard let enemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID)
        else { return nil }
        let resolved = scaling.resolve(partyAverageLevel: partyAverageLevel)
        return ScaledEncounter(combatant: catalogEnemy.combatant, level: resolved.level, profile: resolved.profile)
    }

    /// Adapt mode content to Content's shared scaling policy and build the enemy.
    static func contractEncounter(for offer: ContractOffer, partyAverageLevel: Int) -> ScaledEncounter? {
        scaledEncounter(
            enemyID: offer.enemyID,
            scaling: .contract(offer.difficulty),
            partyAverageLevel: partyAverageLevel,
        )
    }

    static func journeyEncounter(for stage: Stage, worldSeed: UInt64, partyAverageLevel: Int) -> ScaledEncounter? {
        guard let chapter = GameContent.chapters.first(where: { $0.id == stage.chapterID })
        else { return nil }
        return scaledEncounter(
            enemyID: stage.resolvedBattleEnemyID(worldSeed: worldSeed),
            scaling: .journey(authoredLevel: EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)),
            partyAverageLevel: partyAverageLevel,
        )
    }

    static func labyrinthEncounter(for node: LabyrinthNode, partyAverageLevel: Int) -> ScaledEncounter? {
        scaledEncounter(
            enemyID: node.enemyID,
            scaling: .labyrinth(authoredLevel: EncounterLevelResolver.labyrinthEnemyLevel(for: node)),
            partyAverageLevel: partyAverageLevel,
        )
    }

    static func spireEncounter(for floor: SpireFloor) -> ScaledEncounter? {
        scaledEncounter(
            enemyID: floor.enemyID,
            scaling: .spire(authoredLevel: EncounterLevelResolver.spireEnemyLevel(for: floor)),
            partyAverageLevel: 1,
        )
    }
}
