import BattleBalanceTools
import BattleEngine
import Foundation
import TrinketContent

/// Command-line surface for `BalanceSweepCLI`: help text, flag parsing, and
/// invocation building. Sweep execution stays in `BalanceSweepCLIMain`.
extension BalanceSweepCLI {
    static var usageText: String {
        """
        Usage: BalanceSweepCLI [options]

          --mode <name>            identity | ability-contrast | affix-contrast | talent-contrast |
                                   mode-progression | all (default: identity)
          --samples <n>            Observations per identity enemy and pairs per contrast focus
                                   per tier (default: 32)
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
                                    (contrast modes only; ignored by identity/mode-progression)
          --work-offset <n>        Internal chunking: skip the first n work items (default: 0)
          --work-limit <n>         Internal chunking: run at most n work items
          --peer-delta <f>         Internal forwarding: paired lift flag threshold pp/100 (default: 0.10)
          --duration-flag-rate <f> Internal forwarding: stall flag rate (default: 0.15)
          --comfort-hp <f>         Internal forwarding: comfort HP delta threshold (default: 0.10)
          --comfort-rounds <f>     Internal forwarding: comfort rounds delta threshold (default: 2.0)
          --full-markdown          Also write the verbose table dump as *-full.md
          --help                   Show this help

        Combat runs in child processes of this binary (never on GCD). Each child
        writes a JSON slice; the parent merges, writes a findings markdown brief
        and a JSON sidecar. Read the findings file; open JSON or pass
        --full-markdown only when drilling into a named finding.
        """
    }

    struct ParsedInvocation {
        var config: BalanceSweepConfig
        var isWorker: Bool
        var outputFile: String?
        var writeFullMarkdown: Bool
    }

    struct FlagState {
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
        var policyID = PlayPolicy.greedy.rawValue
        var comparePolicies = false
        var heroIDs: [String] = []
        var companionIDs: [String] = []
        var enemyIDs: [String] = []
        var focusIDs: [String] = []
        var peerDeltaFlagThreshold = 0.10
        var durationFlagRate = BalanceSweepConfig.durationFlagRateDefault
        var comfortHPThreshold = BalanceSweepConfig.comfortHPThresholdDefault
        var comfortRoundThreshold = BalanceSweepConfig.comfortRoundThresholdDefault
        var writeFullMarkdown = false

        mutating func consume(_ arguments: [String], index: inout Int) throws {
            let arg = arguments[index]
            switch arg {
            case "--worker":
                isWorker = true
            case "--hero":
                heroIDs = try BalanceSweepCLI.csvValue(after: arg, in: arguments, index: &index)
            case "--companion":
                companionIDs = try BalanceSweepCLI.csvValue(after: arg, in: arguments, index: &index)
            case "--enemy":
                enemyIDs = try BalanceSweepCLI.csvValue(after: arg, in: arguments, index: &index)
            case "--focus":
                focusIDs = try BalanceSweepCLI.csvValue(after: arg, in: arguments, index: &index)
            case "--mode":
                let raw = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
                guard let parsed = BalanceSweepMode(rawValue: raw) else {
                    throw CLIError.invalidMode(raw)
                }
                mode = parsed
            case "--samples":
                battlesPerTier = try BalanceSweepCLI.intValue(after: arg, in: arguments, index: &index)
            case "--seed":
                seed = try BalanceSweepCLI.uintValue(after: arg, in: arguments, index: &index)
            case "--tiers":
                let raw = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
                tiers = try BalanceSweepCLI.parseTiers(raw)
            default:
                try consumeRunFlags(arg, arguments: arguments, index: &index)
            }
        }

        mutating func consumeRunFlags(_ arg: String, arguments: [String], index: inout Int) throws {
            switch arg {
            case "--jobs":
                jobs = try BalanceSweepCLI.intValue(after: arg, in: arguments, index: &index)
            case "--output-dir":
                outputDirectory = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
            case "--max-rounds":
                maxRounds = try BalanceSweepCLI.intValue(after: arg, in: arguments, index: &index)
            case "--max-actions":
                maxActions = try BalanceSweepCLI.intValue(after: arg, in: arguments, index: &index)
            case "--work-offset":
                workOffset = try BalanceSweepCLI.nonNegativeIntValue(after: arg, in: arguments, index: &index)
            case "--work-limit":
                workLimit = try BalanceSweepCLI.intValue(after: arg, in: arguments, index: &index)
            case "--output-file":
                outputFile = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
            case "--peer-delta":
                peerDeltaFlagThreshold = try BalanceSweepCLI.doubleValue(after: arg, in: arguments, index: &index)
            case "--duration-flag-rate":
                durationFlagRate = try BalanceSweepCLI.doubleValue(after: arg, in: arguments, index: &index)
            case "--comfort-hp":
                comfortHPThreshold = try BalanceSweepCLI.doubleValue(after: arg, in: arguments, index: &index)
            case "--comfort-rounds":
                comfortRoundThreshold = try BalanceSweepCLI.doubleValue(after: arg, in: arguments, index: &index)
            case "--pacing":
                let raw = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
                switch raw.lowercased() {
                case "on", "true", "1": appliesFightPacing = true
                case "off", "false", "0": appliesFightPacing = false
                default: throw CLIError.invalidInt("--pacing", raw)
                }
            case "--policy":
                policyID = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
                guard PlayPolicy(rawValue: policyID) != nil else {
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
                peerDeltaFlagThreshold: peerDeltaFlagThreshold,
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
                focusIDs: focusIDs,
                durationFlagRate: durationFlagRate,
                comfortHPThreshold: comfortHPThreshold,
                comfortRoundThreshold: comfortRoundThreshold,
            )
            let roster = config.resolvedRoster
            if roster.heroes.isEmpty || roster.companions.isEmpty || roster.enemies.isEmpty {
                throw CLIError.emptyFilter
            }
            return ParsedInvocation(
                config: config,
                isWorker: isWorker,
                outputFile: outputFile,
                writeFullMarkdown: writeFullMarkdown,
            )
        }
    }

    static func parseInvocation(_ arguments: [String]) throws -> ParsedInvocation {
        var flags = FlagState()
        var index = 0
        while index < arguments.count {
            try flags.consume(arguments, index: &index)
            index += 1
        }
        return try flags.makeInvocation()
    }

    static func parseTiers(_ raw: String) throws -> [SimulationPowerTier] {
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

    static let aliasTier: [String: SimulationPowerTier] = [
        "early": .early,
        "mid": .middle,
        "middle": .middle,
        "late": .lateGame,
        "lategame": .lateGame,
        "lateGame": .lateGame,
    ]

    static func stringValue(
        after flag: String,
        in arguments: [String],
        index: inout Int,
    ) throws -> String {
        index += 1
        guard index < arguments.count else { throw CLIError.missingValue(flag) }
        return arguments[index]
    }

    static func csvValue(
        after flag: String,
        in arguments: [String],
        index: inout Int,
    ) throws -> [String] {
        try stringValue(after: flag, in: arguments, index: &index)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func intValue(
        after flag: String,
        in arguments: [String],
        index: inout Int,
    ) throws -> Int {
        let raw = try stringValue(after: flag, in: arguments, index: &index)
        guard let value = Int(raw), value > 0 else { throw CLIError.invalidInt(flag, raw) }
        return value
    }

    static func nonNegativeIntValue(
        after flag: String,
        in arguments: [String],
        index: inout Int,
    ) throws -> Int {
        let raw = try stringValue(after: flag, in: arguments, index: &index)
        guard let value = Int(raw), value >= 0 else { throw CLIError.invalidInt(flag, raw) }
        return value
    }

    static func uintValue(
        after flag: String,
        in arguments: [String],
        index: inout Int,
    ) throws -> UInt64 {
        let raw = try stringValue(after: flag, in: arguments, index: &index)
        guard let value = UInt64(raw) else { throw CLIError.invalidInt(flag, raw) }
        return value
    }

    static func doubleValue(
        after flag: String,
        in arguments: [String],
        index: inout Int,
    ) throws -> Double {
        let raw = try stringValue(after: flag, in: arguments, index: &index)
        guard let value = Double(raw) else { throw CLIError.invalidDouble(flag, raw) }
        return value
    }
}
