import Foundation
import Observation
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

/// Spire climb flow: prepare/start floor battles and spire victory persistence.
@MainActor
@Observable
public final class SpiresPlayMode {
    private weak var sessionRef: PlaySession?

    func attach(to session: PlaySession) {
        sessionRef = session
    }

    private var session: PlaySession {
        guard let sessionRef else {
            preconditionFailure("SpiresPlayMode used before attach")
        }
        return sessionRef
    }

    @discardableResult
    public func startBattle(for floor: SpireFloor) -> StageMapMessage? {
        guard session.battle.activeBattle == nil else { return nil }

        guard let spire = GameContent.spire(id: floor.spireID) else {
            return StageMapMessage(title: "Spire Missing", message: "This Spire is not ready yet.")
        }

        let spires = session.playerSave.spires
        let roster = session.playerSave.roster
        let homestead = session.playerSave.homestead

        guard spires.isFloorStartable(floor.floor, spireID: floor.spireID.rawValue) else {
            if spires.isFloorCleared(floor.floor, spireID: floor.spireID.rawValue) {
                return StageMapMessage(
                    title: "Floor Cleared",
                    message: "This floor is already complete."
                )
            }
            return StageMapMessage(
                title: "Floor Locked",
                message: "Clear earlier floors first."
            )
        }

        let attunement = SpireAttunement.evaluate(
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            spire: spire
        )
        guard attunement.isReady else {
            return StageMapMessage(title: "Not Attuned", message: attunement.message)
        }

        guard let encounter = ActiveBattleConfiguration.resolvedSpireEncounter(for: floor) else {
            return StageMapMessage(title: "Encounter Missing", message: "This floor is not ready yet.")
        }

        let loot = ActiveBattleConfiguration.lootPackage(
            for: .spire(spireID: floor.spireID, floor: floor.floor),
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent
        )
        session.activateBattle(
            resumeToken: .spire(spireID: floor.spireID, floor: floor.floor),
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            pendingRewardItem: loot?.item
        )
        return nil
    }

    public func prepareBattle(for floor: SpireFloor) {
        let spires = session.playerSave.spires
        let roster = session.playerSave.roster
        let homestead = session.playerSave.homestead
        guard session.battle.activeBattle == nil,
              let spire = GameContent.spire(id: floor.spireID),
              spires.isFloorStartable(floor.floor, spireID: floor.spireID.rawValue),
              SpireAttunement.evaluate(
                  hero: roster.activeHero,
                  companion: roster.activeCompanion,
                  spire: spire
              ).isReady,
              let encounter = ActiveBattleConfiguration.resolvedSpireEncounter(for: floor)
        else { return }

        let loot = ActiveBattleConfiguration.lootPackage(
            for: .spire(spireID: floor.spireID, floor: floor.floor),
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent
        )
        session.battle.prepareBattleRun(session.makeBattleConfiguration(
            resumeToken: .spire(spireID: floor.spireID, floor: floor.floor),
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            pendingRewardItem: loot?.item
        ))
    }

    func persistVictory(
        for configuration: ActiveBattleConfiguration,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]?
    ) -> Bool {
        guard case let .spire(spireID, floorNumber) = configuration.resumeToken else { return false }
        guard let floor = GameContent.spireFloor(spireID: spireID, floor: floorNumber) else {
            appStateLogger.error(
                "Missing spire floor for resume token: \(spireID.rawValue, privacy: .public)/\(floorNumber)"
            )
            return false
        }
        return completeFloor(
            floor,
            hero: hero,
            companion: companion,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards,
            rewardItem: configuration.pendingRewardItem
        )
    }

    @discardableResult
    func completeFloor(
        _ floor: SpireFloor,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil
    ) -> Bool {
        do {
            try session.playerSave.performBatchMutation { save in
                SpireCompletion.complete(
                    floor: floor,
                    hero: hero,
                    companion: companion,
                    battleEarnedGold: battleEarnedGold,
                    materialRewards: materialRewards,
                    rewardItem: rewardItem,
                    save: &save
                )
            }
            return true
        } catch {
            appStateLogger.error(
                "Failed to persist Spire floor: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}
