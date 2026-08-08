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
        let battle = BattleSession(presentationEnvironment: .silent)
        return try AppState(
            environment: makeEnvironment(arguments: arguments),
            playerSave: playerSave ?? SaveTestSupport.makeSaveStore(directoryURL: directoryURL),
            userDefaults: userDefaults,
            battleRuntime: battle
        )
    }
}
