import BattleEngine
import TrinketContent
import TrinketFeatureContracts
import TrinketPersistence

public extension PlaySession {
    @discardableResult
    func restartActiveBattle() -> StageMapMessage? {
        guard let activeBattle = battle.activeBattle else { return nil }

        let registration = battleRegistration(for: activeBattle.runKey)
        let route = registration?.route
        if let restriction = playerSave.accessRestriction(for: route?.origin) {
            endBattleReturningToOrigin()
            return restriction
        }
        guard PlayBattleRoute.matches(
            route,
            runKey: activeBattle.runKey,
            missingLog: "Missing route for active battle restart",
        ) else {
            return nil
        }
        let presentation = registration?.presentation
        guard activeBattle.runKey == nil || presentation != nil else {
            appStateLogger.error("Missing presentation metadata for active battle restart")
            return nil
        }
        let universalModifiers = registration?.universalModifiers ?? []
        guard battleLaunch.restartActiveBattle(
            activeBattle,
            route: route,
            presentation: presentation,
            universalModifiers: universalModifiers,
        ) else { return PlayBattleLaunch.activationFailureMessage }
        return nil
    }
}
