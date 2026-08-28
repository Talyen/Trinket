import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Shared prepare/activate shell for mode-owned battle encounters.
@MainActor
struct PlayBattleEncounterCoordinator<PreparationInputs: Equatable> {
    let battle: any BattleRuntime
    let battleLaunch: PlayBattleLaunch
    private var canBeginTransientEncounter: () -> Bool
    private(set) var preparedInputs: PreparationInputs?

    struct CombatRequest {
        let origin: PlayBattleOrigin
        let encounter: (combatant: Combatant, level: Int)
        let route: PlayBattleRoute
        let loot: BattleLootPackage?
        let stageRewardsAlreadyClaimed: Bool
        let universalModifiers: [AffixModifier]
        let labyrinthModifiers: [LabyrinthModifierDefinition]
        let preparationInputs: PreparationInputs
    }

    init(
        battle: any BattleRuntime,
        battleLaunch: PlayBattleLaunch,
        canBeginTransientEncounter: @escaping () -> Bool = { true }
    ) {
        self.battle = battle
        self.battleLaunch = battleLaunch
        self.canBeginTransientEncounter = canBeginTransientEncounter
    }

    mutating func installBeginGate(_ gate: @escaping () -> Bool) {
        canBeginTransientEncounter = gate
    }

    mutating func notePreparedInputs(_ inputs: PreparationInputs) {
        preparedInputs = inputs
    }

    var cachedPreparationInputs: PreparationInputs? {
        preparedInputs
    }

    func inputsMatch(_ inputs: PreparationInputs) -> Bool {
        preparedInputs == inputs
    }

    @discardableResult
    mutating func activateBattle(_ request: CombatRequest) -> Bool {
        guard canBeginTransientEncounter(), battle.lifecyclePhase != .active else { return false }
        let activated = battleLaunch.activateCombat(
            origin: request.origin,
            encounter: request.encounter,
            route: request.route,
            loot: request.loot,
            stageRewardsAlreadyClaimed: request.stageRewardsAlreadyClaimed,
            universalModifiers: request.universalModifiers,
            labyrinthModifiers: request.labyrinthModifiers
        )
        if activated {
            preparedInputs = nil
        }
        return activated
    }

    func activationFailureMessageIfNeeded(_ activated: Bool) -> StageMapMessage? {
        activated ? nil : PlayBattleLaunch.activationFailureMessage
    }

    @discardableResult
    mutating func prepareBattle(
        _ request: CombatRequest,
        forceWhenMissingPreparedRun: Bool = false
    ) -> Bool {
        guard battle.lifecyclePhase != .active else { return false }
        guard request.preparationInputs != preparedInputs
            || battle.lifecyclePhase == .idle
            || forceWhenMissingPreparedRun
            || !battle.hasPreparedRun(request.origin.runKey)
        else { return true }
        let prepared = battleLaunch.prepareCombat(
            origin: request.origin,
            encounter: request.encounter,
            route: request.route,
            loot: request.loot,
            stageRewardsAlreadyClaimed: request.stageRewardsAlreadyClaimed,
            universalModifiers: request.universalModifiers,
            labyrinthModifiers: request.labyrinthModifiers
        )
        if prepared {
            preparedInputs = request.preparationInputs
        }
        return prepared
    }

    @discardableResult
    func prepareCombatWithoutCache(_ request: CombatRequest) -> Bool {
        guard battle.lifecyclePhase != .active else { return false }
        return battleLaunch.prepareCombat(
            origin: request.origin,
            encounter: request.encounter,
            route: request.route,
            loot: request.loot,
            stageRewardsAlreadyClaimed: request.stageRewardsAlreadyClaimed,
            universalModifiers: request.universalModifiers,
            labyrinthModifiers: request.labyrinthModifiers
        )
    }
}

enum PlayShopEncounterRouting {
    @MainActor
    static func handle(
        encounters: EncounterPlayMode,
        origin: PlayEncounterOrigin,
        identifier: String,
        onAutoComplete: () -> StageMapMessage?
    ) -> StageMapMessage? {
        switch encounters.beginShopEncounter(origin: origin) {
        case .autoCompleted:
            if let failure = onAutoComplete() {
                return failure
            }
            return encounters.emptyShopClosedMessage(identifier: identifier)
        case .opened, .unavailable:
            return nil
        }
    }
}
