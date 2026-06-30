import Foundation

struct AppEnvironment {
    static let shared = load()

    let launchTab: AppTab?
    let launchScreen: LaunchScreen?
    let resetState: Bool
    let seedTestProgress: Bool
    let completedStageIDs: [String]

    private init(
        launchTab: AppTab?,
        launchScreen: LaunchScreen?,
        resetState: Bool,
        seedTestProgress: Bool,
        completedStageIDs: [String]
    ) {
        self.launchTab = launchTab
        self.launchScreen = launchScreen
        self.resetState = resetState
        self.seedTestProgress = seedTestProgress
        self.completedStageIDs = completedStageIDs
    }

    private static func load() -> AppEnvironment {
        let args = ProcessInfo.processInfo.arguments

        let tab: AppTab? = {
            guard let idx = args.firstIndex(of: "-selectedTab"),
                  args.indices.contains(idx + 1)
            else { return nil }
            let val = args[idx + 1].lowercased()
            if val == "heroes" || val == "pets" || val == "inventory" {
                return .collection
            }
            return AppTab(rawValue: val)
        }()

        let screen: LaunchScreen? = {
            guard let idx = args.firstIndex(of: "-launch-screen"),
                  args.indices.contains(idx + 1)
            else { return nil }
            let val = args[idx + 1]
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

        let reset = args.contains("-reset-state")
        let seedTestProgress = args.contains("-seed-test-progress")

        let completedStageIDs: [String] = {
            guard let idx = args.firstIndex(of: "-completed-stages"),
                  args.indices.contains(idx + 1)
            else { return [] }
            return args[idx + 1]
                .split(separator: ",")
                .map(String.init)
                .filter { !$0.isEmpty }
        }()

        return AppEnvironment(
            launchTab: tab,
            launchScreen: screen,
            resetState: reset,
            seedTestProgress: seedTestProgress,
            completedStageIDs: completedStageIDs
        )
    }
}
