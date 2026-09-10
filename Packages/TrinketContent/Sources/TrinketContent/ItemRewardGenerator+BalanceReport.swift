import Foundation

public extension ItemRewardGenerator {
    static func balanceReport() -> String {
        var lines = [
            "# Loot balance",
            "",
            "Exact probabilities from the production policy. Repeated-reward chances assume unchanged level, bonuses, and pool availability.",
            "",
            "| Level | Profile | Sanctum | Pool | Basic % | Astral % | Trinket % | Unique % | Premium in 10 % | Premium in 20 % |",
            "|---|---|---|---|---|---|---|---|---|---|",
        ]
        let pools: [(String, Set<ItemDropTier>)] = [
            ("Full", Set(ItemDropTier.allCases)),
            ("No uniques / shop", [.basic, .astral, .trinket]),
            ("Trinkets exhausted", [.basic, .astral, .unique]),
            ("Both exhausted", [.basic, .astral]),
            ("Guaranteed Astral", [.astral]),
        ]
        for level in 1 ... 20 {
            for boss in [false, true] {
                for bonus in [0, 5, 10, 15, 20] {
                    for (name, tiers) in pools {
                        let probabilities = ItemLootPolicy.probabilities(
                            level: level, bossContent: boss, astralChanceBonusPercent: bonus, availableTiers: tiers,
                        )
                        let chances = probabilities + [1 - pow(probabilities[0], 10), 1 - pow(probabilities[0], 20)]
                        let values = chances.map { String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), $0 * 100) }
                        lines
                            .append(
                                "| \(level) | \(boss ? "Boss" : "Ordinary") | \(bonus)% | \(name) | \(values.joined(separator: " | ")) |",
                            )
                    }
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}
