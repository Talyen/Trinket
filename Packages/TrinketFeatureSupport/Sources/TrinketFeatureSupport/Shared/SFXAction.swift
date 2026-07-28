import SwiftUI

public extension EnvironmentValues {
    @Entry var playSFX: (_ id: String, _ volume: Double) -> Void = { _, _ in }
}
