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
                """.utf8,
            ))
            if parsed.deprecatedBattlesPerTier {
                FileHandle.standardError.write(Data(
                    "--battles-per-tier is deprecated; it is an alias for --samples (n per enemy / pairs per focus).\n".utf8,
                ))
            }
            if parsed.config.battlesPerTier < BalanceSweepConfig.contrastFlagMinPairs {
                FileHandle.standardError.write(Data(
                    "warning: samples < \(BalanceSweepConfig.contrastFlagMinPairs); contrast flags are disabled.\n".utf8,
                ))
            }
            if !parsed.config.focusIDs.isEmpty,
               parsed.config.mode == .identity || parsed.config.mode == .modeProgression {
                FileHandle.standardError.write(Data(
                    "warning: --focus is ignored in \(parsed.config.mode.rawValue) mode.\n".utf8,
                ))
            }

            let report: BalanceSweepReport
            #if os(macOS)
            report = try BalanceSweepProcessOrchestrator.run(
                config: parsed.config,
                executablePath: CommandLine.arguments[0],
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
                toDirectory: parsed.config.outputDirectory,
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
}

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
        fileManager: FileManager = .default,
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
                "full markdown omitted (pass --full-markdown)\n".utf8,
            ))
        }
    }
}

enum CLIError: Error, CustomStringConvertible {
    case unknownArgument(String)
    case missingValue(String)
    case invalidInt(String, String)
    case invalidDouble(String, String)
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
        case let .invalidDouble(flag, raw):
            "\(flag) invalid number \(raw)"
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
