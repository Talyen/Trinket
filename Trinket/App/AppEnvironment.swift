import Foundation

struct AppEnvironment {
    static let shared = load()

    let launchTab: AppTab?
    let launchScreen: LaunchScreen?
    let resetState: Bool
    let seedTestProgress: Bool
    let disableCloudSync: Bool
    let disableAudio: Bool
    let persistSaveImmediately: Bool
    let completedStageIDs: [String]
    /// Test-only deterministic recruit event selected for the Mystery deep link.
    let mysteryRecruitEventID: String?
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
        completedStageIDs: [String],
        mysteryRecruitEventID: String?,
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
        self.completedStageIDs = completedStageIDs
        self.mysteryRecruitEventID = mysteryRecruitEventID
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
        // F1 ship posture: CloudKit off unless explicitly enabled (device + simulator).
        disableCloudSync = arguments.contains("-disable-cloud-sync")
            || arguments.contains("-reset-state")
            || isRunningTests
            || !arguments.contains("-enable-cloud-sync")

        return AppEnvironment(
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
            }
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
        let parts = val.split(separator: ":", maxSplits: 1).map(String.init)
        let kind = parts[0].lowercased()
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
