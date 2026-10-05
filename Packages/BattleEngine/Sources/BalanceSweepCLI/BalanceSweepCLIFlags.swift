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
          --contrast-talents <id>  tier | minimal (default: tier; minimal is a diagnostic)
          --hero <ids>             Comma hero ids (default: all)
          --companion <ids>        Comma companion ids (default: all)
          --enemy <ids>            Comma enemy ids (default: all)
          --focus <ids>            Restrict contrast foci to these ability/affix/talent ids
                                    (contrast modes only; ignored by identity/mode-progression)
          --work-offset <n>        Internal chunking: skip the first n work items (default: 0)
          --work-limit <n>         Internal chunking: run at most n work items
          --peer-delta <f>         Flag threshold: paired lift flag threshold pp/100 (default: 0.10)
          --duration-flag-rate <f> Flag threshold: stall flag rate (default: 0.15)
          --comfort-hp <f>         Flag threshold: comfort HP delta threshold (default: 0.10)
          --comfort-rounds <f>     Flag threshold: comfort rounds delta threshold (default: 2.0)
          --full-markdown          Also write the verbose table dump as *-full.md
          --help                   Show this help

        Combat runs in child processes of this binary (never on GCD). Each child
        writes a JSON slice; the parent merges, writes a findings markdown brief
        and a JSON sidecar. Read the findings file; open JSON or pass
        --full-markdown only when drilling into a named finding.
        """
    }

    struct ParsedInvocation {
        var config = BalanceSweepConfig()
        var writeFullMarkdown = false

        mutating func consume(_ arguments: [String], index: inout Int) throws {
            let arg = arguments[index]
            switch arg {
            case "--hero":
                config.heroIDs = try BalanceSweepCLI.csvValue(after: arg, in: arguments, index: &index)
            case "--companion":
                config.companionIDs = try BalanceSweepCLI.csvValue(after: arg, in: arguments, index: &index)
            case "--enemy":
                config.enemyIDs = try BalanceSweepCLI.csvValue(after: arg, in: arguments, index: &index)
            case "--focus":
                config.focusIDs = try BalanceSweepCLI.csvValue(after: arg, in: arguments, index: &index)
            case "--mode":
                let raw = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
                guard let parsed = BalanceSweepMode(rawValue: raw) else {
                    throw CLIError.invalidMode(raw)
                }
                config.mode = parsed
            case "--samples":
                config.battlesPerTier = try BalanceSweepCLI.intValue(after: arg, in: arguments, index: &index)
            case "--seed":
                config.seed = try BalanceSweepCLI.uintValue(after: arg, in: arguments, index: &index)
            case "--tiers":
                let raw = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
                config.tiers = try BalanceSweepCLI.parseTiers(raw)
            default:
                try consumeRunFlags(arg, arguments: arguments, index: &index)
            }
        }

        mutating func consumeRunFlags(_ arg: String, arguments: [String], index: inout Int) throws {
            switch arg {
            case "--jobs":
                config.jobs = try BalanceSweepCLI.intValue(after: arg, in: arguments, index: &index)
            case "--output-dir":
                config.outputDirectory = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
            case "--max-rounds":
                config.maxRounds = try BalanceSweepCLI.intValue(after: arg, in: arguments, index: &index)
            case "--max-actions":
                config.maxActions = try BalanceSweepCLI.intValue(after: arg, in: arguments, index: &index)
            case "--work-offset":
                config.workOffset = try BalanceSweepCLI.intValue(after: arg, in: arguments, index: &index, minimum: 0)
            case "--work-limit":
                config.workLimit = try BalanceSweepCLI.intValue(after: arg, in: arguments, index: &index)
            case "--peer-delta":
                config.peerDeltaFlagThreshold = try BalanceSweepCLI.doubleValue(after: arg, in: arguments, index: &index)
            case "--duration-flag-rate":
                config.durationFlagRate = try BalanceSweepCLI.doubleValue(after: arg, in: arguments, index: &index)
            case "--comfort-hp":
                config.comfortHPThreshold = try BalanceSweepCLI.doubleValue(after: arg, in: arguments, index: &index)
            case "--comfort-rounds":
                config.comfortRoundThreshold = try BalanceSweepCLI.doubleValue(after: arg, in: arguments, index: &index)
            case "--pacing":
                let raw = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
                switch raw.lowercased() {
                case "on", "true", "1": config.appliesFightPacing = true
                case "off", "false", "0": config.appliesFightPacing = false
                default: throw CLIError.invalidPacing(raw)
                }
            case "--policy":
                config.policyID = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
                guard PlayPolicy(rawValue: config.policyID) != nil else {
                    throw CLIError.invalidPolicy(config.policyID)
                }
            case "--policy-compare":
                config.comparePolicies = true
            case "--contrast-talents":
                let raw = try BalanceSweepCLI.stringValue(after: arg, in: arguments, index: &index)
                switch raw {
                case "tier": config.usesTierTalentBuilds = true
                case "minimal": config.usesTierTalentBuilds = false
                default: throw CLIError.unknownArgument("\(arg) \(raw)")
                }
            case "--full-markdown":
                writeFullMarkdown = true
            default:
                throw CLIError.unknownArgument(arg)
            }
        }
    }

    static func parseInvocation(_ arguments: [String]) throws -> ParsedInvocation {
        var invocation = ParsedInvocation()
        var index = 0
        while index < arguments.count {
            try invocation.consume(arguments, index: &index)
            index += 1
        }
        let roster = invocation.config.resolvedRoster
        guard !roster.heroes.isEmpty, !roster.companions.isEmpty, !roster.enemies.isEmpty else {
            throw CLIError.emptyFilter
        }
        return invocation
    }

    static func parseTiers(_ raw: String) throws -> [SimulationPowerTier] {
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else { return SimulationPowerTier.allCases }
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
        "mid": .middle,
        "late": .lateGame,
        "lategame": .lateGame,
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
        minimum: Int = 1,
    ) throws -> Int {
        let raw = try stringValue(after: flag, in: arguments, index: &index)
        guard let value = Int(raw), value >= minimum else { throw CLIError.invalidInt(flag, raw) }
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
        guard let value = Double(raw), value.isFinite else { throw CLIError.invalidDouble(flag, raw) }
        return value
    }
}
