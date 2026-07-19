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
            let config = try parseConfig(arguments)
            FileHandle.standardError.write(Data(
                """
                Running balance sweep mode=\(config.mode.rawValue) \
                \(config.battlesPerTier)/tier seed=\(config.seed) jobs=\(config.resolvedJobs) …
                """.utf8
            ))

            let report = BalanceSweepRunner.run(config: config)
            let markdown = BalanceMarkdownReporter.render(report)
            let url = try writeReport(markdown, report: report, toDirectory: config.outputDirectory)

            print(markdown)
            FileHandle.standardError.write(Data("Wrote \(url.path)\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            FileHandle.standardError.write(Data(usageText.utf8))
            exit(1)
        }
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

          --mode <name>            identity | ability-contrast | affix-contrast | all
                                   (default: identity)
          --battles-per-tier <n>   Battles/pairs per power tier (default: 1000)
          --seed <n>               Sweep seed (default: 1)
          --tiers <list>           Comma list: early,middle,lateGame (default: all)
          --jobs <n>               Parallel workers (default: CPU count; 1 = sequential)
          --output-dir <path>      Markdown output directory (default: BalanceSweepReports)
          --max-rounds <n>         Stall cap rounds (default: 100)
          --max-actions <n>        Stall cap actions (default: 500)
          --help                   Show this help
        """
    }

    private static func parseConfig(_ arguments: [String]) throws -> BalanceSweepConfig {
        var mode: BalanceSweepMode = .identity
        var battlesPerTier = BalanceSweepConfig.defaultBattlesPerTier
        var seed: UInt64 = 1
        var tiers = SimulationPowerTier.allCases
        var outputDirectory = BalanceSweepConfig.defaultOutputDirectory
        var maxRounds = BattleSimulator.defaultMaxRounds
        var maxActions = BattleSimulator.defaultMaxActions
        var jobs = 0

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
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
            default:
                throw CLIError.unknownArgument(arg)
            }
            index += 1
        }

        return BalanceSweepConfig(
            mode: mode,
            battlesPerTier: battlesPerTier,
            seed: seed,
            tiers: tiers,
            maxRounds: maxRounds,
            maxActions: maxActions,
            outputDirectory: outputDirectory,
            jobs: jobs
        )
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
        "lateGame": .lateGame
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
