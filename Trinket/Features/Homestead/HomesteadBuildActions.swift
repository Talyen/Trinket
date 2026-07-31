import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
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

        switch saveStore.homesteadStore.buildOrUpgradeNode(definition) {
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
    func homesteadBuildErrorAlert(build: Binding<HomesteadBuildControl>) -> some View {
        alert(
            "Build Failed",
            isPresented: Binding(
                get: { build.wrappedValue.error != nil },
                set: {
                    if !$0 {
                        build.wrappedValue.error = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(build.wrappedValue.error ?? "")
        }
    }
}
