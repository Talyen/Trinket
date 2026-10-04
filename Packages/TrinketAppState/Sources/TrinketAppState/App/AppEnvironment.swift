import BattleEngine
import Foundation

public struct AppEnvironment: Sendable {
    public static let shared = load()

    public let launchTab: AppTab?
    public let launchScreen: LaunchScreen?
    public let resetState: Bool
    public let seedTestProgress: Bool
    let equipmentPickerFixture: Bool
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
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            let value = arguments[index + 1]
            return value.isEmpty ? nil : value
        }

        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
        let equipmentPickerFixture: Bool
        #if DEBUG
        equipmentPickerFixture = arguments.contains("-equipment-picker-fixture") && arguments.contains("-seed-test-progress")
        #else
        equipmentPickerFixture = false
        #endif
        let cloudSyncRequested: Bool
        let launchPreparationDelay: TimeInterval
        #if DEBUG
        let requestedDelay = value(after: "-launch-preparation-delay")
            .flatMap(TimeInterval.init) ?? 0
        launchPreparationDelay = requestedDelay.isFinite && requestedDelay > 0 ? requestedDelay : 0
        let battlePerformanceScenario = value(after: "-battle-performance-scenario")
            .flatMap(BattlePerformanceScenario.init(rawValue:))
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
            launchTab: value(after: "-selectedTab").flatMap(launchTab),
            launchScreen: value(after: "-launch-screen").flatMap(LaunchScreen.parse),
            resetState: arguments.contains("-reset-state"),
            seedTestProgress: arguments.contains("-seed-test-progress"),
            equipmentPickerFixture: equipmentPickerFixture,
            skipStarterSelection: arguments.contains("-skip-starter-selection"),
            skipOnboardingCeremony: arguments.contains("-skip-onboarding-ceremony"),
            disableCloudSync: disableCloudSync,
            disableAudio: arguments.contains("-disable-audio"),
            completedStageIDs: (value(after: "-completed-stages") ?? "").split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            mysteryRecruitEventID: value(after: "-mystery-recruit-event"),
            storeName: value(after: "-store-name"),
            battleTickInterval: value(after: "-battle-tick-interval")
                .flatMap(TimeInterval.init)
                .flatMap { $0.isFinite && $0 > 0 ? $0 : nil },
            launchPreparationDelay: launchPreparationDelay,
            startingGold: value(after: "-starting-gold")
                .flatMap(Int.init)
                .flatMap { $0 >= 0 ? $0 : nil },
            enableFrameMetrics: arguments.contains("-enable-frame-metrics"),
            battlePerformanceScenario: battlePerformanceScenario,
        )
    }

    private static func launchTab(_ raw: String) -> AppTab? {
        let val = raw.lowercased()
        if val == "heroes" || val == "companions" || val == "inventory" || val == "search" {
            return .collection
        }
        return AppTab(rawValue: val)
    }
}
