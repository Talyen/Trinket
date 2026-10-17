import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

@Suite(.serialized)
struct BattleSimulatorSweepReportTests {
    @Test func `parallel identity matches sequential outcomes`() {
        var config = BalanceSweepConfig(
            mode: .identity, battlesPerTier: 6, seed: 11, tiers: [.early],
            jobs: 1, enemyIDs: ["living_armor"],
        )
        let sequential = BalanceSweepRunner.run(config: config)
        config.jobs = 4
        let parallel = BalanceSweepRunner.run(config: config)
        #expect(sequential.records == parallel.records)
    }

    @Test func `ability contrast produces lift rows`() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .abilityContrast,
                battlesPerTier: 2,
                seed: 21,
                tiers: [.early],
                maxRounds: 1,
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

    @Test func `affix contrast produces lift rows in every tier`() {
        for tier in SimulationPowerTier.allCases {
            let report = BalanceSweepRunner.run(
                config: BalanceSweepConfig(
                    mode: .affixContrast,
                    battlesPerTier: 4,
                    seed: 22,
                    tiers: [tier],
                    maxRounds: 1,
                    jobs: 1,
                    heroIDs: ["knight"],
                    companionIDs: ["bear"],
                    enemyIDs: ["living_armor"],
                    focusIDs: ["keen"],
                ),
            )
            let markdown = BalanceMarkdownReporter.render(report)
            #expect(!report.affixContrasts.isEmpty)
            #expect(report.affixContrasts.contains { $0.baselineKind == .emptySlot })
            #expect(report.affixContrasts.contains { $0.baselineKind == .replacementAffix })
            #expect(report.affixContrasts.allSatisfy { $0.tier == tier && $0.pairs == 4 })
            #expect(markdown.contains("Affix Contrasts"))
        }
    }

    @Test(arguments: SimulationPowerTier.allCases)
    func `affix pair preserves every other affix and rolled power`(tier: SimulationPowerTier) throws {
        let foci = BalanceAffixContrastRunner.foci(
            heroes: GameContent.heroes, companions: GameContent.companions, focusIDs: ["keen"],
        )
        #expect(!foci.isEmpty)
        for focus in foci {
            var rng = SeededRandomNumberGenerator(seed: 1772)
            let pair = BalanceAffixContrastRunner.makeAffixGearPair(
                focus: focus, tier: tier,
                ownerLoadout: SimulationMatchupBuilder.sampleLoadout(for: focus.owner, using: &rng),
                pairSeed: 1772,
            )
            let entity = try #require(pair.withAffix.inventory.first)
            let baseline = try #require(pair.baseline.inventory.first)
            #expect(entity.affixes.contains { $0.id == focus.definition.id })
            #expect(!baseline.affixes.contains { $0.id == focus.definition.id })
            let retained = entity.affixes.indices.filter { entity.affixes[$0].id != focus.definition.id }
            for index in retained {
                let match = baseline.affixes.firstIndex { $0.id == entity.affixes[index].id }
                let baselineIndex = try #require(match)
                #expect(entity.affixPowers?[index] == baseline.affixPowers?[baselineIndex])
            }
            let difference = focus.baselineKind == .emptySlot ? 1 : 0
            #expect(entity.affixes.count - baseline.affixes.count == difference)
            #expect(pair.withAffix.inventory.dropFirst() == pair.baseline.inventory.dropFirst())
            if tier == .early {
                #expect(pair.withAffix.inventory.count == 1)
                #expect(pair.baseline.inventory.count == 1)
            }
        }
    }

    @Test func `identity quotas equal battles per enemy`() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 3,
                seed: 9,
                tiers: [.early],
                maxRounds: 1,
                jobs: 1,
                enemyIDs: ["living_armor", "mimic"],
            ),
        )
        #expect(report.records.count == 6)
        let byEnemy = Dictionary(grouping: report.records, by: \.enemyID)
        #expect(byEnemy["living_armor"]?.count == 3)
        #expect(byEnemy["mimic"]?.count == 3)
        #expect(report.records.allSatisfy { !$0.enemyAbilityIDs.isEmpty && !$0.enemyTraitIDs.isEmpty })
    }

    @Test(arguments: SimulationPowerTier.allCases)
    func `identity builds spend their tier budget legally`(tier: SimulationPowerTier) throws {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity, battlesPerTier: 1, seed: 4, tiers: [tier],
                maxRounds: 1, jobs: 1, enemyIDs: ["living_armor"],
            ),
        )
        #expect(report.records.count == 1)
        let record = try #require(report.records.first)
        let budget = tier == .early ? 1 : CombatantProgression.at(level: tier.level).totalTalentPoints
        for (ownerID, talents) in [(record.heroID, record.heroTalentIDs), (record.companionID, record.companionTalentIDs)] {
            #expect(talents.count == min(budget, CombatantTalentCatalog.validNodeIDs(for: ownerID).count))
            expectLegalTalentSpend(Set(talents), combatantID: ownerID)
        }
        if tier == .early {
            #expect(record.heroAffixIDs.count == 1)
            #expect(record.companionAffixIDs.count == 1)
        }
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

    @Test func `talent contrast produces sibling lift rows`() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .talentContrast,
                battlesPerTier: 1,
                seed: 23,
                tiers: [.middle],
                maxRounds: 1,
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
                maxRounds: 1,
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
}
