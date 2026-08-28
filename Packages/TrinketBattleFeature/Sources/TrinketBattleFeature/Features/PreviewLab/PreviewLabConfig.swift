import Foundation
import Observation

#if DEBUG

@MainActor
@Observable
final class PreviewLabConfig {
    var openingStyle: UltimateCinematicCoverStyle = .fade
    var closingStyle: UltimateCinematicCoverStyle = .fade

    init() {}
}
#endif
