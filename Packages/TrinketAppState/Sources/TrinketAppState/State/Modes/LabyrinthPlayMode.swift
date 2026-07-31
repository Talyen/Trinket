import BattleEngine
import Foundation
import Observation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Labyrinth map flow: enter, node routing, rest/craft, and node completion writes.
@MainActor
@Observable
public final class LabyrinthPlayMode {
    private let playerSave: PlayerSaveStore
    private let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch
    private let encounters: EncounterPlayMode
    private let registerBattleRoute: (PlayBattleRoute) -> Void

    public var activeNodeSession: LabyrinthNodeSession?

    init(
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
        battleLaunch: PlayBattleLaunch,
        encounters: EncounterPlayMode,
        registerBattleRoute: @escaping (PlayBattleRoute) -> Void
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
        self.encounters = encounters
        self.registerBattleRoute = registerBattleRoute
    }

    private var canBeginTransientEncounter: Bool {
        battle.lifecyclePhase != .active
            && encounters.activeShopEncounter == nil
            && encounters.activeMysteryEncounter == nil
            && activeNodeSession == nil
    }

    @discardableResult
    func beginMysteryEncounter(
        nodeID: String,
        forcedEventID: String? = nil
    ) -> StageMapMessage? {
        encounters.beginMysteryEncounter(
            origin: .labyrinth(nodeID: nodeID),
            forcedEventID: forcedEventID,
            completeProgress: Self.completeMysteryProgress
        )
    }

    /// Completes a Labyrinth shop only after persistence succeeds so a failed leave
    /// keeps the encounter available for another attempt.
    @discardableResult
    public func finishActiveShopEncounter() -> Bool {
        guard let shopSession = encounters.activeShopEncounter,
              case let .labyrinth(nodeID) = shopSession.origin
        else { return false }

        shopSession.clearLeaveFailure()
        do {
            try playerSave.performBatchMutation { save in
                LabyrinthCompletion.complete(
                    nodeID: nodeID,
                    hero: save.roster.activeHero,
                    companion: save.roster.activeCompanion,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to leave Labyrinth shop: \(error.localizedDescription, privacy: .public)"
            )
            shopSession.markLeaveFailed("Couldn't save progress. Stay here and try Leave Shop again.")
            return false
        }
        encounters.clearActiveShopEncounter()
        return true
    }

    @discardableResult
    public func resolveActiveMysteryChoice(choiceID: String? = nil) -> Bool {
        encounters.resolveActiveMysteryChoice(
            choiceID: choiceID,
            completeProgress: Self.completeMysteryProgress
        ) != nil
    }

    @discardableResult
    public func selectActiveMysteryItem(itemID: String) -> Bool {
        encounters.selectActiveMysteryItem(
            itemID: itemID,
            completeProgress: Self.completeMysteryProgress
        ) != nil
    }

    @discardableResult
    public func corruptActiveMysteryItem(itemID: String) -> Bool {
        encounters.corruptActiveMysteryItem(
            itemID: itemID,
            completeProgress: Self.completeMysteryProgress
        )
    }

    @discardableResult
    public func finishActiveMysteryEncounter() -> Bool {
        encounters.finishActiveMysteryEncounter(
            completeProgress: Self.completeMysteryProgress
        ).didFinish
    }

    private static func completeMysteryProgress(
        _ session: MysteryEncounterSession,
        save: inout PlayerSave
    ) -> JourneyProgressState? {
        guard case let .labyrinth(nodeID) = session.origin else { return nil }
        LabyrinthCompletion.complete(
            nodeID: nodeID,
            hero: save.roster.activeHero,
            companion: save.roster.activeCompanion,
            save: &save
        )
        return nil
    }

    @discardableResult
    public func enter() -> StageMapMessage? {
        do {
            try playerSave.performBatchMutation { save in
                LabyrinthCompletion.enter(save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to enter Labyrinth: \(error.localizedDescription, privacy: .public)"
            )
            return StageMapMessage(title: "Labyrinth Error", message: "Could not open Labyrinth.")
        }
        return nil
    }

    @discardableResult
    public func handleNodeAction(nodeID: String) -> StageMapMessage? {
        guard canBeginTransientEncounter else { return nil }
        if let message = enter() {
            return message
        }
        let labyrinth = playerSave.labyrinth
        guard let node = labyrinth.node(id: nodeID) else {
            return StageMapMessage(title: "Path Missing", message: "This path is not ready yet.")
        }
        guard labyrinth.isNodeReachable(nodeID) else {
            return StageMapMessage(title: "Path Closed", message: "Clear another path to reach this node.")
        }

        let roster = playerSave.roster
        switch node.type.canonical {
        case .battle, .boss:
            return startBattle(nodeID: nodeID)
        case .shop:
            switch encounters.beginShopEncounter(origin: .labyrinth(nodeID: nodeID)) {
            case .autoCompleted:
                return completeNodeOrPersistFailure(nodeID: nodeID)
            case .opened, .unavailable:
                return nil
            }
        case .mystery, .event:
            return beginMysteryEncounter(nodeID: nodeID)
        case .recruit:
            let resolution = GameContent.resolveRecruitEncounter(
                configuredEventID: node.recruitEventID,
                encounterID: node.id,
                unlockedHeroIDs: roster.unlockedHeroIDs,
                unlockedCompanionIDs: roster.unlockedCompanionIDs
            )
            return beginMysteryEncounter(
                nodeID: nodeID,
                forcedEventID: resolution.event.id
            )
        case .rest:
            return beginRest(nodeID: nodeID)
        case .craft:
            return beginCraft(nodeID: nodeID)
        case .entrance:
            return nil
        }
    }

    @discardableResult
    func beginRest(nodeID: String) -> StageMapMessage? {
        guard canBeginTransientEncounter else { return nil }
        let labyrinth = playerSave.labyrinth
        guard let node = labyrinth.node(id: nodeID), node.type.canonical == .rest else {
            return StageMapMessage(title: "Shrine Missing", message: "This path is not ready yet.")
        }
        activeNodeSession = LabyrinthNodeSession.rest(
            node: node,
            effects: labyrinth.effects(for: nodeID),
            homestead: playerSave.homestead
        )
        return nil
    }

    @discardableResult
    func beginCraft(nodeID: String) -> StageMapMessage? {
        guard canBeginTransientEncounter else { return nil }
        let labyrinth = playerSave.labyrinth
        guard let node = labyrinth.node(id: nodeID), node.type.canonical == .craft else {
            return StageMapMessage(title: "Altar Missing", message: "This path is not ready yet.")
        }
        activeNodeSession = LabyrinthNodeSession.craft(node: node)
        return nil
    }

    @discardableResult
    public func finishActiveRest() -> Bool {
        guard let sessionNode = activeNodeSession, sessionNode.kind == .rest else { return false }
        sessionNode.clearFailure()
        do {
            try playerSave.performBatchMutation { save in
                LabyrinthCompletion.complete(
                    nodeID: sessionNode.nodeID,
                    hero: save.roster.activeHero,
                    companion: save.roster.activeCompanion,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to finish Labyrinth rest: \(error.localizedDescription, privacy: .public)"
            )
            sessionNode.markFailed("Couldn't save progress. Stay here and try Rest again.")
            return false
        }
        activeNodeSession = nil
        return true
    }

    public func dismissActiveNodeSessionWithoutCompleting() {
        activeNodeSession = nil
    }

    @discardableResult
    public func forgeActiveCraft() -> Bool {
        guard let sessionNode = activeNodeSession, sessionNode.kind == .craft else { return false }
        sessionNode.clearFailure()
        var forged = false
        do {
            try playerSave.performBatchMutation { save in
                forged = LabyrinthCompletion.forgeAtAltar(
                    nodeID: sessionNode.nodeID,
                    hero: save.roster.activeHero,
                    companion: save.roster.activeCompanion,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to forge at Labyrinth altar: \(error.localizedDescription, privacy: .public)"
            )
            sessionNode.markFailed("The altar stays cold. Try again.")
            return false
        }
        if forged {
            activeNodeSession = nil
            return true
        }
        sessionNode.markFailed("Not enough Gold.")
        return false
    }

    @discardableResult
    public func leaveActiveCraftWithoutForging() -> Bool {
        guard let sessionNode = activeNodeSession, sessionNode.kind == .craft else { return false }
        do {
            try playerSave.performBatchMutation { save in
                LabyrinthCompletion.complete(
                    nodeID: sessionNode.nodeID,
                    hero: save.roster.activeHero,
                    companion: save.roster.activeCompanion,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to leave Labyrinth craft: \(error.localizedDescription, privacy: .public)"
            )
            sessionNode.markFailed("The altar stays cold. Try again.")
            return false
        }
        activeNodeSession = nil
        return true
    }

    public func resolvedEncounter(for node: LabyrinthNode) -> (combatant: Combatant, level: Int)? {
        Self.resolvedEncounter(for: node)
    }

    @discardableResult
    func startBattle(nodeID: String) -> StageMapMessage? {
        guard battle.lifecyclePhase != .active else { return nil }
        let labyrinth = playerSave.labyrinth
        guard let node = labyrinth.node(id: nodeID), node.type.isCombat else {
            return StageMapMessage(title: "Encounter Missing", message: "This path is not ready yet.")
        }
        let effects = labyrinth.effects(for: nodeID)
        guard let encounter = resolvedEncounter(for: node) else {
            return StageMapMessage(title: "Encounter Missing", message: "This path is not ready yet.")
        }

        let origin = PlayBattleOrigin.labyrinth(nodeID: nodeID)
        registerBattleRoute(battleRoute(for: origin))
        battleLaunch.activateCombat(
            origin: origin,
            encounter: encounter,
            loot: battleLoot(for: node, labyrinth: labyrinth),
            defeatPrimaryAction: .retreat,
            universalModifiers: Self.combatModifiers(from: effects)
        )
        return nil
    }

    public func prepareReachableBattles() {
        guard battle.lifecyclePhase != .active else { return }
        for nodeID in playerSave.labyrinth.reachableNodeIDs() {
            prepareBattle(nodeID: nodeID)
        }
    }

    private func prepareBattle(nodeID: String) {
        let labyrinth = playerSave.labyrinth
        guard let node = labyrinth.node(id: nodeID), node.type.isCombat else { return }
        let effects = labyrinth.effects(for: nodeID)
        guard let encounter = resolvedEncounter(for: node) else { return }

        let origin = PlayBattleOrigin.labyrinth(nodeID: nodeID)
        registerBattleRoute(battleRoute(for: origin))
        battleLaunch.prepareCombat(
            origin: origin,
            encounter: encounter,
            loot: battleLoot(for: node, labyrinth: labyrinth),
            defeatPrimaryAction: .retreat,
            universalModifiers: Self.combatModifiers(from: effects)
        )
    }

    /// Completes a Labyrinth node, returning a save-failure message when persistence fails.
    func completeNodeOrPersistFailure(nodeID: String) -> StageMapMessage? {
        guard completeNode(nodeID: nodeID) else {
            return StageMapMessage(
                title: "Couldn't Save Progress",
                message: "This path wasn't saved. Try again."
            )
        }
        return nil
    }

    @discardableResult
    func completeNode(
        nodeID: String,
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil
    ) -> Bool {
        let roster = playerSave.roster
        let resolvedHero = hero ?? roster.activeHero
        let resolvedCompanion = companion ?? roster.activeCompanion
        do {
            try playerSave.performBatchMutation { save in
                LabyrinthCompletion.complete(
                    nodeID: nodeID,
                    hero: resolvedHero,
                    companion: resolvedCompanion,
                    battleEarnedGold: battleEarnedGold,
                    materialRewards: materialRewards,
                    rewardItem: rewardItem,
                    save: &save
                )
            }
            return true
        } catch {
            appStateLogger.error(
                "Failed to persist Labyrinth node: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}

extension LabyrinthPlayMode {
    static func resolvedEncounter(
        for node: LabyrinthNode
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID = node.enemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID)
        else { return nil }
        let level = LabyrinthCompletion.enemyLevel(for: node)
        return (CombatantLevelScaler.scale(enemy: catalogEnemy, level: level), level)
    }

    private static func combatModifiers(
        from effects: LabyrinthModifierEffects
    ) -> [AffixModifier] {
        effects.damageDealtBonus
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { .damageDealt($0.key, $0.value) }
    }

    private func battleLoot(
        for node: LabyrinthNode,
        labyrinth: PlayerLabyrinthState
    ) -> BattleLootPackage? {
        Self.resolveBattleLoot(
            for: node,
            effects: labyrinth.effects(for: node.id),
            worldSeed: labyrinth.worldSeed,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent
        )
    }

    static func resolveBattleLoot(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects,
        worldSeed: UInt64,
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage? {
        LabyrinthCompletion.resolveCombatLoot(
            for: node,
            effects: effects,
            worldSeed: worldSeed,
            astralChanceBonusPercent: astralChanceBonusPercent
        )
    }

    func battleRoute(for origin: PlayBattleOrigin) -> PlayBattleRoute {
        guard case let .labyrinth(nodeID) = origin else {
            return PlayBattleRoute(origin: origin) { _, _, _, _ in false }
        }
        return PlayBattleRoute(origin: origin) { [weak self] configuration, presentation, battleEarnedGold, materialRewards in
            guard let self else { return false }
            return completeNode(
                nodeID: nodeID,
                hero: configuration.hero.combatant,
                companion: configuration.companion.combatant,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: presentation?.pendingRewardItem
            )
        }
    }
}
