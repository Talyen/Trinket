import Foundation

enum TrinketWalletFormatting {
    nonisolated static func displayString(for amount: Int, showsIncreasePrefix: Bool = false) -> String {
        let value = amount >= 100000 ? amount.formatted(.number.notation(.compactName)) : amount.formatted()
        return showsIncreasePrefix ? "+\(value)" : value
    }
}
