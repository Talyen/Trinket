import SwiftUI
import TrinketFeatureContracts

public extension EnvironmentValues {
    @Entry var requestFullGameOffer: (FullGameOfferOrigin) -> Void = { _ in }
}
