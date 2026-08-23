import BattleBalanceTools
import BattleEngine
import Foundation
import TrinketContent

@main
enum BalanceSweepCLI {
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments.contains("--help") || arguments.contains("-h") {
                print(usageText)
                return
            }
            let parsed = try parseInvocation(arguments)
            if parsed.isWorker {
                try runWorker(parsed)
                return
            }

            FileHandle.standardError.write(Data(
                """
                Running balance sweep mode=\(parsed.config.mode.rawValue) \
                samples=\(parsed.config.battlesPerTier)/identity-enemy seed=\(parsed.config.seed) \
                jobs=\(parsed.config.resolvedJobs) pacing=\(parsed.config.appliesFightPacing ? "on" : "off") …
                """.utf8
            ))
            if parsed.deprecatedBattlesPerTier {
                FileHandle.standardError.write(Data(
                    "--battles-per-tier is deprecated; it is an alias for --samples (n per enemy / pairs per focus).\n".utf8
                ))
            }
            if parsed.config.battlesPerTier < BalanceSweepConfig.contrastFlagMinPairs {
                FileHandle.standardError.write(Data(
                    "warning: samples < \(BalanceSweepConfig.contrastFlagMinPairs); contrast flags are disabled.\n".utf8
                ))
            }

            let report: BalanceSweepReport
            #if os(macOS)
            report = try BalanceSweepProcessOrchestrator.run(
                config: parsed.config,
                executablePath: CommandLine.arguments[0]
            )
            #else
            report = BalanceSweepRunner.run(config: parsed.config)
            #endif
            let findings = BalanceFindingsReporter.render(report)
            let fullMarkdown = parsed.writeFullMarkdown
                ? BalanceMarkdownReporter.render(report)
                : nil
            let written = try BalanceSweepCLIFiles.write(
                findings: findings,
                fullMarkdown: fullMarkdown,
                report: report,
                toDirectory: parsed.config.outputDirectory
            )
            print(findings)
            BalanceSweepCLIFiles.announce(written)
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            FileHandle.standardError.write(Data(usageText.utf8))
            exit(1)
        }
    }

    private static func runWorker(_ parsed: ParsedInvocation) throws {
        guard let outputFile = parsed.outputFile else {
            throw CLIError.missingValue("--output-file")
        }
        let report = BalanceSweepRunner.run(config: parsed.config)
        let data = try JSONEncoder().encode(report)
        try data.write(to: URL(fileURLWithPath: outputFile), options: .atomic)
    }

    private static var usageText: String {
        """
        Usage: BalanceSweepCLI [options]

          --mode <name>            identity | ability-contrast | affix-contrast | talent-contrast |
                                   mode-progression | all (default: identity)
          --samples <n>            Observations per identity enemy and pairs per contrast focus
                                   per tier (default: 32)
          --battles-per-tier <n>   Deprecated alias for --samples
          --seed <n>               Sweep seed (default: 1)
          --tiers <list>           Comma list: early,middle,lateGame (default: all)
          --jobs <n>               Concurrent worker processes (default: CPU count)
          --output-dir <path>      Markdown+JSON output directory (default: BalanceSweepReports)
          --max-rounds <n>         Stall cap rounds (default: 100)
          --max-actions <n>        Stall cap actions (default: 500)
          --pacing <on|off>        FightPacing in simulated battles (default: on)
          --policy <id>            greedy-v1 | setup-v1 (default: greedy-v1; unknown ids error)
          --policy-compare         Identity-only second pass with the other policy
          --hero <ids>             Comma hero ids (default: all)
          --companion <ids>        Comma companion ids (default: all)
          --enemy <ids>            Comma enemy ids (default: all)
          --focus <ids>            Restrict contrast foci to these ability/affix/talent ids
          --full-markdown          Also write the verbose table dump as *-full.md
          --help                   Show this help

        Combat runs in child processes of this binary (never on GCD). Each child
        writes a JSON slice; the parent merges, writes a findings markdown brief
        and a JSON sidecar. Read the findings file; open JSON or pass
        --full-markdown only when drilling into a named finding.
        """
    }

    private struct ParsedInvocation {
        var config: BalanceSweepConfig
        var isWorker: Bool
        var outputFile: String?
        var deprecatedBattlesPerTier: Bool
        var writeFullMarkdown: Bool
    }

    private struct FlagState {
        var mode: BalanceSweepMode = .identity
        var battlesPerTier = BalanceSweepConfig.defaultBattlesPerTier
        var seed: UInt64 = 1
        var tiers = SimulationPowerTier.allCases
        var outputDirectory = BalanceSweepConfig.defaultOutputDirectory
        var maxRounds = BattleSimulator.defaultMaxRounds
        var maxActions = BattleSimulator.defaultMaxActions
        var jobs = 0
        var workOffset = 0
        var workLimit: Int?
        var isWorker = false
        var outputFile: String?
        var appliesFightPacing = true
        var policyID = GreedyHeuristicPolicy.id
        var comparePolicies = false
        var heroIDs: [String] = []
        var companionIDs: [String] = []
        var enemyIDs: [String] = []
        var focusIDs: [String] = []
        var deprecatedBattlesPerTier = false
        var writeFullMarkdown = false

        mutating func consume(_ arguments: [String], index: inout Int) throws {
            let arg = arguments[index]
            if arg == "--worker" {
                isWorker = true
                return
            }
            try consumeValued(arg, arguments: arguments, index: &index)
        }

        mutating func consumeFilters(_ arg: String, arguments: [String], index: inout Int) throws -> Bool {
            switch arg {
            case "--hero":
                heroIDs = try csvValue(after: arg, in: arguments, index: &index)
            case "--companion":
                companionIDs = try csvValue(after: arg, in: arguments, index: &index)
            case "--enemy":
                enemyIDs = try csvValue(after: arg, in: arguments, index: &index)
            case "--focus":
                focusIDs = try csvValue(after: arg, in: arguments, index: &index)
            default:
                return false
            }
            return true
        }

        mutating func consumeValued(_ arg: String, arguments: [String], index: inout Int) throws {
            if try consumeFilters(arg, arguments: arguments, index: &index) {
                return
            }
            if try consumeSampleFlags(arg, arguments: arguments, index: &index) {
                return
            }
            if try consumeWorkFlags(arg, arguments: arguments, index: &index) {
                return
            }
            try consumePolicyFlags(arg, arguments: arguments, index: &index)
        }

        mutating func consumeSampleFlags(_ arg: String, arguments: [String], index: inout Int) throws -> Bool {
            switch arg {
            case "--mode":
                let raw = try stringValue(after: arg, in: arguments, index: &index)
                guard let parsed = BalanceSweepMode(rawValue: raw) else {
                    throw CLIError.invalidMode(raw)
                }
                mode = parsed
            case "--battles-per-tier":
                battlesPerTier = try intValue(after: arg, in: arguments, index: &index)
                deprecatedBattlesPerTier = true
            case "--samples":
                battlesPerTier = try intValue(after: arg, in: arguments, index: &index)
            case "--seed":
                seed = try uintValue(after: arg, in: arguments, index: &index)
            case "--tiers":
                let raw = try stringValue(after: arg, in: arguments, index: &index)
                tiers = try parseTiers(raw)
            default:
                return false
            }
            return true
        }

        mutating func consumeWorkFlags(_ arg: String, arguments: [String], index: inout Int) throws -> Bool {
            switch arg {
            case "--jobs":
                jobs = try intValue(after: arg, in: arguments, index: &index)
            case "--output-dir":
                outputDirectory = try stringValue(after: arg, in: arguments, index: &index)
            case "--max-rounds":
                maxRounds = try intValue(after: arg, in: arguments, index: &index)
            case "--max-actions":
                maxActions = try intValue(after: arg, in: arguments, index: &index)
            case "--work-offset":
                workOffset = try nonNegativeIntValue(after: arg, in: arguments, index: &index)
            case "--work-limit":
                workLimit = try intValue(after: arg, in: arguments, index: &index)
            case "--output-file":
                outputFile = try stringValue(after: arg, in: arguments, index: &index)
            default:
                return false
            }
            return true
        }

        mutating func consumePolicyFlags(_ arg: String, arguments: [String], index: inout Int) throws {
            switch arg {
            case "--pacing":
                let raw = try stringValue(after: arg, in: arguments, index: &index)
                switch raw.lowercased() {
                case "on", "true", "1": appliesFightPacing = true
                case "off", "false", "0": appliesFightPacing = false
                default: throw CLIError.invalidInt("--pacing", raw)
                }
            case "--policy":
                policyID = try stringValue(after: arg, in: arguments, index: &index)
                guard SimulationPolicies.make(id: policyID) != nil else {
                    throw CLIError.invalidPolicy(policyID)
                }
            case "--policy-compare":
                comparePolicies = true
            case "--full-markdown":
                writeFullMarkdown = true
            default:
                throw CLIError.unknownArgument(arg)
            }
        }

        func makeInvocation() throws -> ParsedInvocation {
            if isWorker, mode == .all {
                throw CLIError.invalidMode("all")
            }
            let config = BalanceSweepConfig(
                mode: mode,
                battlesPerTier: battlesPerTier,
                seed: seed,
                tiers: tiers,
                maxRounds: maxRounds,
                maxActions: maxActions,
                outputDirectory: outputDirectory,
                jobs: jobs,
                workOffset: workOffset,
                workLimit: workLimit,
                appliesFightPacing: appliesFightPacing,
                policyID: policyID,
                comparePolicies: comparePolicies,
                heroIDs: heroIDs,
                companionIDs: companionIDs,
                enemyIDs: enemyIDs,
                focusIDs: focusIDs
            )
            let roster = config.resolvedRoster
            if roster.heroes.isEmpty || roster.companions.isEmpty || roster.enemies.isEmpty {
                throw CLIError.emptyFilter
            }
            return ParsedInvocation(
                config: config,
                isWorker: isWorker,
                outputFile: outputFile,
                deprecatedBattlesPerTier: deprecatedBattlesPerTier,
                writeFullMarkdown: writeFullMarkdown
            )
        }
    }

    private static func parseInvocation(_ arguments: [String]) throws -> ParsedInvocation {
        var flags = FlagState()
        var index = 0
        while index < arguments.count {
            try flags.consume(arguments, index: &index)
            index += 1
        }
        return try flags.makeInvocation()
    }

    private static func parseTiers(_ raw: String) throws -> [SimulationPowerTier] {
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return try parts.map { part -> SimulationPowerTier in
            guard let tier = SimulationPowerTier(rawValue: part)
                ?? SimulationPowerTier(rawValue: part.lowercased())
                ?? aliasTier[part.lowercased()]
            else {
                throw CLIError.invalidTier(raw)
            }
            return tier
        }
    }

    private static let aliasTier: [String: SimulationPowerTier] = [
        "early": .early,
        "mid": .middle,
        "middle": .middle,
        "late": .lateGame,
        "lategame": .lateGame,
        "lateGame": .lateGame,
    ]

    private static func stringValue(
        after flag: String,
        in arguments: [String],
        index: inout Int
    ) throws -> String {
        index += 1
        guard index < arguments.count else { throw CLIError.missingValue(flag) }
        return arguments[index]
    }

    private static func csvValue(
        after flag: String,
        in arguments: [String],
        index: inout Int
    ) throws -> [String] {
        try stringValue(after: flag, in: arguments, index: &index)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func intValue(
        after flag: String,
        in arguments: [String],
        index: inout Int
    ) throws -> Int {
        let raw = try stringValue(after: flag, in: arguments, index: &index)
        guard let value = Int(raw), value > 0 else { throw CLIError.invalidInt(flag, raw) }
        return value
    }

    private static func nonNegativeIntValue(
        after flag: String,
        in arguments: [String],
        index: inout Int
    ) throws -> Int {
        let raw = try stringValue(after: flag, in: arguments, index: &index)
        guard let value = Int(raw), value >= 0 else { throw CLIError.invalidInt(flag, raw) }
        return value
    }

    private static func uintValue(
        after flag: String,
        in arguments: [String],
        index: inout Int
    ) throws -> UInt64 {
        let raw = try stringValue(after: flag, in: arguments, index: &index)
        guard let value = UInt64(raw) else { throw CLIError.invalidInt(flag, raw) }
        return value
    }
}

/// Disk I/O stays in the CLI entrypoint so the BattleEngine library remains pure.
private enum BalanceSweepCLIFiles {
    struct WrittenReport {
        var findingsURL: URL
        var fullMarkdownURL: URL?
    }

    static func write(
        findings: String,
        fullMarkdown: String?,
        report: BalanceSweepReport,
        toDirectory directoryPath: String,
        fileManager: FileManager = .default
    ) throws -> WrittenReport {
        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let stem = "\(stamp)-\(report.config.mode.rawValue)-seed\(report.config.seed)"
        let findingsURL = directory.appendingPathComponent("\(stem).md")
        try findings.write(to: findingsURL, atomically: true, encoding: .utf8)
        let jsonURL = findingsURL.deletingPathExtension().appendingPathExtension("json")
        try JSONEncoder().encode(report).write(to: jsonURL, options: .atomic)
        FileHandle.standardError.write(Data("Wrote \(jsonURL.path)\n".utf8))
        var fullURL: URL?
        if let fullMarkdown {
            let url = directory.appendingPathComponent("\(stem)-full.md")
            try fullMarkdown.write(to: url, atomically: true, encoding: .utf8)
            fullURL = url
        }
        return WrittenReport(findingsURL: findingsURL, fullMarkdownURL: fullURL)
    }

    static func announce(_ written: WrittenReport) {
        FileHandle.standardError.write(Data("Wrote \(written.findingsURL.path)\n".utf8))
        if let fullURL = written.fullMarkdownURL {
            FileHandle.standardError.write(Data("Wrote \(fullURL.path)\n".utf8))
        } else {
            FileHandle.standardError.write(Data(
                "full markdown omitted (pass --full-markdown)\n".utf8
            ))
        }
    }
}

private enum CLIError: Error, CustomStringConvertible {
    case unknownArgument(String)
    case missingValue(String)
    case invalidInt(String, String)
    case invalidTier(String)
    case invalidMode(String)
    case invalidPolicy(String)
    case emptyFilter

    var description: String {
        switch self {
        case let .unknownArgument(arg):
            "unknown argument \(arg)"
        case let .missingValue(flag):
            "\(flag) requires a value"
        case let .invalidInt(flag, raw):
            "\(flag) invalid integer \(raw)"
        case let .invalidTier(raw):
            "invalid tiers \(raw)"
        case let .invalidMode(raw):
            "invalid mode \(raw)"
        case let .invalidPolicy(raw):
            "invalid policy \(raw); use greedy-v1 or setup-v1"
        case .emptyFilter:
            "--hero/--companion/--enemy matched no combatants"
        }
    }
}
