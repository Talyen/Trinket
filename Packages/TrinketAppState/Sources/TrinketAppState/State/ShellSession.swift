import Foundation
import Observation
import TrinketCore

@MainActor
@Observable
public final class ShellSession {
    public static let tabFirstLayoutBudget: Duration = .milliseconds(600)
    public static let secondaryTabFirstLayoutBudget: Duration = .milliseconds(250)

    public var selectedTab: AppTab = .play
    public var playPath: [PlayLaunchDestination] = []
    public var homesteadPath: [HomesteadRoute] = []

    public init(selectedTab: AppTab = .play) {
        self.selectedTab = selectedTab
    }

    public func popToRoot(_ tab: AppTab) {
        switch tab {
        case .play:
            playPath.removeAll()
        case .collection:
            break
        case .homestead:
            homesteadPath.removeAll()
        case .options:
            break
        }
    }
}
