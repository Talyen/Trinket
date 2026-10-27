import BattleEngine
import Testing
@testable import BattleBalanceTools

struct BalanceFindingsReporterTests {
    @Test func `unfinished progression cannot report a clean bill of health`() throws {
        let step = try #require(ModeProgressionTracker.campaign().steps.first)
        let sample = ProgressionBattleRecord(
            step: step, playerLevel: 1, enemyLevel: step.enemyLevel, seed: 1,
            result: BalanceTestFixtures.result(
                outcome: .defeat,
                rounds: 1,
                actions: 1,
                timedOut: true,
                partyHPRemainingFraction: 1,
                enemyHPRemainingFraction: 1,
            ),
        )
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(mode: .modeProgression), policyID: "greedy-v1",
            progressionHotspots: HotspotAnalyzer.analyze(records: [sample]), progressionRecords: [sample],
            progressionPlayerStates: [PlayerProgressionState()], progressionTruncatedRuns: 1, elapsedSeconds: 0,
        )
        let findings = BalanceFindingsReporter.render(report)
        #expect(findings.contains("STALL"))
        #expect(findings.contains("INCOMPLETE"))
        #expect(!findings.contains("No flags"))
    }

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
        let snapshots = BalanceTierSnapshots(report: report)
        let findings = BalanceFindingsReporter.render(report, snapshots: snapshots)
        let full = BalanceMarkdownReporter.render(report, snapshots: snapshots)
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
        #expect(BalanceMarkdownReporter.render(report).contains(
            "| `cinderbloom` | `fireball` | sibling | `phoenix` | Early | 81.2% | 62.5% | +18.8 pp | +0.00 | +0.0 | 32 | 32 | ⚠ HIGH |",
        ))

        var large = contrast
        large.pairs = Int.max
        large.decidedPairs = Int.max - 1
        let lines = BalanceMarkdownTables.contrasts(title: "Contrasts", summaries: [large])
        #expect(lines.contains(
            "| `cinderbloom` | `fireball` | sibling | `phoenix` | Early | 0.0% | 0.0% | +18.8 pp | +0.00 | +0.0 | \(Int.max) | \(Int.max - 1) | ⚠ HIGH |",
        ))
        var largeReport = report
        largeReport.abilityContrasts = [large]
        let largeFindings = BalanceFindingsReporter.render(largeReport)
        #expect(largeFindings.contains("n=\(Int.max - 1) decided"))
        #expect(largeFindings.contains("timeouts 0/\(Int.max) entity, 0/\(Int.max) baseline"))
    }

    @Test func `findings list progression hotspots without node census`() {
        let step = BalanceTestFixtures.step(
            id: "stage-3-10",
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
            flagReason: "Win rate 50.0% below 70%",
        )
        let smoothStep = BalanceTestFixtures.step(id: "stage-1-1", containerTitle: "Chapter 1: Forest", enemyID: "slime", enemyLevel: 1)
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

    @Test func `unfinished fights are stalls rather than short fights`() {
        var record = identityRecord(enemyID: "stall", isBoss: false, abilities: [], win: false, seed: 1)
        record.result.timedOut = true
        record.result.rounds = 1
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(tiers: [.early]), policyID: "greedy-v1",
            records: Array(repeating: record, count: 8), elapsedSeconds: 0,
        )
        let stats = BalanceStatsAggregator.summarize(report: report)[0]
        #expect(stats.trashDuration.shortBattles == 0)
        #expect(stats.enemyDurations.first?.shortRate == 0)
        #expect(stats.heroDurations.first?.shortRate == 0)
        #expect(stats.companionDurations.first?.shortRate == 0)
        #expect(BalanceFindingsReporter.render(report).contains("STALL"))
        var short = identityRecord(enemyID: "short", isBoss: false, abilities: [], win: true, seed: 2)
        short.result.rounds = 1
        let sparse = BalanceDurationAggregation.summarize([short], flagRate: 0.15).trash
        #expect(sparse.shortBattles == 1 && !sparse.flagged)
        #expect(sparse.worstEnemyID == nil)
    }

    @Test func `duration tables preserve encounter roles and capped fight boundaries`() throws {
        var records: [BalanceBattleRecord] = []
        for isBoss in [false, true] {
            for index in 0 ..< 8 {
                var record = identityRecord(enemyID: "shared", isBoss: isBoss, abilities: [], win: true, seed: UInt64(index))
                record.result.rounds = index < 4 ? (isBoss ? 12 : 10) : (isBoss ? 1 : 11)
                record.result.timedOut = index >= 4
                records.append(record)
            }
        }
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(tiers: [.early]), policyID: "greedy-v1",
            records: records, elapsedSeconds: 0,
        )
        let stats = BalanceStatsAggregator.summarize(report: report)[0]
        #expect(stats.decidedBattles == 8)
        #expect(stats.timeouts == 8)
        #expect(stats.enemyDurations.count == 2)
        let trash = try #require(stats.enemyDurations.first { !$0.isBoss })
        let boss = try #require(stats.enemyDurations.first { $0.isBoss })
        #expect(trash.battles == 8 && trash.averageRounds == 10.5)
        #expect(trash.shortRate == 0 && trash.longRate == 0.5 && trash.flagReason == "SLOW")
        #expect(boss.battles == 8 && boss.averageRounds == 6.5)
        #expect(boss.shortRate == 0.5 && boss.longRate == 0 && boss.flagReason == "FAST")
        #expect(stats.trashDuration.longBattles == 4 && stats.trashDuration.averageRoundsWhenLong == 11)
        #expect(stats.trashDuration.worstEnemyID == "shared" && stats.bossDuration.worstEnemyID == nil)
        #expect(stats.bossDuration.shortBattles == 4 && stats.bossDuration.averageRoundsWhenShort == 12)
        #expect(stats.trashDuration.flagReason == "LONG" && stats.bossDuration.flagReason == "SHORT")
        let hero = try #require(stats.heroDurations.first)
        let companion = try #require(stats.companionDurations.first)
        #expect(hero.battles == 16 && hero.averageRounds == 8.5)
        #expect(hero.shortRate == 0.25 && hero.longRate == 0.25 && hero.flagReason == "FAST SLOW")
        #expect(companion.battles == hero.battles && companion.averageRounds == hero.averageRounds)
        #expect(companion.shortRate == hero.shortRate && companion.longRate == hero.longRate)
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("| `shared` | regular | 8 |"))
        #expect(markdown.contains("| `shared` | boss | 8 |"))
        let findings = BalanceFindingsReporter.render(report)
        #expect(findings.contains("Enemy `shared` (Early duration)"))
        #expect(findings.contains("Boss `shared` (Early duration)"))
    }

    @Test func `equal duration outliers select the same enemy regardless of record order`() {
        let records = ["alpha", "zeta"].flatMap { id in
            Array(repeating: identityRecord(enemyID: id, isBoss: false, abilities: [], win: false, seed: 1), count: 8)
        }
        for source in [records, Array(records.reversed())] {
            let stats = BalanceDurationAggregation.summarize(source, flagRate: 0.15).trash
            #expect(stats.worstEnemyID == "alpha")
        }
    }

    @Test func `cross-tier warnings count tiers rather than boss and regular rows`() {
        let early = [false, true].flatMap { isBoss in
            Array(repeating: identityRecord(enemyID: "shared", isBoss: isBoss, abilities: [], win: false, seed: 1), count: 8)
        }
        var middle = identityRecord(enemyID: "sparse", isBoss: false, abilities: [], win: true, seed: 2)
        middle.tier = .middle
        var report = BalanceSweepReport(
            config: BalanceSweepConfig(tiers: [.early, .middle]), policyID: "greedy-v1",
            records: early + [middle], elapsedSeconds: 0,
        )
        #expect(!BalanceFindingsReporter.render(report).contains("Cross-Tier Outlier"))
        report.records += early.map { record in
            var record = record
            record.tier = .middle
            return record
        }
        let warnings = BalanceFindingsReporter.render(report).split(separator: "\n").filter { $0.contains("Cross-Tier Outlier") }
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("flagged in 2 tiers (Early, Middle)") == true)
    }

    @Test func `affix findings identify the owner whose build benefits or suffers`() {
        var win = identityRecord(enemyID: "enemy", isBoss: false, abilities: [], win: true, seed: 1)
        win.heroAffixIDs = ["keen"]
        var loss = identityRecord(enemyID: "enemy", isBoss: false, abilities: [], win: false, seed: 2)
        loss.companionAffixIDs = ["keen"]
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(tiers: [.early]), policyID: "greedy-v1",
            records: Array(repeating: win, count: 8) + Array(repeating: loss, count: 8), elapsedSeconds: 0,
        )
        let findings = BalanceFindingsReporter.render(report)
        #expect(findings.contains("Affix `keen` (Early, on `knight`): ⚠ HIGH"))
        #expect(findings.contains("Affix `keen` (Early, on `bear`): ⚠ LOW"))
    }

    @Test func `repeated affix counts once per owner per battle`() {
        var record = identityRecord(enemyID: "enemy", isBoss: false, abilities: [], win: true, seed: 1)
        record.heroAffixIDs = ["keen", "keen", "keen"]
        record.companionAffixIDs = ["keen", "keen"]
        record.heroItemBaseIDs = ["blade"]
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(tiers: [.early]), policyID: "greedy-v1",
            records: Array(repeating: record, count: 3), elapsedSeconds: 0,
        )
        let rows = BalanceStatsAggregator.summarize(report: report)[0].affixes
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.battles == 3 && $0.wins == 3 && $0.sampleTooLow })
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("Item Bases (within owner)"))
        #expect(markdown.contains("Item Affixes (within owner)"))
        #expect(markdown.contains("`blade`"))
    }

    @Test func `encounter tables compare only matching boss or trash samples`() {
        let records = Array(repeating: identityRecord(
            enemyID: "shared", isBoss: false, abilities: [], win: true, seed: 1,
        ), count: 8) + Array(repeating: identityRecord(
            enemyID: "shared", isBoss: true, abilities: [], win: false, seed: 2,
        ), count: 8)
        let rows = BalanceIdentityMargins.enemyMargins(records: records) { isBoss in
            isBoss ? (0.7, 0.8) : (0.4, 0.5)
        }
        #expect(rows.count == 2)
        #expect(rows.map(\.battles) == [8, 8])
        #expect(rows.map(\.flagReason) == ["EASY", "HARD"])
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(tiers: [.early]), policyID: "greedy-v1",
            records: records, elapsedSeconds: 0,
        )
        let stats = BalanceStatsAggregator.summarize(report: report)[0]
        for owners in [stats.heroesTrash, stats.heroesBoss, stats.companionsTrash, stats.companionsBoss] {
            #expect(owners.count == 1)
            #expect(owners.allSatisfy { $0.deltaVsPeer == 0 && !$0.flagged })
        }
    }
}

extension BalanceFindingsReporterTests {
    @Test func `pairing anomalies surface even when individual owners have equal win rates`() {
        var records: [BalanceBattleRecord] = []
        for hero in 0 ..< 2 {
            for companion in 0 ..< 2 {
                for sample in 0 ..< 32 {
                    var record = identityRecord(
                        enemyID: "enemy", isBoss: false, abilities: [],
                        win: hero == companion, seed: UInt64(sample),
                    )
                    record.heroID = "hero-\(hero)"
                    record.companionID = "companion-\(companion)"
                    records.append(record)
                }
            }
        }
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(tiers: [.early]), policyID: "greedy-v1",
            records: records, elapsedSeconds: 0,
        )
        let stats = BalanceStatsAggregator.summarize(report: report)[0]
        #expect(stats.heroes.allSatisfy { !$0.flagged })
        #expect(stats.companions.allSatisfy { !$0.flagged })
        #expect(!stats.heroCompanionCells.isEmpty)
        let findings = BalanceFindingsReporter.render(report)
        let pairings = findings.split(separator: "\n").filter { $0.contains("pairing outlier") }
        #expect(pairings.count == BalanceFindingsReporter.pairingCap)
        #expect(pairings.first?.contains("hero `hero-0` × companion `companion-0`") == true)
        #expect(!pairings.contains { $0.contains("hero `hero-1` × companion `companion-1`") })
    }

    @Test func `matchup identities remain distinct when IDs contain separators`() {
        var records: [BalanceBattleRecord] = []
        for sample in 0 ..< 8 {
            var win = identityRecord(enemyID: "enemy", isBoss: false, abilities: [], win: true, seed: UInt64(sample))
            win.heroID = "hero|one"
            win.companionID = "partner"
            records.append(win)

            var loss = identityRecord(enemyID: "enemy", isBoss: false, abilities: [], win: false, seed: UInt64(sample + 8))
            loss.heroID = "hero"
            loss.companionID = "one|partner"
            records.append(loss)
        }

        let cells = BalanceIdentityMargins.flaggedPairCells(
            records: records,
            left: \.heroID,
            right: \.companionID,
            peerRate: 0.5,
            threshold: 0.1,
        )
        #expect(cells.map(\.leftID) == ["hero", "hero|one"])
        #expect(cells.map(\.rightID) == ["one|partner", "partner"])
        #expect(cells.map(\.battles) == [8, 8])
        #expect(cells.map(\.flagReason) == ["LOW", "HIGH"])
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
            enemyTraitIDs: ["\(enemyID)_trait"],
            affixIDs: [],
            heroTalentIDs: [],
            companionTalentIDs: [],
            seed: seed,
            policyID: "greedy-v1",
            result: BalanceTestFixtures.result(
                outcome: win ? .victory : .defeat,
                rounds: win ? 6 : 18,
                actions: 12,
                partyHPRemainingFraction: win ? 0.8 : 0,
                enemyHPRemainingFraction: win ? 0 : 0.7,
            ),
        )
    }
}

extension BalanceFindingsReporterTests {
    @Test(arguments: SimulationPowerTier.allCases)
    func `encounter targets are consistent across tiers`(_ tier: SimulationPowerTier) throws {
        let records = [false, true].flatMap { isBoss in
            (0 ..< 1000).map { index in
                var record = identityRecord(
                    enemyID: isBoss ? "boss" : "normal",
                    isBoss: isBoss,
                    abilities: [],
                    win: index < 800,
                    seed: UInt64(index),
                )
                record.tier = tier
                return record
            }
        }
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(tiers: [tier]),
            policyID: "greedy-v1",
            records: records,
            elapsedSeconds: 0,
        )
        let stats = try #require(BalanceStatsAggregator.summarize(report: report).first)
        #expect(stats.enemies.first { $0.id == "normal" }?.flagReason == "HARD")
        #expect(stats.enemies.first { $0.id == "boss" }?.flagged == false)
        #expect(abs((stats.heroesTrash.first?.targetBandDelta ?? 0) + 0.14) < 1e-12)
        #expect(stats.heroesBoss.first?.targetBandDelta == 0)
        for text in [BalanceFindingsReporter.render(report), BalanceMarkdownReporter.render(report)] {
            #expect(text.contains("regular enemies `90-98%`, bosses `70-90%` (all tiers)"))
            #expect(text.contains("15 pp"))
            #expect(text.contains("2.0%"))
        }
    }

    @Test(arguments: [false, true])
    func `enemy extremes flag after the minimum decided sample`(_ win: Bool) throws {
        let record = identityRecord(enemyID: "enemy", isBoss: false, abilities: [], win: win, seed: 1)
        for count in [7, 8] {
            let rows = BalanceIdentityMargins.enemyMargins(
                records: Array(repeating: record, count: count),
                targetBand: BalanceEncounterTargets.winBand,
            )
            let row = try #require(rows.first)
            #expect(row.flagged == (count == 8))
            #expect(row.flagReason == (count == 8 ? (win ? "EASY" : "HARD") : nil))
        }
    }

    @Test func `owner median is not dominated by unequal sample counts`() throws {
        let records = [("a", 10, 20), ("b", 12, 20), ("c", 360, 400)].flatMap { id, wins, count in
            (0 ..< count).map { index in
                var record = identityRecord(
                    enemyID: "enemy",
                    isBoss: false,
                    abilities: [],
                    win: index < wins,
                    seed: UInt64(index),
                )
                record.heroID = id
                return record
            }
        }
        let rows = BalanceIdentityMargins.ownerMargins(records: records, id: \.heroID, threshold: 0.15)
        let high = try #require(rows.first { $0.id == "c" })
        #expect(abs(high.deltaVsPeer - 0.3) < 1e-12)
        #expect(high.flagReason == "HIGH")
        #expect(rows.first { $0.id == "b" }?.deltaVsPeer == 0)
    }

    @Test(arguments: [(50, "STALL"), (51, "UNFINISHED")])
    func `material stalls retain below threshold diagnostics`(count: Int, label: String) {
        let records = (0 ..< count).map { index in
            var record = identityRecord(
                enemyID: "enemy",
                isBoss: false,
                abilities: [],
                win: true,
                seed: UInt64(index),
            )
            record.result.timedOut = index == 0
            return record
        }
        let progression = records.map { record in
            ProgressionBattleRecord(
                step: BalanceTestFixtures.step(),
                playerLevel: 1,
                enemyLevel: 1,
                seed: record.seed,
                result: record.result,
            )
        }
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(tiers: [.early]),
            policyID: "greedy-v1",
            records: records,
            progressionRecords: progression,
            elapsedSeconds: 0,
        )
        let findings = BalanceFindingsReporter.render(report)
        #expect(findings.contains("Enemy `enemy` (Early): ⚠ \(label) · 1/\(count)"))
        #expect(findings.contains("Progression: ⚠ \(label) · 1/\(count)"))
    }
}
