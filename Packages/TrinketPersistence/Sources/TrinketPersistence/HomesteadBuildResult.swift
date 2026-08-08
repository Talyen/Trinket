import Foundation
import TrinketCore

public enum HomesteadBuildResult: Equatable {
    case success
    case insufficientResources
    case persistFailed
}

public enum HomesteadCollectionResult: Equatable {
    case success([ResourceAmount])
    case noProduction
    case cloudSyncUnsupported
    case persistFailed
}
