import Foundation
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Transient build/upgrade attempt state. Stays separate from
/// `HomesteadCollectionControl` below: the result types and success payloads
/// differ (tier celebration vs granted amounts), and sharing an abstraction
/// would couple the two flows for ~20 saved lines.
struct HomesteadBuildControl {
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
            break
        case .notAvailable:
            break
        case .cloudSyncUnsupported:
            break
        case .cloudUnavailable, .persistFailed:
            isPending = true
        }
    }
}

struct HomesteadCollectionControl {
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
            break
        case .cloudUnavailable, .persistFailed:
            isPending = true
        }
    }
}
