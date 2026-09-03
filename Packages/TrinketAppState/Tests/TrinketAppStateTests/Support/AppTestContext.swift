import BattleEngine
import Foundation
import TrinketBattleFeature
import TrinketFeatureSupport
import TrinketPersistence
import TrinketPersistenceTestSupport
import TrinketTestSupport
@testable import TrinketAppState

final class AppTestContext {
    let directoryURL: URL
    let suiteName: String
    let userDefaults: UserDefaults
    private(set) var lastBattle: BattleSession?

    private var cachedPlayerSave: PlayerSaveStore?

    private static let defaultTestArguments = [
        "-disable-cloud-sync",
        "-disable-audio",
        "-skip-starter-selection",
    ]

    init() throws {
        let prefix = "AppTestContext"
        suiteName = "\(prefix).\(UUID().uuidString)"
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: prefix)
        userDefaults = try SaveTestSupport.makeUserDefaults(suiteName: suiteName)
    }

    deinit {
        SaveTestSupport.removeUserDefaults(suiteName: suiteName, defaults: userDefaults)
        SaveTestSupport.removeTempDirectory(directoryURL)
    }

    @MainActor
    func makeEnvironment(arguments: [String] = []) -> AppEnvironment {
        AppEnvironment.parse(arguments: Self.defaultTestArguments + arguments, environment: [:])
    }

    @MainActor
    func makeOnboardingEnvironment() -> AppEnvironment {
        AppEnvironment.parse(
            arguments: Self.defaultTestArguments.filter { $0 != "-skip-starter-selection" },
            environment: [:],
        )
    }

    @MainActor
    func makeAppState(
        arguments: [String] = [],
        environment: [String: String] = [:],
        playerSave: PlayerSaveStore? = nil,
        battleRuntime: (any BattleRuntime)? = nil,
    ) throws -> AppState {
        let parsed = AppEnvironment.parse(
            arguments: Self.defaultTestArguments + arguments,
            environment: environment,
        )
        let battle = battleRuntime ?? BattleSession(presentationEnvironment: .silent)
        let resolvedSave = try playerSave ?? sharedPlayerSave(resetState: parsed.resetState)
        return try buildAppState(environment: parsed, playerSave: resolvedSave, battle: battle)
    }

    @MainActor
    func makeAppState(environment: AppEnvironment) throws -> AppState {
        try buildAppState(
            environment: environment,
            playerSave: sharedPlayerSave(resetState: environment.resetState),
            battle: BattleSession(presentationEnvironment: .silent),
        )
    }

    @MainActor
    func makePlaySession(
        arguments: [String] = [],
        environment: [String: String] = [:],
        playerSave: PlayerSaveStore? = nil,
        battleRuntime: (any BattleRuntime)? = nil,
    ) throws -> PlaySession {
        try makeAppState(
            arguments: arguments,
            environment: environment,
            playerSave: playerSave,
            battleRuntime: battleRuntime,
        ).play
    }

    @MainActor
    func makePlaySession(environment: AppEnvironment) throws -> PlaySession {
        try makeAppState(environment: environment).play
    }

    @MainActor
    private func buildAppState(
        environment: AppEnvironment,
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
    ) throws -> AppState {
        let state = try AppState(
            environment: environment,
            playerSave: playerSave,
            userDefaults: userDefaults,
            makeBattleRuntime: { _ in battle },
        )
        lastBattle = battle as? BattleSession
        lastBattle?.openingHandDrawStagger = .zero
        return state
    }

    @MainActor
    private func sharedPlayerSave(resetState: Bool) throws -> PlayerSaveStore {
        if let cachedPlayerSave, !resetState {
            return cachedPlayerSave
        }
        let store = try SaveTestSupport.makeSaveStore(
            directoryURL: directoryURL,
            persistImmediately: true,
            resetState: resetState,
            inMemoryOnly: !resetState,
        )
        if !resetState {
            cachedPlayerSave = store
        }
        return store
    }
}
