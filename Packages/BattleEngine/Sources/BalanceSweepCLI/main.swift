import Foundation
import BattleBalanceTools
import BattleEngine
import TrinketContent

struct CLIOptions {
    var runs: Int = BalanceSweepDefaults.runsPerMatchup
    var samples: Int = BalanceSweepDefaults.loadoutSamplesPerMatchup
    var output: String = ".DerivedData/BalanceReports/latest.html"
    var tiers: [SimulationPowerTier] = SimulationPowerTier.allCases
    var smoke: Bool = false
    var ciGate: Bool = false
    var includeAbilityAnalysis: Bool = true
    var baseSeed: UInt64 = BalanceSweepDefaults.baseSeed
    var stageWeighted: Bool = false
    var loadoutMode: LoadoutSamplingMode = .realistic
}

enum BalanceSweepCLI {
    static func main() throws {
        let options = try parseOptions()
        let request = try makeRequest(options: options)

        print(
            "Running balance sweep (\(request.encodedTripleCount) triples, loadout \(request.loadoutSamplingMode.rawValue), stage-weighted \(request.stageWeighted))..."
        )
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

        printKPIs(result)
        printGateViolations(result)

        print(
            "Wrote \(outputURL.path) (\(result.matchupRows.count) matchup rows, \(result.abilityRows.count) ability rows, \(result.anomalies.count) anomalies)"
        )

        if options.ciGate, !result.gateViolations.isEmpty {
            throw CLIError.gateFailed(result.gateViolations.count)
        }
    }

    private static func makeRequest(options: CLIOptions) throws -> BalanceSweepRequest {
        if options.ciGate {
            let hero = try representativeCombatant(
                id: BalanceSweepDefaults.representativeHeroID,
                from: GameContent.heroes,
                label: "hero"
            )
            let pet = try representativeCombatant(
                id: BalanceSweepDefaults.representativePetID,
                from: GameContent.pets,
                label: "pet"
            )
            let enemies = BalanceSweepCatalog.enemies(for: .middle, stageWeighted: true)
                .filter { !$0.isBoss && !$0.isElite }
            let triples = enemies.map { BalanceSweepTriple(hero: hero, pet: pet, enemy: $0) }

            return BalanceSweepRequest(
                tiers: [.middle],
                runsPerMatchup: options.runs,
                loadoutSamplesPerMatchup: options.samples,
                baseSeed: options.baseSeed,
                includeAbilityAnalysis: false,
                stageWeighted: true,
                loadoutSamplingMode: .realistic,
                triples: triples
            )
        }

        let triples: [BalanceSweepTriple]?
        if options.smoke {
            let hero = try representativeCombatant(id: "wizard", from: GameContent.heroes, label: "hero")
            let pet = try representativeCombatant(id: "wolf", from: GameContent.pets, label: "pet")
            triples = Array(GameContent.enemies.prefix(2)).map {
                BalanceSweepTriple(hero: hero, pet: pet, enemy: $0)
            }
        } else {
            triples = nil
        }

        return BalanceSweepRequest(
            tiers: options.tiers,
            runsPerMatchup: options.runs,
            loadoutSamplesPerMatchup: options.samples,
            baseSeed: options.baseSeed,
            includeAbilityAnalysis: options.includeAbilityAnalysis,
            stageWeighted: options.stageWeighted,
            loadoutSamplingMode: options.loadoutMode,
            triples: triples
        )
    }

    private static func representativeCombatant(
        id: String,
        from combatants: [Combatant],
        label: String
    ) throws -> Combatant {
        guard let combatant = combatants.first(where: { $0.id == id }) else {
            throw CLIError.missingRepresentative(id, label: label)
        }
        return combatant
    }

    private static func printKPIs(_ result: BalanceSweepResult) {
        let kpis = result.kpis
        print(
            String(
                format: "KPIs: %.1f%% in band · %.1f%% perfect wins · %.1f%% duration in 10–100 ticks",
                kpis.inBandRate * 100,
                kpis.perfectWinRate * 100,
                kpis.durationInBandRate * 100
            )
        )
    }

    private static func printGateViolations(_ result: BalanceSweepResult) {
        guard !result.gateViolations.isEmpty else {
            print("Balance gate: passed")
            return
        }
        print("Balance gate: \(result.gateViolations.count) violation(s)")
        for violation in result.gateViolations {
            print("  - \(violation.detail)")
        }
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
            case "--ci-gate":
                options.ciGate = true
            case "--stage-weighted":
                options.stageWeighted = true
            case "--loadout-mode":
                let raw = try stringValue(from: &arguments, flag: flag)
                guard let mode = LoadoutSamplingMode(rawValue: raw) else {
                    throw CLIError.invalidLoadoutMode(raw)
                }
                options.loadoutMode = mode
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
          --ci-gate                  Middle-tier gate sweep (knight+wolf vs stage-weighted fodder)
          --stage-weighted           Limit enemies to journey-appropriate sets per tier
          --loadout-mode <mode>      optimistic or realistic (default: realistic)
          --no-ability-analysis      Skip ability A/B comparison pass
          --help                     Show this help
        """)
    }
}

try BalanceSweepCLI.main()

enum CLIError: Error, CustomStringConvertible {
    case help
    case unknownFlag(String)
    case missingValue(String)
    case invalidInteger(String, flag: String)
    case invalidTiers(String)
    case invalidSeed(String)
    case invalidLoadoutMode(String)
    case missingRepresentative(String, label: String)
    case gateFailed(Int)

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
        case .invalidLoadoutMode(let raw):
            return "Invalid loadout mode '\(raw)' (expected optimistic or realistic)."
        case .missingRepresentative(let id, let label):
            return "Missing representative \(label) '\(id)'."
        case .gateFailed(let count):
            return "Balance gate failed with \(count) violation(s)."
        }
    }
}
