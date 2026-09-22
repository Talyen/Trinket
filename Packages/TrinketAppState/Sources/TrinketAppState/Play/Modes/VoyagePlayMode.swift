import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
@Observable
public final class VoyagePlayMode {
    public let playerSave: PlayerSaveStore
    private let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch
    private let encounters: EncounterPlayMode
    private var preparationTracker = PlayBattlePreparationTracker<SingleBattlePreparationInputs>()

    init(playerSave: PlayerSaveStore, battle: any BattleRuntime, battleLaunch: PlayBattleLaunch, encounters: EncounterPlayMode) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
        self.encounters = encounters
    }

    @discardableResult
    public func enter() -> StageMapMessage? {
        guard encounters.canBeginTransientEncounter else { return nil }
        guard !playerSave.voyage.isUnreadable else {
            return StageMapMessage(title: "Voyage Unavailable", message: "Your Voyage could not be read. Your progress is preserved.")
        }
        let access = playerSave.contentAccess
        persist(key: "voyage-enter") { save in
            save.voyage.ensureBoard(access: access)
            Self.refreshRecruit(save: &save, access: access)
        }
        return nil
    }

    public func refresh() {
        guard encounters.canBeginTransientEncounter else { return }
        let access = playerSave.contentAccess
        persist(key: "voyage-refresh") { $0.voyage.refresh(access: access) }
    }

    public func embark(offerID: String) {
        guard encounters.canBeginTransientEncounter else { return }
        let access = playerSave.contentAccess
        persist(key: "voyage-embark-\(offerID)") { save in
            _ = save.voyage.embark(
                offerID: offerID,
                eligibleRecruitEventIDs: save.roster.eligibleRecruitEventIDs(access: access),
                access: access, eligibleRewards: RewardOwnership(save).eligibleModifiers,
            )
        }
    }

    public func abandon(runID: String) {
        guard encounters.canBeginTransientEncounter else { return }
        let access = playerSave.contentAccess
        persist(key: "voyage-abandon-\(runID)") { save in
            _ = save.voyage.abandon(runID: runID, access: access)
        }
        prunePrepared()
    }

    public func dismissCompleted() {
        guard encounters.canBeginTransientEncounter else { return }
        persist(key: "voyage-completed") { $0.voyage.dismissCompleted() }
    }

    public func resolvedEncounter(for node: VoyageNode) -> ScaledEncounter? {
        guard let run = playerSave.voyage.activeRun else { return nil }
        return PlayBattlePreparation.scaledEncounter(
            enemyID: node.enemyID,
            level: run.offer.difficulty.encounterLevel(partyLevel: playerSave.roster.activePartyAverageLevel),
        )
    }

    @discardableResult
    public func handleNode(runID: String, nodeID: String) -> StageMapMessage? {
        guard encounters.canBeginTransientEncounter,
              playerSave.voyage.isPlayable(runID: runID, nodeID: nodeID) else { return nil }
        let origin = PlayBattleOrigin.voyage(runID: runID, nodeID: nodeID)
        if let restriction = playerSave.accessRestriction(for: origin) {
            return restriction
        }
        _ = enter()
        guard let node = playerSave.voyage.node(runID: runID, nodeID: nodeID) else { return nil }
        let encounterOrigin = PlayEncounterOrigin.voyage(runID: runID, nodeID: nodeID)
        switch node.type {
        case .battle, .boss:
            prepareNextBattle()
            return battleLaunch.startBattle(origin: origin, encounters: encounters, busyMessage: nil, resolve: {
                request(runID: runID, node: node)
            }, onActivated: { preparationTracker.invalidate() })
        case .shop:
            return encounters.beginShopOrAutoComplete(origin: encounterOrigin, identifier: nodeID) { [self] in
                persist(key: "voyage-shop-\(nodeID)") { save in
                    _ = VoyageCompletion.completeNode(runID: runID, nodeID: nodeID, save: &save)
                }
                return nil
            }
        case .mystery:
            return encounters.beginMysteryEncounter(origin: encounterOrigin)
        case .recruit:
            return encounters.beginMysteryEncounter(origin: encounterOrigin, forcedEventID: node.recruitEventID)
        case .entrance:
            return nil
        }
    }

    public func prepareNextBattle() {
        guard encounters.canBeginTransientEncounter, let run = playerSave.voyage.activeRun,
              let node = run.nextNode, node.type.isCombat, let request = request(runID: run.id, node: node) else {
            prunePrepared()
            return
        }
        battleLaunch.prepareSingleBattle(
            tracker: &preparationTracker, origin: .voyage(runID: run.id, nodeID: node.id),
            stageRewardsAlreadyClaimed: false, party: PlayBattlePartySnapshot(playerSave: playerSave),
            makeRequest: { request },
        )
        battleLaunch.keepPreparedRuns([PlayBattleOrigin.voyage(runID: run.id, nodeID: node.id).runKey], preservingWhere: {
            if case .voyage = $0 {
                false
            } else {
                true
            }
        })
    }

    private func request(runID: String, node: VoyageNode) -> (input: BattleLaunchInput, route: PlayBattleRoute)? {
        guard let run = playerSave.voyage.activeRun, run.id == runID,
              let encounter = resolvedEncounter(for: node) else { return nil }
        let modifiers = RewardOwnership(playerSave.inventory).modifiers(ids: node.modifierIDs)
        let effects = LabyrinthModifierEffects.combining(modifiers)
        let loot = VoyageCompletion.resolveLoot(node: node, encounterLevel: encounter.level, save: playerSave.currentSave)
        let origin = PlayBattleOrigin.voyage(runID: runID, nodeID: node.id)
        let input = ModeBattleSpec.launchInput(
            origin: origin, encounter: encounter, loot: loot, roster: playerSave.roster,
            experienceBonusPercent: effects.experienceEarnedPercent,
            universalModifiers: LabyrinthPlayMode.combatModifiers(from: effects),
            labyrinthModifiers: modifiers,
            completionBonus: node.type == .boss ? VoyageCompletionBonus(gold: run.earnedGold, materials: run.earnedMaterials) : nil,
        )
        let access = playerSave.contentAccess
        let route = PlayBattleRoute.makeModeRoute(
            origin: origin, logging: "Failed to complete Voyage node", playerSave: playerSave,
        ) { configuration, presentation, award, materials, _, save in
            guard let presentation else { return .unavailable }
            let earned = presentation.rewardPlan.resolve(
                battleGold: award.award.goldFlow, materials: materials, includingCompletionBonus: false,
            )
            return VoyageCompletion.completeBattle(
                runID: runID, nodeID: node.id, hero: configuration.hero.combatant, companion: configuration.companion.combatant,
                rewards: (award, earned), save: &save, access: access,
            )
        }
        return (input, route)
    }

    private func prunePrepared() {
        battleLaunch.keepPreparedRuns([], preservingWhere: {
            if case .voyage = $0 {
                false
            } else {
                true
            }
        })
        preparationTracker.invalidate()
    }

    private func persist(key: String, action: @escaping (inout PlayerSave) -> Void) {
        guard playerSave.persistBatch(logging: "Failed to save Voyage", action) else {
            playerSave.retrySaveAction(key: key) { [weak self] in
                self?.persist(key: key, action: action)
            }
            return
        }
    }

    private static func refreshRecruit(save: inout PlayerSave, access: ContentAccessPolicy) {
        guard let run = save.voyage.activeRun else { return }
        let eligible = save.roster.eligibleRecruitEventIDs(access: access)
        for node in run.nodes where node.type == .recruit && !node.isCleared {
            if let id = node.recruitEventID, eligible.contains(id) {
                continue
            }
            save.voyage.updateNode(runID: run.id, nodeID: node.id) { updated in
                if let eventID = eligible.min() {
                    updated.recruitEventID = eventID
                } else {
                    updated.type = .mystery
                    updated.recruitEventID = nil
                    updated.modifierIDs = LabyrinthCatalog.modifierIDs(
                        for: .mystery,
                        enemyID: nil,
                        worldSeed: run.offer.seed,
                        nodeID: node.id,
                    )
                }
            }
        }
    }
}
