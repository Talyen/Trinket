import SwiftUI

enum AppShellEvent {
    case appeared
    case selectedTabChanged(AppTab)
    case activeBattleStarted
    case activeBattleEnded
    case scenePhaseChanged(ScenePhase)
    case musicInputsChanged
}
