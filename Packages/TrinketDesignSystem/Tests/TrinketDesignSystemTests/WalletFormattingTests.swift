import Testing
@testable import TrinketDesignSystem

struct WalletFormattingTests {
    @Test func `amounts compact at one hundred thousand`() {
        #expect(WalletFormatting.displayString(for: 99999) == 99999.formatted())
        #expect(
            WalletFormatting.displayString(for: 100000) == 100000.formatted(.number.notation(.compactName)),
        )
        #expect(WalletFormatting.displayString(for: 0) == 0.formatted())
    }
}
