import Observation

@MainActor
@Observable
public final class ShellSession {
    public static let tabFirstLayoutBudget: Duration = .milliseconds(600)
    public static let secondaryTabFirstLayoutBudget: Duration = .milliseconds(250)

    public var selectedTab: AppTab = .play
    public var isShellWarmupActive = false

    public init(selectedTab: AppTab = .play) {
        self.selectedTab = selectedTab
    }
}
