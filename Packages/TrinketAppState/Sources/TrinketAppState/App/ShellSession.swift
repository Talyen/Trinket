import Foundation
import Observation
import TrinketCore

@MainActor
@Observable
public final class ShellSession {
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
        case .homestead:
            homesteadPath.removeAll()
        case .collection, .options:
            break
        }
    }
}
