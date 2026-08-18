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
                \(parsed.config.battlesPerTier)/tier seed=\(parsed.config.seed) \
                jobs=\(parsed.config.resolvedJobs) …
                """.utf8
            ))

            let report: BalanceSweepReport
            #if os(macOS)
            report = try BalanceSweepProcessOrchestrator.run(
                config: parsed.config,
                executablePath: CommandLine.arguments[0]
            )
            #else
            report = BalanceSweepRunner.run(config: parsed.config)
            #endif
            let markdown = BalanceMarkdownReporter.render(report)
            let url = try writeReport(markdown, report: report, toDirectory: parsed.config.outputDirectory)

            print(markdown)
            FileHandle.standardError.write(Data("Wrote \(url.path)\n".utf8))
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

    /// Disk I/O stays in the CLI entrypoint so the BattleEngine library remains pure.
    private static func writeReport(
        _ markdown: String,
        report: BalanceSweepReport,
        toDirectory directoryPath: String,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let filename = "\(stamp)-\(report.config.mode.rawValue)-seed\(report.config.seed).md"
        let fileURL = directory.appendingPathComponent(filename)
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private static var usageText: String {
        """
        Usage: BalanceSweepCLI [options]

          --mode <name>            identity | ability-contrast | affix-contrast | talent-contrast |
                                   mode-progression | all (default: identity)
          --battles-per-tier <n>   Battles/pairs per power tier (default: 100)
          --seed <n>               Sweep seed (default: 1)
          --tiers <list>           Comma list: early,middle,lateGame (default: all)
          --jobs <n>               Concurrent worker processes (default: CPU count)
          --output-dir <path>      Markdown output directory (default: BalanceSweepReports)
          --max-rounds <n>         Stall cap rounds (default: 100)
          --max-actions <n>        Stall cap actions (default: 500)
          --help                   Show this help

        Combat runs in child processes of this binary (never on GCD). Each child
        writes a JSON slice; the parent merges and renders markdown.
        """
    }

    private struct ParsedInvocation {
        var config: BalanceSweepConfig
        var isWorker: Bool
        var outputFile: String?
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

        mutating func consume(_ arguments: [String], index: inout Int) throws {
            let arg = arguments[index]
            if arg == "--worker" {
                isWorker = true
                return
            }
            try consumeValued(arg, arguments: arguments, index: &index)
        }

        mutating func consumeValued(_ arg: String, arguments: [String], index: inout Int) throws {
            switch arg {
            case "--mode":
                let raw = try stringValue(after: arg, in: arguments, index: &index)
                guard let parsed = BalanceSweepMode(rawValue: raw) else {
                    throw CLIError.invalidMode(raw)
                }
                mode = parsed
            case "--battles-per-tier":
                battlesPerTier = try intValue(after: arg, in: arguments, index: &index)
            case "--seed":
                seed = try uintValue(after: arg, in: arguments, index: &index)
            case "--tiers":
                let raw = try stringValue(after: arg, in: arguments, index: &index)
                tiers = try parseTiers(raw)
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
                throw CLIError.unknownArgument(arg)
            }
        }

        func makeInvocation() throws -> ParsedInvocation {
            if isWorker, mode == .all {
                throw CLIError.invalidMode("all")
            }
            return ParsedInvocation(
                config: BalanceSweepConfig(
                    mode: mode,
                    battlesPerTier: battlesPerTier,
                    seed: seed,
                    tiers: tiers,
                    maxRounds: maxRounds,
                    maxActions: maxActions,
                    outputDirectory: outputDirectory,
                    jobs: jobs,
                    workOffset: workOffset,
                    workLimit: workLimit
                ),
                isWorker: isWorker,
                outputFile: outputFile
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

private enum CLIError: Error, CustomStringConvertible {
    case unknownArgument(String)
    case missingValue(String)
    case invalidInt(String, String)
    case invalidTier(String)
    case invalidMode(String)

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
        }
    }
}
