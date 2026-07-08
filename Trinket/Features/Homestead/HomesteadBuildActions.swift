import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadBuildControl {
    var isBuilding = false
    var error: String?
    var upgradeEventCount = 0

    @MainActor
    mutating func perform(
        _ definition: HomesteadNodeDefinition,
        saveStore: PlayerSaveStore,
        onSuccess: (HomesteadNodeID) -> Void = { _ in }
    ) {
        guard !isBuilding else { return }
        isBuilding = true
        defer { isBuilding = false }

        switch saveStore.buildOrUpgradeHomesteadNode(definition) {
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
    func homesteadLockedArtworkStyle(
        isUnlocked: Bool,
        lockedSaturation: Double,
        lockedOpacity: Double
    ) -> some View {
        saturation(isUnlocked ? 1 : lockedSaturation)
            .opacity(isUnlocked ? 1 : lockedOpacity)
    }

    func homesteadBuildErrorAlert(build: Binding<HomesteadBuildControl>) -> some View {
        homesteadBuildErrorAlert(error: Binding(
            get: { build.wrappedValue.error },
            set: { build.wrappedValue.error = $0 }
        ))
    }

    private func homesteadBuildErrorAlert(error: Binding<String?>) -> some View {
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
