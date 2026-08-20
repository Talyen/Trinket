import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

struct BattleSimulatorTests {
    @Test func greedyPolicyReachesOutcomeDeterministically() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first)

        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: .early,
            heroLoadout: hero.abilityLoadout,
            companionLoadout: companion.abilityLoadout,
            seed: 42
        )

        let first = BattleSimulator.run(matchup: matchup, policy: GreedyHeuristicPolicy())
        let second = BattleSimulator.run(matchup: matchup, policy: GreedyHeuristicPolicy())

        #expect(first == second)
        #expect(first.timedOut == false || first.actions > 0)
    }

    @Test func tracksEventsFalseKeepsEventLogEmpty() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        var battle = BattleState(
            hero: hero,
            companion: companion,
            enemy: enemy.combatant,
            rngSeed: 7,
            tracksLog: false,
            tracksEvents: false
        )
        #expect(battle.events.isEmpty)

        if let card = battle.hand.cards.first(where: { battle.isCardPlayable($0) }) {
            _ = try battle.playCard(cardID: card.id, rebuildLog: false)
        } else {
            _ = battle.endTurn(rebuildLog: false)
        }

        #expect(battle.events.isEmpty)
    }

    @Test func midTierGearUsesBuildAlignedAffixesOnly() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first)
        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: .middle,
            heroLoadout: hero.abilityLoadout,
            companionLoadout: companion.abilityLoadout,
            seed: 99
        )

        let buildKeywords = Set(matchup.context.heroLoadout.abilities.flatMap(\.keywords))
        let definitions = Dictionary(
            uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) }
        )
        for affixID in matchup.context.heroAffixIDs {
            let definition = try #require(definitions[affixID])
            #expect(definition.isAligned(withBuildKeywords: buildKeywords))
        }
        #expect(!(matchup.context.heroAffixIDs.isEmpty))
    }

    @Test func sampleLoadoutIncludesAllTiersByDefault() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        var rng = SeededRandomNumberGenerator(seed: 5)
        let loadout = SimulationMatchupBuilder.sampleLoadout(for: hero, using: &rng)
        #expect(loadout.ultimate != nil)
        #expect(loadout.basic != nil)
        #expect(loadout.skill != nil)
    }

    @Test func samplePartyLoadoutsMeetDamagingFloor() throws {
        for hero in GameContent.heroes {
            for companion in GameContent.companions {
                var rng = SeededRandomNumberGenerator(seed: 11)
                let pair = SimulationMatchupBuilder.samplePartyLoadouts(
                    hero: hero,
                    companion: companion,
                    using: &rng
                )
                let count = SimulationMatchupBuilder.damagingAbilityCount(
                    hero: pair.hero,
                    companion: pair.companion
                )
                try #expect(
                    count >= SimulationMatchupBuilder.minimumPartyDamagingAbilities,
                    "\(hero.id)+\(companion.id) damaging count \(count)"
                )
            }
        }

        let supportHeavy = SimulationMatchupBuilder.damagingAbilityCount(
            hero: AbilityLoadout(basic: .block, skill: .smite, ultimate: .moltenBulwark),
            companion: AbilityLoadout(basic: .apple, skill: .heal, ultimate: .panaceaPotion)
        )
        try #expect(supportHeavy < SimulationMatchupBuilder.minimumPartyDamagingAbilities)
    }

    @Test func matchupBuilderAppliesUnlockedTalentsToCombatBuild() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first)
        let withTalent = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: .early,
            heroLoadout: hero.abilityLoadout,
            companionLoadout: companion.abilityLoadout,
            seed: 7,
            heroTalents: ["knight_block_t1_1"]
        )
        let withoutTalent = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: .early,
            heroLoadout: hero.abilityLoadout,
            companionLoadout: companion.abilityLoadout,
            seed: 7
        )
        #expect(withTalent.heroModifiers.triggers.blockPerTurn == 2)
        #expect(withoutTalent.heroModifiers.triggers.blockPerTurn == 0)
        #expect(withTalent.context.heroTalentIDs == ["knight_block_t1_1"])
        #expect(withoutTalent.context.heroTalentIDs.isEmpty)
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
        #expect(lateRecord.heroTalentIDs.count == 18)
        #expect(lateRecord.companionTalentIDs.count == 18)
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

    @Test func talentKitContrastIsLegalOnlyWhenPointsCoverCatalog() throws {
        let owner = try #require(GameContent.heroes.first { $0.id == "knight" })
        let focus = BalanceTalentContrastRunner.KitFocus(
            owner: owner,
            kit: CombatantTalentCatalog.validNodeIDs(for: owner.id)
        )
        #expect(!BalanceTalentContrastRunner.isKitLegal(focus: focus, tier: .early))
        #expect(!BalanceTalentContrastRunner.isKitLegal(focus: focus, tier: .middle))
        #expect(BalanceTalentContrastRunner.isKitLegal(focus: focus, tier: .lateGame))
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
