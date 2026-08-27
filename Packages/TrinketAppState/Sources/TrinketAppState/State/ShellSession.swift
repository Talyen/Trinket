import Observation

/// In-session shell navigation state.
///
/// The selected tab is launch-argument driven and intentionally not persisted:
/// every cold launch lands on Play unless a UI-test launch override selects
/// another tab/screen.
@MainActor
@Observable
public final class ShellSession {
    /// First layout budget for Play under the cover (includes overlay battlefield).
    public static let tabFirstLayoutBudget: Duration = .milliseconds(600)
    /// First layout budget for Collection / Homestead / Options under the cover.
    public static let secondaryTabFirstLayoutBudget: Duration = .milliseconds(250)

    public var selectedTab: AppTab = .play
    /// True while launch first-layouts every tab root under the cover.
    /// Skip music and Play-tab path resets for those synthetic switches.
    public var isShellWarmupActive = false

    public init(selectedTab: AppTab = .play) {
        self.selectedTab = selectedTab
    }
}
