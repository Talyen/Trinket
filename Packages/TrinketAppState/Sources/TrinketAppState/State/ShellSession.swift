import Observation

/// In-session shell navigation state.
///
/// The selected tab is launch-argument driven and intentionally not persisted:
/// every cold launch lands on Play unless a UI-test launch override selects
/// another tab/screen.
@MainActor
@Observable
public final class ShellSession {
    public var selectedTab: AppTab = .play

    public init(selectedTab: AppTab = .play) {
        self.selectedTab = selectedTab
    }
}
