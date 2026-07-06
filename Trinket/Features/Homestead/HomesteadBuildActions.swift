import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

func runHomesteadBuildOrUpgrade(
    _ definition: HomesteadNodeDefinition,
    homestead: PlayerHomesteadStore,
    roster: PlayerRosterStore,
    onSuccess: () -> Void,
    onFailure: (String) -> Void
) {
    switch homestead.buildOrUpgrade(definition, roster: roster) {
    case .success:
        onSuccess()
    case .insufficientResources:
        onFailure("Not enough resources to build or upgrade this project.")
    case .persistFailed:
        onFailure("Couldn't save homestead progress. Try again.")
    }
}

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

        runHomesteadBuildOrUpgrade(
            definition,
            homestead: homestead,
            roster: roster,
            onSuccess: {
                upgradeEventCount += 1
                onSuccess(definition.id)
            },
            onFailure: { error = $0 }
        )
    }
}

extension View {
    func homesteadLockedArtworkStyle(
        isUnlocked: Bool,
        lockedSaturation: Double,
        lockedOpacity: Double
    ) -> some View {
        saturation(isUnlocked ? 1 : lockedSaturation)
            .opacity(isUnlocked ? 1 : lockedOpacity)
    }

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
