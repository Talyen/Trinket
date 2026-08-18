import CoreGraphics
import Testing
import TrinketCore
@testable import TrinketBattleFeature

@MainActor
struct CardActivationTests {
    @Test func cardActivationRequestNormalizesKeywords() {
        let request = CardActivationRequest(
            artworkName: nil,
            center: .zero,
            size: CGSize(width: 100, height: 140),
            rotation: 0,
            verticalTilt: 0,
            scale: 1,
            keywords: [.burn, .burn, .physical]
        )

        #expect(request.keywords == [.burn, .physical])
    }
}
