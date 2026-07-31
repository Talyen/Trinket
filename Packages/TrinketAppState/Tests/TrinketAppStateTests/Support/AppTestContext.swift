import Foundation
import TrinketBattleFeature
import TrinketBattleRuntime
import TrinketFeatureSupport
import TrinketPersistence
import TrinketTestSupport
@testable import TrinketAppState

final class AppTestContext {
    let directoryURL: URL
    let suiteName: String
    let userDefaults: UserDefaults
    let shellSessionURL: URL
    private(set) var lastBattle: BattleSession?

    private static let defaultTestArguments = [
        "-disable-cloud-sync",
        "-disable-audio",
        "-persist-save-immediately",
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
    func makeShellSessionStore(environment: AppEnvironment) throws -> PlayerShellSessionStore {
        try PlayerShellSessionStore(
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
    ) throws -> AppState {
        let parsed = AppEnvironment.parse(
            arguments: Self.defaultTestArguments + arguments,
            environment: environment
        )
        let battle = BattleSession(presentationEnvironment: .silent)
        let state = try AppState(
            environment: parsed,
            playerSave: playerSave ?? PlayerSaveStore(
                storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
                disableCloudSync: true,
                resetState: parsed.resetState,
                persistSaveImmediately: parsed.persistSaveImmediately
            ),
            shellSessionStore: makeShellSessionStore(environment: parsed),
            userDefaults: userDefaults,
            battleComposition: BattleRuntimeComposition(
                runtime: battle,
                onLaunchBattleVictory: { battle.presentLaunchVictory() }
            )
        )
        lastBattle = battle
        // Unit tests expect a full hand before the next statement; skip paced deal.
        battle.openingHandDrawStagger = 0
        return state
    }

    @MainActor
    func makeAppState(environment: AppEnvironment) throws -> AppState {
        let battle = BattleSession(presentationEnvironment: .silent)
        let state = try AppState(
            environment: environment,
            playerSave: PlayerSaveStore(
                storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
                disableCloudSync: true,
                resetState: environment.resetState,
                persistSaveImmediately: environment.persistSaveImmediately
            ),
            shellSessionStore: makeShellSessionStore(environment: environment),
            userDefaults: userDefaults,
            battleComposition: BattleRuntimeComposition(
                runtime: battle,
                onLaunchBattleVictory: { battle.presentLaunchVictory() }
            )
        )
        lastBattle = battle
        battle.openingHandDrawStagger = 0
        return state
    }

    @MainActor
    func makePlaySession(
        arguments: [String] = [],
        environment: [String: String] = [:],
        playerSave: PlayerSaveStore? = nil
    ) throws -> PlaySession {
        try makeAppState(
            arguments: arguments,
            environment: environment,
            playerSave: playerSave
        ).play
    }

    @MainActor
    func makePlaySession(environment: AppEnvironment) throws -> PlaySession {
        try makeAppState(environment: environment).play
    }
}

extension PlaySession {
    var uiBattle: BattleSession {
        guard let battle = battle as? BattleSession else {
            fatalError("AppState tests require the BattleFeature runtime")
        }
        return battle
    }
}
