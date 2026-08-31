import Foundation
import Observation

@MainActor
@Observable
public final class ShellSession {
    public static let tabFirstLayoutBudget: Duration = .milliseconds(600)
    public static let secondaryTabFirstLayoutBudget: Duration = .milliseconds(250)

    public var selectedTab: AppTab = .play
    public var playPath: [PlayLaunchDestination] = []
    public var collectionStackID = UUID()
    public var homesteadStackID = UUID()
    public var optionsStackID = UUID()

    public init(selectedTab: AppTab = .play) {
        self.selectedTab = selectedTab
    }

    public func popToRoot(_ tab: AppTab) {
        switch tab {
        case .play:
            playPath.removeAll()
        case .collection:
            collectionStackID = UUID()
        case .homestead:
            homesteadStackID = UUID()
        case .options:
            optionsStackID = UUID()
        }
    }
}
