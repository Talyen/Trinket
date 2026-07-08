import Foundation
import TrinketPersistence
import TrinketTestSupport
@testable import Trinket

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
        try AppState(
            environment: makeEnvironment(arguments: arguments),
            playerSave: playerSave ?? SaveTestSupport.makeSaveStore(directoryURL: directoryURL),
            userDefaults: userDefaults
        )
    }
}
