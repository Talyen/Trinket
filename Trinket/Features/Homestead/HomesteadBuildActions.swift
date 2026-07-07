import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

@Observable
@MainActor
final class HomesteadBuildActions {
    var isBuilding = false
    var error: String?
    var upgradeEventCount = 0

    func perform(
        _ definition: HomesteadNodeDefinition,
        homestead: PlayerHomesteadStore,
        roster: PlayerRosterStore,
        onSuccess: (HomesteadNodeID) -> Void = { _ in }
    ) {
        guard !isBuilding else { return }
        isBuilding = true
        defer { isBuilding = false }

        switch homestead.buildOrUpgrade(definition, roster: roster) {
        case .success:
            upgradeEventCount += 1
            onSuccess(definition.id)
        case .insufficientResources:
            error = "Not enough resources to build or upgrade this project."
        case .persistFailed:
            error = "Couldn't save homestead progress. Try again."
        }
    }
}

extension View {
    func homesteadBuildErrorAlert(error: Binding<String?>) -> some View {
        alert(
            "Build Failed",
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error.wrappedValue ?? "")
        }
    }
}
