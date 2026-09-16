import BattleEngine
import Foundation

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
    public let completedStageIDs: [String]
    public let mysteryRecruitEventID: String?
    public let storeName: String?
    public let battleTickInterval: TimeInterval?
    public let launchPreparationDelay: TimeInterval
    public let startingGold: Int?
    public let enableFrameMetrics: Bool
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
        completedStageIDs: [String],
        mysteryRecruitEventID: String?,
        storeName: String?,
        battleTickInterval: TimeInterval?,
        launchPreparationDelay: TimeInterval,
        startingGold: Int?,
        enableFrameMetrics: Bool,
        battlePerformanceScenario: BattlePerformanceScenario?,
    ) {
        self.launchTab = launchTab
        self.launchScreen = launchScreen
        self.resetState = resetState
        self.seedTestProgress = seedTestProgress
        self.skipStarterSelection = skipStarterSelection
        self.skipOnboardingCeremony = skipOnboardingCeremony
        self.disableCloudSync = disableCloudSync
        self.disableAudio = disableAudio
        self.completedStageIDs = completedStageIDs
        self.mysteryRecruitEventID = mysteryRecruitEventID
        self.storeName = storeName
        self.battleTickInterval = battleTickInterval
        self.launchPreparationDelay = launchPreparationDelay
        self.startingGold = startingGold
        self.enableFrameMetrics = enableFrameMetrics
        self.battlePerformanceScenario = battlePerformanceScenario
    }

    private static func load() -> Self {
        var arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        let key = "development.cloudSyncEnabled"
        let defaults = UserDefaults.standard
        if arguments.contains("-enable-cloud-sync") {
            defaults.set(true, forKey: key)
        }
        if arguments.contains("-disable-cloud-sync") {
            defaults.set(false, forKey: key)
        }
        if defaults.bool(forKey: key), !arguments.contains("-enable-cloud-sync") {
            arguments.append("-enable-cloud-sync")
        }
        #endif
        return parse(
            arguments: arguments,
            environment: ProcessInfo.processInfo.environment,
            cloudSyncEnabledByDefault: Bundle.main.object(forInfoDictionaryKey: "TrinketCloudSyncEnabled") as? String == "YES",
        )
    }

    public static func parse(
        arguments: [String],
        environment: [String: String],
        cloudSyncEnabledByDefault: Bool = false,
    ) -> Self {
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
        let cloudSyncRequested: Bool
        let launchPreparationDelay: TimeInterval
        #if DEBUG
        let requestedDelay = argumentValue(after: "-launch-preparation-delay", in: arguments)
            .flatMap(TimeInterval.init) ?? 0
        launchPreparationDelay = requestedDelay.isFinite && requestedDelay > 0 ? requestedDelay : 0
        let battlePerformanceScenario = argumentValue(
            after: "-battle-performance-scenario",
            in: arguments,
        ).flatMap(BattlePerformanceScenario.init(rawValue:))
        cloudSyncRequested = cloudSyncEnabledByDefault || arguments.contains("-enable-cloud-sync")
        #else
        launchPreparationDelay = 0
        let battlePerformanceScenario: BattlePerformanceScenario? = nil
        cloudSyncRequested = cloudSyncEnabledByDefault
        #endif
        let disableCloudSync = !cloudSyncRequested
            || arguments.contains("-disable-cloud-sync")
            || arguments.contains("-reset-state")
            || arguments.contains("-seed-test-progress")
            || isRunningTests

        return Self(
            launchTab: launchTab(from: arguments),
            launchScreen: launchScreen(from: arguments),
            resetState: arguments.contains("-reset-state"),
            seedTestProgress: arguments.contains("-seed-test-progress"),
            skipStarterSelection: arguments.contains("-skip-starter-selection"),
            skipOnboardingCeremony: arguments.contains("-skip-onboarding-ceremony"),
            disableCloudSync: disableCloudSync,
            disableAudio: arguments.contains("-disable-audio"),
            completedStageIDs: completedStageIDs(from: arguments),
            mysteryRecruitEventID: argumentValue(after: "-mystery-recruit-event", in: arguments),
            storeName: argumentValue(after: "-store-name", in: arguments),
            battleTickInterval: argumentValue(after: "-battle-tick-interval", in: arguments)
                .flatMap(TimeInterval.init)
                .flatMap { $0.isFinite && $0 > 0 ? $0 : nil },
            launchPreparationDelay: launchPreparationDelay,
            startingGold: argumentValue(after: "-starting-gold", in: arguments)
                .flatMap(Int.init)
                .flatMap { $0 >= 0 ? $0 : nil },
            enableFrameMetrics: arguments.contains("-enable-frame-metrics"),
            battlePerformanceScenario: battlePerformanceScenario,
        )
    }

    private static func launchTab(from arguments: [String]) -> AppTab? {
        guard let raw = argumentValue(after: "-selectedTab", in: arguments) else { return nil }
        let val = raw.lowercased()
        if val == "heroes" || val == "companions" || val == "inventory" || val == "search" {
            return .collection
        }
        return AppTab(rawValue: val)
    }

    private static func launchScreen(from arguments: [String]) -> LaunchScreen? {
        argumentValue(after: "-launch-screen", in: arguments).flatMap(LaunchScreen.parse)
    }

    private static func completedStageIDs(from arguments: [String]) -> [String] {
        guard let raw = argumentValue(after: "-completed-stages", in: arguments) else { return [] }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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
