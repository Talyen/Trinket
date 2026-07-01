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

    private init(
        launchTab: AppTab?,
        launchScreen: LaunchScreen?,
        resetState: Bool,
        seedTestProgress: Bool,
        disableCloudSync: Bool,
        disableAudio: Bool,
        themeOverride: TrinketDesign.AppTheme?,
        completedStageIDs: [String]
    ) {
        self.launchTab = launchTab
        self.launchScreen = launchScreen
        self.resetState = resetState
        self.seedTestProgress = seedTestProgress
        self.disableCloudSync = disableCloudSync
        self.disableAudio = disableAudio
        self.themeOverride = themeOverride
        self.completedStageIDs = completedStageIDs
    }

    private static func load() -> AppEnvironment {
        parse(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    static func parse(arguments: [String], environment: [String: String]) -> AppEnvironment {
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil

        let tab: AppTab? = {
            guard let idx = arguments.firstIndex(of: "-selectedTab"),
                  arguments.indices.contains(idx + 1)
            else { return nil }
            let val = arguments[idx + 1].lowercased()
            if val == "heroes" || val == "pets" || val == "inventory" {
                return .collection
            }
            return AppTab(rawValue: val)
        }()

        let screen: LaunchScreen? = {
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
        }()

        let reset = arguments.contains("-reset-state")
        let seedTestProgress = arguments.contains("-seed-test-progress")
        let disableCloudSync = arguments.contains("-disable-cloud-sync")
        let disableAudio = arguments.contains("-disable-audio")
        let themeOverride: TrinketDesign.AppTheme? = {
            guard let idx = arguments.firstIndex(of: "-theme"),
                  arguments.indices.contains(idx + 1)
            else { return nil }
            let val = arguments[idx + 1].lowercased()
            return TrinketDesign.AppTheme.allCases.first { $0.rawValue.lowercased() == val }
        }()

        let completedStageIDs: [String] = {
            guard let idx = arguments.firstIndex(of: "-completed-stages"),
                  arguments.indices.contains(idx + 1)
            else { return [] }
            return arguments[idx + 1]
                .split(separator: ",")
                .map(String.init)
                .filter { !$0.isEmpty }
        }()

        return AppEnvironment(
            launchTab: tab,
            launchScreen: screen,
            resetState: reset,
            seedTestProgress: seedTestProgress,
            disableCloudSync: disableCloudSync || reset || isRunningTests,
            disableAudio: disableAudio || isRunningTests,
            themeOverride: themeOverride,
            completedStageIDs: completedStageIDs
        )
    }
}
