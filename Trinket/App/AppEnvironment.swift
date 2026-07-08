import Foundation
import TrinketDesignSystem

struct AppEnvironment {
    static let shared = load()

    let launchTab: AppTab?
    let launchScreen: LaunchScreen?
    let resetState: Bool
    let seedTestProgress: Bool
    let disableCloudSync: Bool
    let disableAudio: Bool
    let persistSaveImmediately: Bool
    let appearanceOverride: TrinketDesign.AppAppearance?
    let completedStageIDs: [String]
    /// Scroll target ID for the Play map row id, used by UI tests.
    let mapScrollTarget: String?
    /// When set, overrides the default 1s battle tick interval in `BattleView`.
    /// One battle tick equals one second of player-facing duration.
    let battleTickInterval: TimeInterval?
    let storeName: String?

    static let defaultBattleTickInterval: TimeInterval = 1.0

    private init(
        launchTab: AppTab?,
        launchScreen: LaunchScreen?,
        resetState: Bool,
        seedTestProgress: Bool,
        disableCloudSync: Bool,
        disableAudio: Bool,
        persistSaveImmediately: Bool,
        appearanceOverride: TrinketDesign.AppAppearance?,
        completedStageIDs: [String],
        mapScrollTarget: String?,
        battleTickInterval: TimeInterval?,
        storeName: String?
    ) {
        self.launchTab = launchTab
        self.launchScreen = launchScreen
        self.resetState = resetState
        self.seedTestProgress = seedTestProgress
        self.disableCloudSync = disableCloudSync
        self.disableAudio = disableAudio
        self.persistSaveImmediately = persistSaveImmediately
        self.appearanceOverride = appearanceOverride
        self.completedStageIDs = completedStageIDs
        self.mapScrollTarget = mapScrollTarget
        self.battleTickInterval = battleTickInterval
        self.storeName = storeName
    }

    private static func load() -> AppEnvironment {
        parse(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    static func parse(arguments: [String], environment: [String: String]) -> AppEnvironment {
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
        let disableCloudSync: Bool
        #if targetEnvironment(simulator)
        disableCloudSync = arguments.contains("-disable-cloud-sync") || arguments.contains("-reset-state") || isRunningTests || !arguments.contains("-enable-cloud-sync")
        #else
        disableCloudSync = arguments.contains("-disable-cloud-sync") || arguments.contains("-reset-state") || isRunningTests
        #endif

        return AppEnvironment(
            launchTab: launchTab(from: arguments),
            launchScreen: launchScreen(from: arguments),
            resetState: arguments.contains("-reset-state"),
            seedTestProgress: arguments.contains("-seed-test-progress"),
            disableCloudSync: disableCloudSync,
            disableAudio: arguments.contains("-disable-audio"),
            persistSaveImmediately: arguments.contains("-persist-save-immediately"),
            appearanceOverride: appearanceOverride(from: arguments),
            completedStageIDs: completedStageIDs(from: arguments),
            mapScrollTarget: mapScrollTarget(from: arguments),
            battleTickInterval: battleTickInterval(from: arguments),
            storeName: arguments.firstIndex(of: "-store-name").flatMap { idx in
                arguments.indices.contains(idx + 1) ? arguments[idx + 1] : nil
            }
        )
    }

    private static func launchTab(from arguments: [String]) -> AppTab? {
        guard let idx = arguments.firstIndex(of: "-selectedTab"),
              arguments.indices.contains(idx + 1)
        else { return nil }
        let val = arguments[idx + 1].lowercased()
        if val == "heroes" || val == "pets" || val == "inventory" || val == "search" {
            return .collection
        }
        return AppTab(rawValue: val)
    }

    private static func launchScreen(from arguments: [String]) -> LaunchScreen? {
        guard let idx = arguments.firstIndex(of: "-launch-screen"),
              arguments.indices.contains(idx + 1)
        else { return nil }
        let val = arguments[idx + 1]
        let parts = val.split(separator: ":", maxSplits: 1).map(String.init)
        let kind = parts[0].lowercased()
        let id = parts.count == 2 ? parts[1] : ""
        switch kind {
        case "hero" where !id.isEmpty: return .heroDetail(id)
        case "pet" where !id.isEmpty: return .petDetail(id)
        case "item" where !id.isEmpty: return .itemDetail(id)
        case "options": return .options
        case "battle": return .battle
        default: return nil
        }
    }

    private static func appearanceOverride(from arguments: [String]) -> TrinketDesign.AppAppearance? {
        guard let idx = arguments.firstIndex(of: "-appearance"),
              arguments.indices.contains(idx + 1)
        else { return nil }
        return TrinketDesign.AppAppearance(rawValue: arguments[idx + 1])
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

    private static func battleTickInterval(from arguments: [String]) -> TimeInterval? {
        guard let idx = arguments.lastIndex(of: "-battle-tick-interval"),
              arguments.indices.contains(idx + 1),
              let value = TimeInterval(arguments[idx + 1]),
              value > 0
        else { return nil }
        return value
    }
}
