import Foundation
import BattleEngine

public struct AppEnvironment: Sendable {
    public static let shared = load()

    public let launchTab: AppTab?
    public let launchScreen: LaunchScreen?
    public let resetState: Bool
    public let seedTestProgress: Bool
    public let skipStarterSelection: Bool
    public let skipOnboardingCeremony: Bool
    public let disableCloudSync: Bool
    public let disableAudio: Bool
    public let persistSaveImmediately: Bool
    public let completedStageIDs: [String]
    /// Test-only deterministic recruit event selected for the Mystery deep link.
    public let mysteryRecruitEventID: String?
    public let storeName: String?
    /// Test-only override of the battle auto-end cadence (UI anti-flake contract).
    public let battleTickInterval: TimeInterval?
    /// Test-only gold balance granted after seeding (shop-purchase UI journeys).
    public let startingGold: Int?
    /// DEBUG frame-pacing sampler + accessibility metrics node (UI soak / hitch gate).
    public let enableFrameMetrics: Bool
    /// DEBUG-only deterministic workload driver. Presence changes stimuli, never rendering fidelity.
    public let battlePerformanceScenario: BattlePerformanceScenario?

    private init(
        launchTab: AppTab?,
        launchScreen: LaunchScreen?,
        resetState: Bool,
        seedTestProgress: Bool,
        skipStarterSelection: Bool,
        skipOnboardingCeremony: Bool,
        disableCloudSync: Bool,
        disableAudio: Bool,
        persistSaveImmediately: Bool,
        completedStageIDs: [String],
        mysteryRecruitEventID: String?,
        storeName: String?,
        battleTickInterval: TimeInterval?,
        startingGold: Int?,
        enableFrameMetrics: Bool,
        battlePerformanceScenario: BattlePerformanceScenario?
    ) {
        self.launchTab = launchTab
        self.launchScreen = launchScreen
        self.resetState = resetState
        self.seedTestProgress = seedTestProgress
        self.skipStarterSelection = skipStarterSelection
        self.skipOnboardingCeremony = skipOnboardingCeremony
        self.disableCloudSync = disableCloudSync
        self.disableAudio = disableAudio
        self.persistSaveImmediately = persistSaveImmediately
        self.completedStageIDs = completedStageIDs
        self.mysteryRecruitEventID = mysteryRecruitEventID
        self.storeName = storeName
        self.battleTickInterval = battleTickInterval
        self.startingGold = startingGold
        self.enableFrameMetrics = enableFrameMetrics
        self.battlePerformanceScenario = battlePerformanceScenario
    }

    private static func load() -> Self {
        parse(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    public static func parse(arguments: [String], environment: [String: String]) -> Self {
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
        let disableCloudSync: Bool
        #if DEBUG
        let battlePerformanceScenario = argumentValue(
            after: "-battle-performance-scenario",
            in: arguments
        ).flatMap(BattlePerformanceScenario.init(rawValue:))
        #else
        let battlePerformanceScenario: BattlePerformanceScenario? = nil
        #endif
        // F1 ship posture: CloudKit off unless explicitly enabled (device + simulator).
        disableCloudSync = arguments.contains("-disable-cloud-sync")
            || arguments.contains("-reset-state")
            || isRunningTests
            || !arguments.contains("-enable-cloud-sync")

        return Self(
            launchTab: launchTab(from: arguments),
            launchScreen: launchScreen(from: arguments),
            resetState: arguments.contains("-reset-state"),
            seedTestProgress: arguments.contains("-seed-test-progress"),
            skipStarterSelection: arguments.contains("-skip-starter-selection"),
            skipOnboardingCeremony: arguments.contains("-skip-onboarding-ceremony"),
            disableCloudSync: disableCloudSync,
            disableAudio: arguments.contains("-disable-audio"),
            persistSaveImmediately: !arguments.contains("-defer-persistence"),
            completedStageIDs: completedStageIDs(from: arguments),
            mysteryRecruitEventID: argumentValue(after: "-mystery-recruit-event", in: arguments),
            storeName: arguments.firstIndex(of: "-store-name").flatMap { idx in
                arguments.indices.contains(idx + 1) ? arguments[idx + 1] : nil
            },
            battleTickInterval: argumentValue(after: "-battle-tick-interval", in: arguments)
                .flatMap(TimeInterval.init),
            startingGold: argumentValue(after: "-starting-gold", in: arguments)
                .flatMap(Int.init),
            enableFrameMetrics: arguments.contains("-enable-frame-metrics"),
            battlePerformanceScenario: battlePerformanceScenario
        )
    }

    private static func launchTab(from arguments: [String]) -> AppTab? {
        guard let idx = arguments.firstIndex(of: "-selectedTab"),
              arguments.indices.contains(idx + 1)
        else { return nil }
        let val = arguments[idx + 1].lowercased()
        if val == "heroes" || val == "companions" || val == "inventory" || val == "search" {
            return .collection
        }
        return AppTab(rawValue: val)
    }

    private static func launchScreen(from arguments: [String]) -> LaunchScreen? {
        guard let idx = arguments.firstIndex(of: "-launch-screen"),
              arguments.indices.contains(idx + 1)
        else { return nil }
        return LaunchScreen.parse(arguments[idx + 1])
    }

    private static func completedStageIDs(from arguments: [String]) -> [String] {
        guard let idx = arguments.firstIndex(of: "-completed-stages"),
              arguments.indices.contains(idx + 1)
        else { return [] }
        return arguments[idx + 1]
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func argumentValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1)
        else { return nil }
        let value = arguments[index + 1]
        return value.isEmpty ? nil : value
    }
}
