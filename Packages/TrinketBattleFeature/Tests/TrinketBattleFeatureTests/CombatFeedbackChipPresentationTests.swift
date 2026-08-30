import Testing
import TrinketCore
import TrinketDesignSystem
@testable import TrinketBattleFeature

struct CombatFeedbackChipPresentationTests {
    @Test func `cleanse uses cleanse leading icon`() {
        let presentation = CombatFeedbackChipPresentation.resolve(
            label: .word(.cleanse(.poison)),
            keyword: .poison,
            visualRole: .keyword,
            feedbackClass: .buff,
        )

        #expect(presentation.leadingStyle == .keyword(.cleanse))
        #expect(presentation.trailingStyle == .keyword(.poison))
        #expect(presentation.text == nil)
    }

    @Test func `purge uses purge leading icon`() {
        let presentation = CombatFeedbackChipPresentation.resolve(
            label: .word(.purge(.poison)),
            keyword: .poison,
            visualRole: .keyword,
            feedbackClass: .buff,
        )

        #expect(presentation.leadingStyle == .keyword(.purge))
        #expect(presentation.trailingStyle == .keyword(.poison))
        #expect(presentation.text == nil)
    }
}
