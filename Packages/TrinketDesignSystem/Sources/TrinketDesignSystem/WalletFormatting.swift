import Foundation

enum TrinketWalletFormatting {
    nonisolated static func displayString(for amount: Int) -> String {
        amount >= 100000 ? amount.formatted(.number.notation(.compactName)) : amount.formatted()
    }

    nonisolated static func displayString(for amount: Int, showsIncreasePrefix: Bool) -> String {
        let value = displayString(for: amount)
        return showsIncreasePrefix ? "+\(value)" : value
    }
}
