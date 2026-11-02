import SwiftUI
import TrinketAppState
import TrinketFeatureSupport

public extension View {
    func appFramePacingSignpost(_ name: StaticString, isActive: Bool) -> some View {
        framePacingInterval(signposter: AppFramePacingSignposts.signposter, name: name, isActive: isActive)
    }
}
