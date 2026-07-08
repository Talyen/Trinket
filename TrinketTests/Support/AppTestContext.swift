import Foundation
import TrinketPersistence
@testable import Trinket

final class AppTestContext {
    let directoryURL: URL
    let suiteName: String
    let userDefaults: UserDefaults
    let shellSessionURL: URL

    private static let defaultTestArguments = [
        "-disable-cloud-sync",
        "-disable-audio",
        "-persist-save-immediately"
    ]

    init() throws {
        let prefix = "AppTestContext"
        suiteName = "\(prefix).\(UUID().uuidString)"
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: prefix)
        shellSessionURL = directoryURL.appending(path: "shell-session.store")
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            throw CocoaError(.fileWriteUnknown)
        }
        self.userDefaults = userDefaults
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        SaveTestSupport.removeTempDirectory(directoryURL)
    }

    @MainActor
    func makeEnvironment(arguments: [String] = []) -> AppEnvironment {
        AppEnvironment.parse(arguments: Self.defaultTestArguments + arguments, environment: [:])
    }

    @MainActor
    func makeShellSessionStore(environment: AppEnvironment) -> PlayerShellSessionStore {
        PlayerShellSessionStore(
            storeURL: shellSessionURL,
            resetState: environment.resetState,
            legacyUserDefaults: userDefaults
        )
    }

    @MainActor
    func makeAppState(
        arguments: [String] = [],
        environment: [String: String] = [:],
        playerSave: PlayerSaveStore? = nil
    ) -> AppState {
        let parsed = AppEnvironment.parse(
            arguments: Self.defaultTestArguments + arguments,
            environment: environment
        )
        return AppState(
            environment: parsed,
            playerSave: playerSave ?? PlayerSaveStore(
                storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
                disableCloudSync: true,
                resetState: parsed.resetState,
                persistSaveImmediately: parsed.persistSaveImmediately
            ),
            shellSessionStore: makeShellSessionStore(environment: parsed),
            userDefaults: userDefaults
        )
    }

    @MainActor
    func makeAppState(environment: AppEnvironment) -> AppState {
        AppState(
            environment: environment,
            playerSave: PlayerSaveStore(
                storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
                disableCloudSync: true,
                resetState: environment.resetState,
                persistSaveImmediately: environment.persistSaveImmediately
            ),
            shellSessionStore: makeShellSessionStore(environment: environment),
            userDefaults: userDefaults
        )
    }
}
