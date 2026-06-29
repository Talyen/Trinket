import Foundation

struct AppEnvironment {
    static let shared = load()

    let launchTab: AppTab?
    let launchScreen: LaunchScreen?
    let resetState: Bool
    let battlePreset: BattlePreset

    private init(
        launchTab: AppTab?,
        launchScreen: LaunchScreen?,
        resetState: Bool,
        battlePreset: BattlePreset
    ) {
        self.launchTab = launchTab
        self.launchScreen = launchScreen
        self.resetState = resetState
        self.battlePreset = battlePreset
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
            let parts = val.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            let kind = String(parts[0]).lowercased()
            let id = String(parts[1])
            switch kind {
            case "hero": return .heroDetail(id)
            case "pet": return .petDetail(id)
            case "item": return .itemDetail(id)
            case "options": return .options
            case "battle": return .battle
            default: return nil
            }
        }()

        let reset = args.contains("-reset-state")

        let preset: BattlePreset = {
            guard let idx = args.firstIndex(of: "-battle-preset"),
                  args.indices.contains(idx + 1)
            else { return .fresh }
            return BattlePreset(rawValue: args[idx + 1]) ?? .fresh
        }()

        return AppEnvironment(
            launchTab: tab,
            launchScreen: screen,
            resetState: reset,
            battlePreset: preset
        )
    }
}
