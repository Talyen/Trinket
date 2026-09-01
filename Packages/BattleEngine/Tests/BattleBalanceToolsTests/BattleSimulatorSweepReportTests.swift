import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

@Suite(.serialized)
struct BattleSimulatorSweepReportTests {
    @Test func `parallel identity matches sequential outcomes`() {
        let sequential = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 6,
                seed: 11,
                tiers: [.early],
                jobs: 1,
                enemyIDs: ["living_armor"],
            ),
        )
        let parallel = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 6,
                seed: 11,
                tiers: [.early],
                jobs: 4,
                enemyIDs: ["living_armor"],
            ),
        )
        #expect(sequential.records.map(\.result) == parallel.records.map(\.result))
        #expect(sequential.records.map(\.seed) == parallel.records.map(\.seed))
    }

    @Test func `ability contrast produces lift rows`() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .abilityContrast,
                battlesPerTier: 2,
                seed: 21,
                tiers: [.early],
                jobs: 1,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                enemyIDs: ["living_armor"],
                focusIDs: ["bash"],
            ),
        )
        #expect(report.records.isEmpty)
        #expect(!(report.abilityContrasts.isEmpty))
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("Ability Contrasts"))
    }

    @Test func `affix contrast produces lift rows on mid tier`() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .affixContrast,
                battlesPerTier: 8,
                seed: 22,
                tiers: [.middle],
                jobs: 1,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                enemyIDs: ["living_armor"],
                focusIDs: ["keen"],
            ),
        )
        let markdown = BalanceMarkdownReporter.render(report)
        if report.affixContrasts.isEmpty {
            #expect(markdown.contains("Affix contrast rows: `0`"))
        } else {
            #expect(report.affixContrasts.contains { $0.baselineKind == .emptySlot })
            #expect(report.affixContrasts.contains { $0.baselineKind == .replacementAffix })
            #expect(markdown.contains("Affix Contrasts"))
        }
    }

    @Test func `identity quotas equal battles per enemy`() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 3,
                seed: 9,
                tiers: [.early],
                jobs: 1,
                enemyIDs: ["living_armor", "mimic"],
            ),
        )
        #expect(report.records.count == 6)
        let byEnemy = Dictionary(grouping: report.records, by: \.enemyID)
        #expect(byEnemy["living_armor"]?.count == 3)
        #expect(byEnemy["mimic"]?.count == 3)
    }

    @Test func `identity work slices concatenate to full sweep`() {
        let config = BalanceSweepConfig(
            mode: .identity,
            battlesPerTier: 8,
            seed: 11,
            tiers: [.early],
            jobs: 1,
            enemyIDs: ["living_armor"],
        )
        let full = BalanceSweepRunner.run(config: config)
        let first = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 8,
                seed: 11,
                tiers: [.early],
                jobs: 1,
                workOffset: 0,
                workLimit: 4,
                enemyIDs: ["living_armor"],
            ),
        )
        let second = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 8,
                seed: 11,
                tiers: [.early],
                jobs: 1,
                workOffset: 4,
                workLimit: 4,
                enemyIDs: ["living_armor"],
            ),
        )
        let merged = BalanceSweepReport.merged(
            [first, second],
            config: config,
            policyID: full.policyID,
            elapsedSeconds: 0,
        )
        #expect(first.records.count == 4)
        #expect(second.records.count == 4)
        #expect(merged.records.map(\.result) == full.records.map(\.result))
        #expect(merged.records.map(\.seed) == full.records.map(\.seed))
    }

    @Test func `identity early spends one talent and one starter item`() {
        let early = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 2,
                seed: 4,
                tiers: [.early],
                jobs: 1,
                enemyIDs: ["living_armor"],
            ),
        )
        #expect(early.records.count == 2)
        #expect(SimulationPowerTier.early.identityTalentPointCap == 1)
        for record in early.records {
            #expect(record.heroTalentIDs.count == 1)
            #expect(record.companionTalentIDs.count == 1)
            #expect(record.heroAffixIDs.count == 1)
            #expect(record.companionAffixIDs.count == 1)
            expectLegalTalentSpend(Set(record.heroTalentIDs), combatantID: record.heroID)
            expectLegalTalentSpend(Set(record.companionTalentIDs), combatantID: record.companionID)
        }

        let middle = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 1,
                seed: 5,
                tiers: [.middle],
                jobs: 1,
                enemyIDs: ["living_armor"],
            ),
        )
        #expect(middle.records.count == 1)
        let middleRecord = middle.records[0]
        let middleBudget = CombatantProgression.at(level: SimulationPowerTier.middle.level).totalTalentPoints
        #expect(middleRecord.heroTalentIDs.count == middleBudget)
        #expect(middleRecord.companionTalentIDs.count == middleBudget)
        expectLegalTalentSpend(Set(middleRecord.heroTalentIDs), combatantID: middleRecord.heroID)
        expectLegalTalentSpend(Set(middleRecord.companionTalentIDs), combatantID: middleRecord.companionID)

        let late = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 1,
                seed: 6,
                tiers: [.lateGame],
                jobs: 1,
                enemyIDs: ["living_armor"],
            ),
        )
        #expect(late.records.count == 1)
        let lateRecord = late.records[0]
        let lateBudget = CombatantProgression.at(level: SimulationPowerTier.lateGame.level).totalTalentPoints
        #expect(lateRecord.heroTalentIDs.count <= min(lateBudget, CombatantTalentCatalog.validNodeIDs(for: lateRecord.heroID).count))
        #expect(lateRecord.heroTalentIDs.count >= 18)
        #expect(lateRecord.companionTalentIDs.count <= min(
            lateBudget,
            CombatantTalentCatalog.validNodeIDs(for: lateRecord.companionID).count,
        ))
        #expect(lateRecord.companionTalentIDs.count >= 18)
        expectLegalTalentSpend(Set(lateRecord.heroTalentIDs), combatantID: lateRecord.heroID)
        expectLegalTalentSpend(Set(lateRecord.companionTalentIDs), combatantID: lateRecord.companionID)
    }

    private func expectLegalTalentSpend(_ ids: Set<String>, combatantID: String) {
        let config = CombatantTalentCatalog.config(for: combatantID)
        #expect(ids.isSubset(of: CombatantTalentCatalog.validNodeIDs(for: combatantID)))
        for tree in config.trees {
            let unlocked = Set(tree.nodes.map(\.id)).intersection(ids)
            for node in tree.nodes where unlocked.contains(node.id) && node.row >= 2 {
                #expect(tree.isRowComplete(node.row - 1, unlockedNodeIDs: unlocked))
            }
        }
    }

    @Test func `talent contrast produces sibling and kit lift rows`() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .talentContrast,
                battlesPerTier: 1,
                seed: 23,
                tiers: [.middle],
                jobs: 1,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                enemyIDs: ["living_armor"],
                focusIDs: ["knight_block_t1_1"],
            ),
        )
        #expect(report.records.isEmpty)
        #expect(!(report.talentContrasts.isEmpty))
        #expect(report.talentKitContrasts.isEmpty)
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("Talent Contrasts (paired lift vs sibling in the same row)"))
    }

    @Test func `talent contrast runs row one at early and skips full kit`() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .talentContrast,
                battlesPerTier: 2,
                seed: 23,
                tiers: [.early],
                jobs: 1,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                enemyIDs: ["living_armor"],
                focusIDs: ["knight_block_t1_1"],
            ),
        )
        #expect(!(report.talentContrasts.isEmpty))
        #expect(report.talentContrasts.allSatisfy { $0.tier == .early })
        #expect(report.talentKitContrasts.isEmpty)
    }

    @Test func `identity sweep produces markdown with secondary metrics`() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 4,
                seed: 3,
                tiers: [.early],
                jobs: 1,
                enemyIDs: ["living_armor"],
            ),
        )
        #expect(report.records.count == 4)
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("# Balance Sweep Report"))
        #expect(markdown.contains("### Heroes"))
        #expect(markdown.contains("### Duration"))
        #expect(markdown.contains("### Party Abilities"))
        #expect(markdown.contains("### Enemy Abilities"))
        #expect(markdown.contains("### Enemy Traits"))
        #expect(markdown.contains("SHORT%"))
        #expect(markdown.contains("Avg rounds"))
        #expect(report.records.allSatisfy { !$0.enemyAbilityIDs.isEmpty })
        #expect(report.records.allSatisfy { !$0.enemyTraitID.isEmpty })
    }
}
