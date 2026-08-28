import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

@Suite(.serialized)
struct BattleSimulatorSweepReportTests {
    @Test func parallelIdentityMatchesSequentialOutcomes() {
        let sequential = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 6,
                seed: 11,
                tiers: [.early],
                jobs: 1,
                enemyIDs: ["living_armor"]
            )
        )
        let parallel = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 6,
                seed: 11,
                tiers: [.early],
                jobs: 4,
                enemyIDs: ["living_armor"]
            )
        )
        #expect(sequential.records.map(\.result) == parallel.records.map(\.result))
        #expect(sequential.records.map(\.seed) == parallel.records.map(\.seed))
    }

    @Test func abilityContrastProducesLiftRows() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .abilityContrast,
                battlesPerTier: 2,
                seed: 21,
                tiers: [.early],
                jobs: 1,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                enemyIDs: ["living_armor"]
            )
        )
        #expect(report.records.isEmpty)
        #expect(!(report.abilityContrasts.isEmpty))
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("Ability Contrasts"))
    }

    @Test func affixContrastProducesLiftRowsOnMidTier() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .affixContrast,
                battlesPerTier: 2,
                seed: 22,
                tiers: [.middle],
                jobs: 1,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                enemyIDs: ["living_armor"],
                focusIDs: ["keen"]
            )
        )
        #expect(!(report.affixContrasts.isEmpty))
        #expect(report.affixContrasts.contains { $0.baselineKind == .emptySlot })
        #expect(report.affixContrasts.contains { $0.baselineKind == .replacementAffix })
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("Affix Contrasts"))
    }

    @Test func identityQuotasEqualBattlesPerEnemy() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 3,
                seed: 9,
                tiers: [.early],
                jobs: 1,
                enemyIDs: ["living_armor", "mimic"]
            )
        )
        #expect(report.records.count == 6)
        let byEnemy = Dictionary(grouping: report.records, by: \.enemyID)
        #expect(byEnemy["living_armor"]?.count == 3)
        #expect(byEnemy["mimic"]?.count == 3)
    }

    @Test func identityWorkSlicesConcatenateToFullSweep() {
        let config = BalanceSweepConfig(
            mode: .identity,
            battlesPerTier: 8,
            seed: 11,
            tiers: [.early],
            jobs: 1,
            enemyIDs: ["living_armor"]
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
                enemyIDs: ["living_armor"]
            )
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
                enemyIDs: ["living_armor"]
            )
        )
        let merged = BalanceSweepReport.merged(
            [first, second],
            config: config,
            policyID: full.policyID,
            elapsedSeconds: 0
        )
        #expect(first.records.count == 4)
        #expect(second.records.count == 4)
        #expect(merged.records.map(\.result) == full.records.map(\.result))
        #expect(merged.records.map(\.seed) == full.records.map(\.seed))
    }

    @Test func identityEarlySpendsOneTalentAndOneStarterItem() {
        let early = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 2,
                seed: 4,
                tiers: [.early],
                jobs: 1,
                enemyIDs: ["living_armor"]
            )
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
                enemyIDs: ["living_armor"]
            )
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
                enemyIDs: ["living_armor"]
            )
        )
        #expect(late.records.count == 1)
        let lateRecord = late.records[0]
        let lateBudget = CombatantTalentCatalog.validNodeIDs(for: lateRecord.heroID).count
        #expect(lateRecord.heroTalentIDs.count == lateBudget)
        #expect(lateRecord.companionTalentIDs.count == CombatantTalentCatalog.validNodeIDs(for: lateRecord.companionID).count)
        #expect(Set(lateRecord.heroTalentIDs) == CombatantTalentCatalog.validNodeIDs(for: lateRecord.heroID))
        #expect(Set(lateRecord.companionTalentIDs) == CombatantTalentCatalog.validNodeIDs(for: lateRecord.companionID))
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

    @Test func talentContrastProducesSiblingAndKitLiftRows() {
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
                focusIDs: ["knight_block_t1_1"]
            )
        )
        #expect(report.records.isEmpty)
        #expect(!(report.talentContrasts.isEmpty))
        #expect(report.talentKitContrasts.isEmpty)
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("Talent Contrasts (paired lift vs sibling in the same row)"))
    }

    @Test func talentContrastRunsRowOneAtEarlyAndSkipsFullKit() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .talentContrast,
                battlesPerTier: 2,
                seed: 23,
                tiers: [.early],
                jobs: 1,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                enemyIDs: ["living_armor"]
            )
        )
        #expect(!(report.talentContrasts.isEmpty))
        #expect(report.talentContrasts.allSatisfy { $0.tier == .early })
        #expect(report.talentKitContrasts.isEmpty)
    }

    @Test func identitySweepProducesMarkdownWithSecondaryMetrics() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 4,
                seed: 3,
                tiers: [.early],
                jobs: 1,
                enemyIDs: ["living_armor"]
            )
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
