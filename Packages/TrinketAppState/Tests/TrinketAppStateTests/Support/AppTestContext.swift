import BattleEngine
import Foundation
import TrinketBattleFeature
import TrinketContent
import TrinketContentTestSupport
import TrinketFeatureSupport
import TrinketPersistence
import TrinketPersistenceTestSupport
@testable import TrinketAppState

final class AppTestContext {
    /// Shared fixture: temp directory + `UserDefaults` suite (torn down with
    /// the context). Every state defaults to `-disable-cloud-sync
    /// -disable-audio -skip-starter-selection`, full-game access, and a silent
    /// battle runtime wired with the production progression closures.
    /// `makeOnboardingEnvironment` is the same minus `-skip-starter-selection`.
    /// Saves are cached per context and reused unless `-reset-state` is passed;
    /// `lastBattle` is the injected runtime, invalid when a custom
    /// `battleRuntime` is supplied.
    let directoryURL: URL
    let suiteName: String
    let userDefaults: UserDefaults
    private(set) var lastBattle: BattleSession?
    var progressionDate: @MainActor () -> Date = { Date() }

    private var cachedPlayerSave: PlayerSaveStore?
    private let ownsDirectory: Bool

    private static let defaultTestArguments = [
        "-disable-cloud-sync",
        "-disable-audio",
        "-skip-starter-selection",
    ]

    init(directoryURL: URL? = nil) throws {
        let prefix = "AppTestContext"
        suiteName = "\(prefix).\(UUID().uuidString)"
        ownsDirectory = directoryURL == nil
        self.directoryURL = try directoryURL ?? SaveTestSupport.makeTempDirectory(prefix: prefix)
        try FileManager.default.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
        userDefaults = try SaveTestSupport.makeUserDefaults(suiteName: suiteName)
    }

    deinit {
        SaveTestSupport.removeUserDefaults(suiteName: suiteName, defaults: userDefaults)
        if ownsDirectory {
            SaveTestSupport.removeTempDirectory(directoryURL)
        }
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
        contentAccess: ContentAccessPolicy = .fullGame,
    ) throws -> AppState {
        let parsed = AppEnvironment.parse(
            arguments: Self.defaultTestArguments + arguments,
            environment: environment,
        )
        let battle = battleRuntime ?? BattleSession(presentationEnvironment: .silent)
        let resolvedSave = try playerSave ?? sharedPlayerSave(resetState: parsed.resetState)
        return try buildAppState(environment: parsed, playerSave: resolvedSave, battle: battle, contentAccess: contentAccess)
    }

    @MainActor
    func makeAppState(
        environment: AppEnvironment,
        playerSave: PlayerSaveStore? = nil,
        battleRuntime: (any BattleRuntime)? = nil,
        contentAccess: ContentAccessPolicy = .fullGame,
    ) throws -> AppState {
        try buildAppState(
            environment: environment,
            playerSave: playerSave ?? sharedPlayerSave(resetState: environment.resetState),
            battle: battleRuntime ?? BattleSession(presentationEnvironment: .silent),
            contentAccess: contentAccess,
        )
    }

    @MainActor
    func makePlaySession(
        arguments: [String] = [],
        environment: [String: String] = [:],
        playerSave: PlayerSaveStore? = nil,
        battleRuntime: (any BattleRuntime)? = nil,
        contentAccess: ContentAccessPolicy = .fullGame,
    ) throws -> PlaySession {
        try makeAppState(
            arguments: arguments,
            environment: environment,
            playerSave: playerSave,
            battleRuntime: battleRuntime,
            contentAccess: contentAccess,
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
        contentAccess: ContentAccessPolicy = .fullGame,
    ) throws -> AppState {
        let progressionDate = progressionDate
        playerSave.contentAccess = contentAccess
        let state = try AppState(
            environment: environment,
            playerSave: playerSave,
            userDefaults: userDefaults,
            makeBattleRuntime: { _ in battle },
            configureBattleRuntime: { runtime, play in
                guard let session = runtime as? BattleSession else { return }
                session.configureProgression(
                    presentation: { [weak play] configuration in
                        play?.battlePresentation(for: configuration)
                    },
                    settleRewards: { [weak play] configuration, gold in
                        play?.settleBattleRewards(configuration, battleGold: gold, at: progressionDate())
                    },
                    completeVictory: { [weak play] configuration, gold, settlement, defersExit in
                        play?.completeActiveBattle(
                            configuration, battleGold: gold,
                            settlement: settlement,
                            defersPresentationExit: defersExit,
                        ) ?? .unavailable
                    },
                    settleDefeat: { [weak play] configuration in
                        play?.settleDefeatRewards(configuration, at: progressionDate())
                    },
                    completeDefeat: { [weak play] configuration, settlement, action in
                        play?.completeDefeat(configuration, settlement: settlement, action: action) ?? .unavailable
                    },
                    finishPresentation: { [weak play] id in
                        play?.finishBattleRewardPresentation(configurationID: id)
                    },
                )
            },
        )
        lastBattle = battle as? BattleSession
        return state
    }

    @MainActor
    private func sharedPlayerSave(resetState: Bool) throws -> PlayerSaveStore {
        if let cachedPlayerSave, !resetState {
            return cachedPlayerSave
        }
        let store = try SaveTestSupport.makeSaveStore(
            directoryURL: directoryURL,
            resetState: resetState,
            inMemoryOnly: !resetState,
        )
        if !resetState {
            cachedPlayerSave = store
        }
        return store
    }
}
