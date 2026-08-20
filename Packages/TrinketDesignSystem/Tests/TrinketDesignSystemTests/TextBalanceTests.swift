import Testing
@testable import TrinketDesignSystem

struct TextBalanceTests {
    @Test func singleWordReturnsUnchanged() {
        let input = "Victory"
        #expect(input.trinketBalanced() == "Victory")
    }

    @Test func twoWordsBindsWithNonBreakingSpace() {
        let input = "Defeat King"
        #expect(input.trinketBalanced() == "Defeat\u{00A0}King")
    }

    @Test func multiWordBindsOnlyLastSpace() {
        let input = "Defeat the Skeleton King"
        #expect(input.trinketBalanced() == "Defeat the Skeleton\u{00A0}King")
    }

    @Test func emptyStringReturnsUnchanged() {
        let input = ""
        #expect(input.trinketBalanced().isEmpty)
    }

    @Test func tabWhitespaceReplaced() {
        let input = "Hello\tWorld"
        #expect(input.trinketBalanced() == "Hello\u{00A0}World")
    }
}
