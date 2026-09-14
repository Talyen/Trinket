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
    var isPending = false

    @MainActor
    mutating func complete(
        _ result: HomesteadBuildResult,
        onSuccess: () -> Void,
    ) {
        isPending = false
        switch result {
        case .success:
            upgradeEventCount += 1
            onSuccess()
        case .insufficientResources:
            error = "Not enough resources to build or upgrade this project."
        case .notAvailable:
            error = "This project isn't available to build or upgrade yet."
        case .cloudSyncUnsupported:
            error = "Homestead projects are unavailable while cloud sync is enabled."
        case .cloudUnavailable, .persistFailed:
            isPending = true
        }
    }
}

struct HomesteadCollectionControl {
    var error: String?
    var isPending = false

    @MainActor
    mutating func complete(
        _ result: HomesteadCollectionResult,
        onSuccess: ([ResourceAmount]) -> Void = { _ in },
    ) {
        isPending = false
        switch result {
        case let .success(amounts):
            onSuccess(amounts)
        case .noProduction:
            break
        case .cloudSyncUnsupported:
            error = "Passive collection is unavailable while cloud sync is enabled."
        case .cloudUnavailable, .persistFailed:
            isPending = true
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
