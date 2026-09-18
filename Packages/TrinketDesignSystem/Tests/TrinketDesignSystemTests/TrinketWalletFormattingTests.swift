import Testing
@testable import TrinketDesignSystem

struct TrinketWalletFormattingTests {
    @Test func `amounts compact at one hundred thousand`() {
        // Locale-independent: compare against the same Foundation formatters
        // the implementation uses, and assert the branch taken on each side
        // of the threshold so a wrong cutoff still fails.
        #expect(TrinketWalletFormatting.displayString(for: 99999) == 99999.formatted())
        #expect(
            TrinketWalletFormatting.displayString(for: 100000) == 100000.formatted(.number.notation(.compactName)),
        )
        #expect(
            TrinketWalletFormatting.displayString(for: 99999)
                != 99999.formatted(.number.notation(.compactName)),
        )
        #expect(TrinketWalletFormatting.displayString(for: 100000) != 100000.formatted())
        #expect(TrinketWalletFormatting.displayString(for: 0) == 0.formatted())
        #expect(TrinketWalletFormatting.displayString(for: -50) == (-50).formatted())
    }

    @Test(arguments: [
        (amount: 50, showsIncreasePrefix: true, expected: "+50"),
        (amount: 50, showsIncreasePrefix: false, expected: "50"),
        (
            amount: 100000,
            showsIncreasePrefix: true,
            expected: "+\(100000.formatted(.number.notation(.compactName)))",
        ),
    ])
    func `increase prefix applies after compact formatting`(
        amount: Int,
        showsIncreasePrefix: Bool,
        expected: String,
    ) {
        #expect(TrinketWalletFormatting.displayString(for: amount, showsIncreasePrefix: showsIncreasePrefix) == expected)
    }

    @Test func `wallet grid initializes safely with boundary column counts`() {
        _ = TrinketWalletGrid(columnCount: 0) {}
        _ = TrinketWalletGrid(columnCount: 4) {}
    }
}
