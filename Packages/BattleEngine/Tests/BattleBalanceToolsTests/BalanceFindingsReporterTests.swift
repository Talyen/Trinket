import BattleEngine
import Testing
@testable import BattleBalanceTools

struct BalanceFindingsReporterTests {
    @Test func `findings omit presence tables and include flagged enemy`() {
        var records: [BalanceBattleRecord] = []
        for index in 0 ..< 10 {
            records.append(identityRecord(
                enemyID: "slime",
                isBoss: false,
                abilities: ["caustic-jab", "panacea-potion"],
                win: true,
                seed: UInt64(index),
            ))
            records.append(identityRecord(
                enemyID: "the_forge_golem",
                isBoss: true,
                abilities: ["bash", "molten-bulwark"],
                win: false,
                seed: UInt64(index + 20),
            ))
        }
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(mode: .identity, battlesPerTier: 10, tiers: [.early], jobs: 1),
            policyID: "greedy-v1",
            records: records,
            elapsedSeconds: 0,
        )
        let findings = BalanceFindingsReporter.render(report)
        let full = BalanceMarkdownReporter.render(report)
        #expect(findings.contains("# Balance Sweep Findings"))
        #expect(findings.contains("per identity enemy / contrast focus"))
        #expect(findings.contains("Identity battles: `20`"))
        #expect(findings.contains("`the_forge_golem`"))
        #expect(findings.contains("molten-bulwark"))
        #expect(!findings.contains("Party Abilities (within owner)"))
        #expect(!findings.contains("n too low to flag"))
        #expect(full.contains("Party Abilities (within owner)"))
    }

    @Test func `findings list flagged contrasts without full tables`() {
        let contrast = PairedContrastSummary(
            entityID: "cinderbloom",
            baselineID: "fireball",
            ownerID: "phoenix",
            tier: .early,
            baselineKind: .sibling,
            pairs: 32,
            decidedPairs: 32,
            winsWithEntity: 26,
            winsWithBaseline: 20,
            entityOnlyWins: 6,
            baselineOnlyWins: 0,
            lift: 0.1875,
            flagged: true,
            flagReason: "HIGH",
        )
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(
                mode: .abilityContrast,
                battlesPerTier: 32,
                tiers: [.early],
                jobs: 1,
            ),
            policyID: "greedy-v1",
            abilityContrasts: [contrast],
            elapsedSeconds: 0,
        )
        let findings = BalanceFindingsReporter.render(report)
        #expect(findings.contains("`cinderbloom`"))
        #expect(findings.contains("`fireball`"))
        #expect(!findings.contains("Party Abilities (within owner)"))
        #expect(!findings.contains("Ability Contrasts (paired lift vs sibling choice)"))
    }

    @Test func `findings list progression hotspots without node census`() {
        let step = ModeProgressionStep(
            id: "stage-3-10",
            mode: .campaign,
            containerID: "chapter-3",
            containerTitle: "Chapter 3: Desert",
            stepIndex: 10,
            displayTitle: "Stage 3-10",
            enemyID: "the_forge_golem",
            enemyLevel: 15,
            isBoss: true,
        )
        let flagged = NodeHotspotSummary(
            step: step,
            battles: 32,
            wins: 16,
            winRate: 0.5,
            wilsonLow: 0.34,
            wilsonHigh: 0.66,
            averagePlayerLevel: 21,
            averageEnemyLevel: 15,
            averageEnemyPowerRating: 892,
            status: .overtuned,
            flagReason: "Win rate 50.0% below 80%",
        )
        let smoothStep = ModeProgressionStep(
            id: "stage-1-1",
            mode: .campaign,
            containerID: "chapter-1",
            containerTitle: "Chapter 1: Forest",
            stepIndex: 1,
            displayTitle: "Stage 1-1",
            enemyID: "slime",
            enemyLevel: 1,
            isBoss: false,
        )
        let smooth = NodeHotspotSummary(
            step: smoothStep,
            battles: 32,
            wins: 32,
            winRate: 1,
            wilsonLow: 0.89,
            wilsonHigh: 1,
            averagePlayerLevel: 1,
            averageEnemyLevel: 1,
            averageEnemyPowerRating: 273,
            status: .smooth,
        )
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(mode: .modeProgression, battlesPerTier: 32, jobs: 1),
            policyID: "greedy-v1",
            progressionHotspots: [flagged, smooth],
            progressionPlayerStates: [PlayerProgressionState()],
            elapsedSeconds: 0,
        )
        let findings = BalanceFindingsReporter.render(report)
        let full = BalanceMarkdownReporter.render(report)
        #expect(findings.contains("OVERTUNED"))
        #expect(findings.contains("Stage 3-10"))
        #expect(!findings.contains("Campaign Progression Detail"))
        #expect(full.contains("Campaign Progression Detail"))
    }

    @Test func `findings include compared policy win rate`() {
        var records: [BalanceBattleRecord] = []
        var compared: [BalanceBattleRecord] = []
        for index in 0 ..< 8 {
            records.append(identityRecord(
                enemyID: "slime",
                isBoss: false,
                abilities: ["bash"],
                win: index < 4,
                seed: UInt64(index),
            ))
            compared.append(identityRecord(
                enemyID: "slime",
                isBoss: false,
                abilities: ["bash"],
                win: true,
                seed: UInt64(index + 40),
            ))
        }
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(mode: .identity, battlesPerTier: 8, tiers: [.early], jobs: 1),
            policyID: "greedy-v1",
            records: records,
            comparedPolicyID: "optimal-v1",
            comparedRecords: compared,
            elapsedSeconds: 0,
        )
        let findings = BalanceFindingsReporter.render(report)
        #expect(findings.contains("Compared policy: `optimal-v1`"))
        #expect(findings.contains("`optimal-v1`"))
        #expect(findings.contains("win (Δ"))
    }

    private func identityRecord(
        enemyID: String,
        isBoss: Bool,
        abilities: [String],
        win: Bool,
        seed: UInt64,
    ) -> BalanceBattleRecord {
        BalanceBattleRecord(
            tier: .early,
            heroID: "knight",
            companionID: "bear",
            enemyID: enemyID,
            isBoss: isBoss,
            heroAbilityIDs: ["bash", "smite"],
            companionAbilityIDs: ["maul"],
            enemyAbilityIDs: abilities,
            enemyTraitID: "\(enemyID)_trait",
            affixIDs: [],
            heroTalentIDs: [],
            companionTalentIDs: [],
            seed: seed,
            policyID: "greedy-v1",
            result: BattleSimResult(
                outcome: win ? .victory : .defeat,
                rounds: win ? 6 : 18,
                actions: 12,
                timedOut: false,
                partyHPRemainingFraction: win ? 0.8 : 0,
                enemyHPRemainingFraction: win ? 0 : 0.7,
            ),
        )
    }
}
