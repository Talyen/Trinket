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
    private(set) var lastBattle: BattleSession?

    /// Shared across `makeAppState` calls in this context so suite setup does not
    /// reopen SwiftData for every trivial assertion. Disk + persist-immediately stay
    /// explicit for reload-survival tests that pass their own `playerSave`.
    private var cachedPlayerSave: PlayerSaveStore?

    private static let defaultTestArguments = [
        "-disable-cloud-sync",
        "-disable-audio",
    ]

    init() throws {
        let prefix = "AppTestContext"
        suiteName = "\(prefix).\(UUID().uuidString)"
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: prefix)
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
    func makeAppState(
        arguments: [String] = [],
        environment: [String: String] = [:],
        playerSave: PlayerSaveStore? = nil,
        battleRuntime: (any BattleRuntime)? = nil
    ) throws -> AppState {
        let parsed = AppEnvironment.parse(
            arguments: Self.defaultTestArguments + arguments,
            environment: environment
        )
        let battle: any BattleRuntime = battleRuntime ?? BattleSession(presentationEnvironment: .silent)
        let resolvedSave = try playerSave ?? sharedPlayerSave(resetState: parsed.resetState)
        let state = try AppState(
            environment: parsed,
            playerSave: resolvedSave,
            userDefaults: userDefaults,
            battleRuntime: battle
        )
        lastBattle = battle as? BattleSession
        // Unit tests expect a full hand before the next statement; skip paced deal.
        lastBattle?.openingHandDrawStagger = 0
        return state
    }

    @MainActor
    func makeAppState(environment: AppEnvironment) throws -> AppState {
        let battle = BattleSession(presentationEnvironment: .silent)
        let state = try AppState(
            environment: environment,
            playerSave: sharedPlayerSave(resetState: environment.resetState),
            userDefaults: userDefaults,
            battleRuntime: battle
        )
        lastBattle = battle
        battle.openingHandDrawStagger = 0
        return state
    }

    @MainActor
    func makePlaySession(
        arguments: [String] = [],
        environment: [String: String] = [:],
        playerSave: PlayerSaveStore? = nil,
        battleRuntime: (any BattleRuntime)? = nil
    ) throws -> PlaySession {
        try makeAppState(
            arguments: arguments,
            environment: environment,
            playerSave: playerSave,
            battleRuntime: battleRuntime
        ).play
    }

    @MainActor
    func makePlaySession(environment: AppEnvironment) throws -> PlaySession {
        try makeAppState(environment: environment).play
    }

    @MainActor
    private func sharedPlayerSave(resetState: Bool) throws -> PlayerSaveStore {
        if let cachedPlayerSave, !resetState {
            return cachedPlayerSave
        }
        // Default path is in-memory + reused. `-reset-state` opens the temp disk URL so
        // wipe/reload assertions observe the same store file as explicit disk tests.
        let store = try PlayerSaveStore(
            storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
            disableCloudSync: true,
            resetState: resetState,
            inMemoryOnly: !resetState,
            persistSaveImmediately: resetState
        )
        if !resetState {
            cachedPlayerSave = store
        }
        return store
    }
}
