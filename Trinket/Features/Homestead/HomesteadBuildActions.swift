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
        onSuccess: (HomesteadNodeID) -> Void = { _ in }
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
    var collectionEventCount = 0

    @MainActor
    mutating func perform(
        saveStore: PlayerSaveStore,
        at date: Date,
        onSuccess: ([ResourceAmount]) -> Void = { _ in }
    ) {
        switch saveStore.collectProduction(at: date) {
        case let .success(amounts):
            collectionEventCount += 1
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

    func homesteadCollectionErrorAlert(collection: Binding<HomesteadCollectionControl>) -> some View {
        alert(
            "Collection Failed",
            isPresented: Binding(
                get: { collection.wrappedValue.error != nil },
                set: {
                    if !$0 {
                        collection.wrappedValue.error = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(collection.wrappedValue.error ?? "")
        }
    }
}
