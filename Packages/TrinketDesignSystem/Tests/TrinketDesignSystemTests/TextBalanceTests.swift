import Testing
@testable import TrinketDesignSystem

struct TextBalanceTests {
    private struct BalanceCase: Sendable {
        let input: String
        let expected: String

        static let singleWord = Self(input: "Victory", expected: "Victory")
        static let twoWords = Self(input: "Defeat King", expected: "Defeat\u{00A0}King")
        static let multiWord = Self(input: "Defeat the Skeleton King", expected: "Defeat the Skeleton\u{00A0}King")
        static let empty = Self(input: "", expected: "")
        static let tabWhitespace = Self(input: "Hello\tWorld", expected: "Hello\u{00A0}World")
        static let trailingWhitespace = Self(input: "Victory ", expected: "Victory ")
        static let twoWordsWithTrailingWhitespace = Self(input: "Defeat King  ", expected: "Defeat\u{00A0}King  ")
        static let multipleInterWordSpaces = Self(input: "Defeat  King", expected: "Defeat \u{00A0}King")
        static let onlyWhitespace = Self(input: "   ", expected: "   ")
    }

    @Test(arguments: [
        Self.BalanceCase.singleWord,
        .twoWords,
        .multiWord,
        .empty,
        .tabWhitespace,
        .trailingWhitespace,
        .twoWordsWithTrailingWhitespace,
        .multipleInterWordSpaces,
        .onlyWhitespace,
    ])
    private func trinketBalancedBindsOnlyTheLastSpace(_ testCase: BalanceCase) {
        #expect(testCase.input.trinketBalanced() == testCase.expected)
    }
}
