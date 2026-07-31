import TrinketBattleRuntime

/// The app-composition boundary for one battle runtime instance.
///
/// The runtime stays SwiftUI-free, while the app root supplies the one
/// presentation action needed by launch-preview flows. Keeping both values in
/// one composition object prevents Play and the UI from being wired to
/// different runtime handles.
@MainActor
public struct BattleRuntimeComposition {
    public let runtime: any BattleRuntime
    public let onLaunchBattleVictory: () -> Void

    public init(
        runtime: any BattleRuntime,
        onLaunchBattleVictory: @escaping () -> Void
    ) {
        self.runtime = runtime
        self.onLaunchBattleVictory = onLaunchBattleVictory
    }
}
