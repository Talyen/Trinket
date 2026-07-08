import Foundation
import TrinketPersistence
@testable import Trinket

@MainActor
final class AppTestContext {
    let directoryURL: URL
    let suiteName: String
    let userDefaults: UserDefaults

    init() throws {
        let prefix = "AppTestContext"
        suiteName = "\(prefix).\(UUID().uuidString)"
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: prefix)
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
        SaveTestSupport.removeTempDirectory(directoryURL)
    }

    func makeEnvironment(arguments: [String] = []) -> AppEnvironment {
        AppEnvironment.parse(arguments: arguments, environment: [:])
    }

    func makeAppState(
        arguments: [String] = [],
        environment: [String: String] = [:],
        playerSave: PlayerSaveStore? = nil
    ) -> AppState {
        var resolvedEnvironment = environment
        resolvedEnvironment["XCTestConfigurationFilePath"] = "/tmp/xctest"
        let parsed = AppEnvironment.parse(arguments: arguments, environment: resolvedEnvironment)
        return AppState(
            environment: parsed,
            playerSave: playerSave ?? PlayerSaveStore(
                storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
                disableCloudSync: true,
                resetState: parsed.resetState
            ),
            userDefaults: userDefaults
        )
    }

    func makeAppState(environment: AppEnvironment) -> AppState {
        AppState(
            environment: environment,
            playerSave: PlayerSaveStore(
                storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
                disableCloudSync: true,
                resetState: environment.resetState
            ),
            userDefaults: userDefaults
        )
    }
}
