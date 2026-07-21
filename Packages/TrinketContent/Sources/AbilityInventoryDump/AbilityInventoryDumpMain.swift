import Foundation
import TrinketContent

@main
enum AbilityInventoryDump {
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run() throws {
        let sorted = AbilityCatalog.all.sorted { lhs, rhs in
            let leftTier = lhs.tier.rawValue.lowercased()
            let rightTier = rhs.tier.rawValue.lowercased()
            if leftTier != rightTier {
                return leftTier < rightTier
            }
            return lhs.name.lowercased() < rhs.name.lowercased()
        }

        var lines = ["id\tname\ttier\tsummary"]
        for ability in sorted {
            let summary = ability.summary
            if summary.contains("\t") || summary.contains("\n") || summary.contains("\r") {
                throw DumpError.invalidSummary(abilityID: ability.id)
            }
            let tier = ability.tier.rawValue.lowercased()
            lines.append("\(ability.id)\t\(ability.name)\t\(tier)\t\(summary)")
        }
        print(lines.joined(separator: "\n"))
    }

    private enum DumpError: Error, CustomStringConvertible {
        case invalidSummary(abilityID: String)

        var description: String {
            switch self {
            case let .invalidSummary(abilityID):
                "Ability \(abilityID) summary contains tab or newline; cannot emit TSV"
            }
        }
    }
}
