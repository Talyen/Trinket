import Foundation
import Testing
import TrinketContent
@testable import TrinketFeatureSupport

struct LocalizationRenderingTests {
    @Test func `locked labels resolve nested names in the rendering locale`() {
        // One locale differs from the process language, exposing eager String argument translation.
        for (language, expected) in [("en", "Knight, locked"), ("ko", "기사, 잠김")] {
            let locale = Locale(identifier: language)
            var name = ContentCopy.resource("Knight")
            name.locale = locale
            var label = L10n.ui_combatantcard_1_locked_1871c(name)
            label.locale = locale
            #expect(String(localized: label) == expected)
        }
    }
}
