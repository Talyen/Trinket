import Foundation
import TrinketBattleFeature
import TrinketFeatureSupport

public struct AppEnvironment: Sendable {
    public static let shared = load()

    public let launchTab: AppTab?
    public let launchScreen: LaunchScreen?
    public let resetState: Bool
    public let seedTestProgress: Bool
    public let disableCloudSync: Bool
    public let disableAudio: Bool
    public let persistSaveImmediately: Bool
    public let completedStageIDs: [String]
    /// Test-only deterministic recruit event selected for the Mystery deep link.
    public let mysteryRecruitEventID: String?
    /// Scroll target ID for the Play map row id, used by UI tests.
    public let mapScrollTarget: String?
    /// When set, overrides the default 1s battle tick interval in `BattleView`.
    /// One battle tick equals one second of player-facing duration.
    public let battleTickInterval: TimeInterval?
    public let storeName: String?
    /// DEBUG frame-pacing sampler + accessibility metrics node (UI soak / hitch gate).
    public let enableFrameMetrics: Bool
    /// DEBUG-only deterministic workload driver. Presence changes stimuli, never rendering fidelity.
    public let battlePerformanceScenario: BattlePerformanceScenario?

    private init(
        launchTab: AppTab?,
        launchScreen: LaunchScreen?,
        resetState: Bool,
        seedTestProgress: Bool,
        disableCloudSync: Bool,
        disableAudio: Bool,
        persistSaveImmediately: Bool,
        completedStageIDs: [String],
        mysteryRecruitEventID: String?,
        mapScrollTarget: String?,
        battleTickInterval: TimeInterval?,
        storeName: String?,
        enableFrameMetrics: Bool,
        battlePerformanceScenario: BattlePerformanceScenario?
    ) {
        self.launchTab = launchTab
        self.launchScreen = launchScreen
        self.resetState = resetState
        self.seedTestProgress = seedTestProgress
        self.disableCloudSync = disableCloudSync
        self.disableAudio = disableAudio
        self.persistSaveImmediately = persistSaveImmediately
        self.completedStageIDs = completedStageIDs
        self.mysteryRecruitEventID = mysteryRecruitEventID
        self.mapScrollTarget = mapScrollTarget
        self.battleTickInterval = battleTickInterval
        self.storeName = storeName
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
            disableCloudSync: disableCloudSync,
            disableAudio: arguments.contains("-disable-audio"),
            persistSaveImmediately: arguments.contains("-persist-save-immediately"),
            completedStageIDs: completedStageIDs(from: arguments),
            mysteryRecruitEventID: argumentValue(after: "-mystery-recruit-event", in: arguments),
            mapScrollTarget: mapScrollTarget(from: arguments),
            battleTickInterval: battleTickInterval(from: arguments),
            storeName: arguments.firstIndex(of: "-store-name").flatMap { idx in
                arguments.indices.contains(idx + 1) ? arguments[idx + 1] : nil
            },
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
        let val = arguments[idx + 1]
        // split omits empty subsequences, so "" / ":" yield no parts — never index [0].
        let parts = val.split(separator: ":", maxSplits: 1).map(String.init)
        guard let kind = parts.first?.lowercased() else { return nil }
        let id = parts.count == 2 ? parts[1] : ""
        switch kind {
        case "hero" where !id.isEmpty: return .heroDetail(id)
        case "companion" where !id.isEmpty: return .companionDetail(id)
        case "item" where !id.isEmpty: return .itemDetail(id)
        case "options": return .options
        case "battle": return .battle
        case "battle-victory": return .battleVictory
        case "shop": return .shop
        case "mystery": return .mystery
        case "labyrinth": return .labyrinth
        case "labyrinth-map": return .labyrinthMap
        default: return nil
        }
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

    private static func mapScrollTarget(from arguments: [String]) -> String? {
        guard let idx = arguments.firstIndex(of: "-map-scroll-target"),
              arguments.indices.contains(idx + 1)
        else { return nil }
        let target = arguments[idx + 1]
        return target.isEmpty ? nil : target
    }

    private static func argumentValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1)
        else { return nil }
        let value = arguments[index + 1]
        return value.isEmpty ? nil : value
    }

    private static func battleTickInterval(from arguments: [String]) -> TimeInterval? {
        guard let idx = arguments.lastIndex(of: "-battle-tick-interval"),
              arguments.indices.contains(idx + 1),
              let value = TimeInterval(arguments[idx + 1]),
              value > 0
        else { return nil }
        return value
    }
}
