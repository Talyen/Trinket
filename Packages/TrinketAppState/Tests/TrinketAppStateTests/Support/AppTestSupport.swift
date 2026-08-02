import Foundation
import TrinketBattleFeature
import TrinketBattleRuntime
import TrinketFeatureSupport
import TrinketPersistence
import TrinketTestSupport
@testable import TrinketAppState

@MainActor
enum AppTestSupport {
    static func makeEnvironment(arguments: [String] = []) -> AppEnvironment {
        AppEnvironment.parse(arguments: arguments, environment: [:])
    }

    static func makeAppState(
        arguments: [String] = [],
        playerSave: PlayerSaveStore? = nil,
        directoryURL: URL,
        userDefaults: UserDefaults? = nil
    ) throws -> AppState {
        let runtime = BattleRuntimeSession()
        let battle = BattleSession(runtime: runtime, presentationEnvironment: .silent)
        return try AppState(
            environment: makeEnvironment(arguments: arguments),
            playerSave: playerSave ?? SaveTestSupport.makeSaveStore(directoryURL: directoryURL),
            userDefaults: userDefaults,
            battleComposition: BattleRuntimeComposition(
                runtime: runtime,
                onLaunchBattleVictory: { battle.presentLaunchVictory() }
            )
        )
    }
}
