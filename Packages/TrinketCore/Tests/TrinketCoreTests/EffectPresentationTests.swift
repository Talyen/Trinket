import TrinketCore
import XCTest

final class EffectPresentationTests: XCTestCase {
    func testActivePhraseFormatsControlMeterBuildUp() {
        let active = ActiveEffect(
            id: 1,
            effect: .controlMeter(.stun, 3, 10),
            remainingTicks: 0
        )

        XCTAssertEqual(EffectPresentation.activePhrase(for: active), "Stun Build-up: 3/10")
    }

    func testActivePhraseFormatsTriggeredControlAsStatusAlias() {
        let active = ActiveEffect(
            id: 1,
            effect: .controlMeter(.stun, 10, 10),
            remainingTicks: 2
        )

        XCTAssertEqual(EffectPresentation.activePhrase(for: active), "Stunned")
    }

    func testActivePhraseFormatsDeathsDoor() {
        let active = ActiveEffect(
            id: 1,
            effect: .deathsDoor,
            remainingTicks: 8
        )

        XCTAssertEqual(EffectPresentation.activePhrase(for: active), "Death's Door")
    }
}
