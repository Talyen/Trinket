import Foundation
import BattleBalanceTools
import TrinketContent

struct CLIOptions {
    var runs: Int = BalanceSweepDefaults.runsPerMatchup
    var samples: Int = BalanceSweepDefaults.loadoutSamplesPerMatchup
    var output: String = ".DerivedData/BalanceReports/latest.html"
    var tiers: [SimulationPowerTier] = SimulationPowerTier.allCases
    var smoke: Bool = false
    var includeAbilityAnalysis: Bool = true
    var baseSeed: UInt64 = BalanceSweepDefaults.baseSeed
}

@main
enum BalanceSweepCLI {
    static func main() throws {
        let options = try parseOptions()
        let triples: [BalanceSweepTriple]?
        if options.smoke {
            let hero = GameContent.heroes.first { $0.id == "wizard" }!
            let pet = GameContent.pets.first { $0.id == "wolf" }!
            triples = Array(GameContent.enemies.prefix(2)).map {
                BalanceSweepTriple(hero: hero, pet: pet, enemy: $0)
            }
        } else {
            triples = nil
        }

        let request = BalanceSweepRequest(
            tiers: options.tiers,
            runsPerMatchup: options.runs,
            loadoutSamplesPerMatchup: options.samples,
            baseSeed: options.baseSeed,
            includeAbilityAnalysis: options.includeAbilityAnalysis,
            triples: triples
        )

        print("Running balance sweep (\(request.triples?.count ?? BalanceSweepCatalog.allTriples().count) triples)...")
        let result = BalanceSweepRunner.run(request)
        let html = BalanceReportRenderer.renderHTML(result)
        let json = try BalanceReportRenderer.renderJSON(result)

        let outputURL = URL(fileURLWithPath: options.output, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try html.write(to: outputURL, atomically: true, encoding: .utf8)
        try json.write(to: outputURL.deletingPathExtension().appendingPathExtension("json"))

        print(
            "Wrote \(outputURL.path) (\(result.matchupRows.count) matchup rows, \(result.abilityRows.count) ability rows, \(result.anomalies.count) anomalies)"
        )
    }

    private static func parseOptions() throws -> CLIOptions {
        var options = CLIOptions()
        var arguments = Array(CommandLine.arguments.dropFirst())

        while let flag = arguments.first {
            arguments.removeFirst()
            switch flag {
            case "--runs":
                options.runs = try intValue(from: &arguments, flag: flag)
            case "--samples":
                options.samples = try intValue(from: &arguments, flag: flag)
            case "--output":
                options.output = try stringValue(from: &arguments, flag: flag)
            case "--tiers":
                let raw = try stringValue(from: &arguments, flag: flag)
                options.tiers = raw.split(separator: ",").compactMap { SimulationPowerTier(rawValue: String($0)) }
                guard !options.tiers.isEmpty else {
                    throw CLIError.invalidTiers(raw)
                }
            case "--seed":
                let raw = try stringValue(from: &arguments, flag: flag)
                guard let seed = UInt64(raw) else { throw CLIError.invalidSeed(raw) }
                options.baseSeed = seed
            case "--smoke":
                options.smoke = true
            case "--no-ability-analysis":
                options.includeAbilityAnalysis = false
            case "--help", "-h":
                printHelp()
                throw CLIError.help
            default:
                throw CLIError.unknownFlag(flag)
            }
        }

        return options
    }

    private static func intValue(from arguments: inout [String], flag: String) throws -> Int {
        guard let raw = arguments.first else { throw CLIError.missingValue(flag) }
        arguments.removeFirst()
        guard let value = Int(raw) else { throw CLIError.invalidInteger(raw, flag: flag) }
        return value
    }

    private static func stringValue(from arguments: inout [String], flag: String) throws -> String {
        guard let value = arguments.first else { throw CLIError.missingValue(flag) }
        arguments.removeFirst()
        return value
    }

    private static func printHelp() {
        print("""
        Usage: balance-sweep [options]

          --runs <n>                 Battles per matchup (default: \(BalanceSweepDefaults.runsPerMatchup))
          --samples <n>              Random loadout samples for middle/late (default: \(BalanceSweepDefaults.loadoutSamplesPerMatchup))
          --output <path>            HTML output path (default: .DerivedData/BalanceReports/latest.html)
          --tiers <early,middle,...> Comma-separated tiers (default: all)
          --seed <n>                 Base RNG seed (default: \(BalanceSweepDefaults.baseSeed))
          --smoke                    Wizard + wolf vs first two enemies only
          --no-ability-analysis      Skip ability A/B comparison pass
          --help                     Show this help
        """)
    }
}

enum CLIError: Error, CustomStringConvertible {
    case help
    case unknownFlag(String)
    case missingValue(String)
    case invalidInteger(String, flag: String)
    case invalidTiers(String)
    case invalidSeed(String)

    var description: String {
        switch self {
        case .help:
            return "Help requested."
        case .unknownFlag(let flag):
            return "Unknown flag: \(flag)"
        case .missingValue(let flag):
            return "Missing value for \(flag)."
        case .invalidInteger(let raw, let flag):
            return "Invalid integer '\(raw)' for \(flag)."
        case .invalidTiers(let raw):
            return "No valid tiers in '\(raw)'."
        case .invalidSeed(let raw):
            return "Invalid seed '\(raw)'."
        }
    }
}
