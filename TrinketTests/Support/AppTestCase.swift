import TrinketPersistence
import XCTest
@testable import Trinket

@MainActor
class AppTestCase: XCTestCase {
    var directoryURL: URL!
    var suiteName: String!
    var userDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        let prefix = String(describing: type(of: self))
        suiteName = "\(prefix).\(UUID().uuidString)"
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: prefix)
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        userDefaults.removePersistentDomain(forName: suiteName)
        SaveTestSupport.removeTempDirectory(directoryURL)
        try await super.tearDown()
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
