import Foundation

struct AppEnvironment {
    static let shared = load()

    let launchTab: AppTab?
    let launchScreen: LaunchScreen?
    let resetState: Bool
    let seedTestProgress: Bool
    let disableCloudSync: Bool
    let disableAudio: Bool
    let themeOverride: TrinketDesign.AppTheme?
    let completedStageIDs: [String]
    /// When set, overrides the default 0.8s battle tick interval in `BattleView`.
    let battleTickInterval: TimeInterval?

    static let defaultBattleTickInterval: TimeInterval = 0.8
    static let testBattleTickInterval: TimeInterval = 0.05

    private init(
        launchTab: AppTab?,
        launchScreen: LaunchScreen?,
        resetState: Bool,
        seedTestProgress: Bool,
        disableCloudSync: Bool,
        disableAudio: Bool,
        themeOverride: TrinketDesign.AppTheme?,
        completedStageIDs: [String],
        battleTickInterval: TimeInterval?
    ) {
        self.launchTab = launchTab
        self.launchScreen = launchScreen
        self.resetState = resetState
        self.seedTestProgress = seedTestProgress
        self.disableCloudSync = disableCloudSync
        self.disableAudio = disableAudio
        self.themeOverride = themeOverride
        self.completedStageIDs = completedStageIDs
        self.battleTickInterval = battleTickInterval
    }

    private static func load() -> AppEnvironment {
        parse(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    static func parse(arguments: [String], environment: [String: String]) -> AppEnvironment {
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil

        return AppEnvironment(
            launchTab: launchTab(from: arguments),
            launchScreen: launchScreen(from: arguments),
            resetState: arguments.contains("-reset-state"),
            seedTestProgress: arguments.contains("-seed-test-progress"),
            disableCloudSync: arguments.contains("-disable-cloud-sync") || arguments.contains("-reset-state") || isRunningTests,
            disableAudio: arguments.contains("-disable-audio") || isRunningTests,
            themeOverride: themeOverride(from: arguments),
            completedStageIDs: completedStageIDs(from: arguments),
            battleTickInterval: battleTickInterval(from: arguments, isRunningTests: isRunningTests)
        )
    }

    private static func launchTab(from arguments: [String]) -> AppTab? {
        guard let idx = arguments.firstIndex(of: "-selectedTab"),
              arguments.indices.contains(idx + 1)
        else { return nil }
        let val = arguments[idx + 1].lowercased()
        if val == "heroes" || val == "pets" || val == "inventory" {
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

    private static func themeOverride(from arguments: [String]) -> TrinketDesign.AppTheme? {
        guard let idx = arguments.firstIndex(of: "-theme"),
              arguments.indices.contains(idx + 1)
        else { return nil }
        let val = arguments[idx + 1].lowercased()
        return TrinketDesign.AppTheme.allCases.first { $0.rawValue.lowercased() == val }
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

    private static func battleTickInterval(
        from arguments: [String],
        isRunningTests: Bool
    ) -> TimeInterval? {
        if let idx = arguments.firstIndex(of: "-battle-tick-interval"),
           arguments.indices.contains(idx + 1),
           let value = TimeInterval(arguments[idx + 1]),
           value > 0 {
            return value
        }
        if isRunningTests {
            return testBattleTickInterval
        }
        return nil
    }
}
