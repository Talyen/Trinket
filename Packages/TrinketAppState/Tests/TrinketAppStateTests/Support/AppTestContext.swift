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
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            throw CocoaError(.fileWriteUnknown)
        }
        self.userDefaults = userDefaults
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
        SaveTestSupport.removeTempDirectory(directoryURL)
    }

    @MainActor
    func makeEnvironment(arguments: [String] = []) -> AppEnvironment {
        AppEnvironment.parse(arguments: Self.defaultTestArguments + arguments, environment: [:])
    }

    @MainActor
    func makeOnboardingEnvironment() -> AppEnvironment {
        AppEnvironment.parse(
            arguments: ["-disable-cloud-sync", "-disable-audio"],
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
        let battle: any BattleRuntime = battleRuntime ?? BattleSession(presentationEnvironment: .silent)
        let resolvedSave = try playerSave ?? sharedPlayerSave(resetState: parsed.resetState)
        let state = try AppState(
            environment: parsed,
            playerSave: resolvedSave,
            userDefaults: userDefaults,
            makeBattleRuntime: { _ in battle },
        )
        lastBattle = battle as? BattleSession
        lastBattle?.openingHandDrawStagger = .zero
        return state
    }

    @MainActor
    func makeAppState(environment: AppEnvironment) throws -> AppState {
        let battle = BattleSession(presentationEnvironment: .silent)
        let state = try AppState(
            environment: environment,
            playerSave: sharedPlayerSave(resetState: environment.resetState),
            userDefaults: userDefaults,
            makeBattleRuntime: { _ in battle },
        )
        lastBattle = battle
        battle.openingHandDrawStagger = .zero
        return state
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
    private func sharedPlayerSave(resetState: Bool) throws -> PlayerSaveStore {
        if let cachedPlayerSave, !resetState {
            return cachedPlayerSave
        }
        let store = try PlayerSaveStore(
            storeURL: SaveTestSupport.makeStoreURL(directoryURL: directoryURL),
            disableCloudSync: true,
            resetState: resetState,
            inMemoryOnly: !resetState,
            persistSaveImmediately: true,
        )
        if !resetState {
            cachedPlayerSave = store
        }
        return store
    }
}
