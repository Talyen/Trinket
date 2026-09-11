import Foundation
import TrinketContent
import TrinketCore

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
            if lhs.tier != rhs.tier {
                return tierRank(lhs.tier) < tierRank(rhs.tier)
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
        let output = lines.joined(separator: "\n") + "\n"
        if CommandLine.arguments.count > 1 {
            try output.write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
        } else {
            print(output, terminator: "")
        }
    }

    private static func tierRank(_ tier: AbilityTier) -> Int {
        switch tier {
        case .basic: 0
        case .skill: 1
        case .ultimate: 2
        }
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
