import Foundation
import Observation

#if DEBUG
// DEBUG playground only — production defaults live in the transition style enums. Do not ship lab UI.

/// Debug-only state for the Options > Developer Preview Lab. The lab injects this
/// into its own `BattleSession`, so only the embedded battle uses the selected
/// Ultimate transition styles; production battles keep the diagonal split defaults.
@MainActor
@Observable
final class PreviewLabConfig {
    var openingStyle: UltimateCinematicEnterStyle = .fade
    var closingStyle: UltimateCinematicExitStyle = .fade

    init() {}
}
#endif
