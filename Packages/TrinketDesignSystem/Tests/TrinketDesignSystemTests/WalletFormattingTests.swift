import Testing
@testable import TrinketDesignSystem

struct WalletFormattingTests {
    @Test func `amounts compact at one hundred thousand`() {
        #expect(WalletFormatting.displayString(for: 99999) == 99999.formatted())
        #expect(
            WalletFormatting.displayString(for: 100000) == 100000.formatted(.number.notation(.compactName)),
        )
        #expect(WalletFormatting.displayString(for: 0) == 0.formatted())
        #expect(WalletFormatting.displayString(for: -50) == (-50).formatted())
    }

    @Test func `wallet grid initializes safely with boundary column counts`() {
        _ = TrinketWalletGrid(columnCount: 0) {}
        _ = TrinketWalletGrid(columnCount: 4) {}
    }
}
