import Foundation
import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadBuildControl {
    var error: String?
    var upgradeEventCount = 0

    @MainActor
    mutating func perform(
        _ definition: HomesteadNodeDefinition,
        saveStore: PlayerSaveStore,
        onSuccess: (HomesteadNodeID) -> Void = { _ in },
    ) {
        switch saveStore.buildOrUpgradeNode(definition) {
        case .success:
            upgradeEventCount += 1
            onSuccess(definition.id)
        case .insufficientResources:
            error = "Not enough resources to build or upgrade this project."
        case .notAvailable:
            error = "This project isn't available to build or upgrade yet."
        case .persistFailed:
            error = "Couldn't save homestead progress. Try again."
        }
    }
}

struct HomesteadCollectionControl {
    var error: String?

    @MainActor
    mutating func perform(
        saveStore: PlayerSaveStore,
        at date: Date,
        onSuccess: ([ResourceAmount]) -> Void = { _ in },
    ) {
        switch saveStore.collectProduction(at: date) {
        case let .success(amounts):
            onSuccess(amounts)
        case .noProduction:
            break
        case .cloudSyncUnsupported:
            error = "Passive collection is unavailable while cloud sync is enabled."
        case .persistFailed:
            error = "Couldn't save collected materials. Try again."
        }
    }
}

extension View {
    func homesteadBuildErrorAlert(build: Binding<HomesteadBuildControl>) -> some View {
        trinketFailureAlert("Build Failed", message: build.error)
    }

    func homesteadCollectionErrorAlert(collection: Binding<HomesteadCollectionControl>) -> some View {
        trinketFailureAlert("Collection Failed", message: collection.error)
    }
}
