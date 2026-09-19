import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

public enum BalanceSweepRunner {
    public static func run(
        config: BalanceSweepConfig,
        policy: PlayPolicy? = nil,
        heroes: [Combatant]? = nil,
        companions: [Combatant]? = nil,
        enemies: [Enemy]? = nil,
    ) -> BalanceSweepReport {
        let roster = config.resolvedRoster
        let resolvedHeroes = heroes ?? roster.heroes
        let resolvedCompanions = companions ?? roster.companions
        let resolvedEnemies = enemies ?? roster.enemies
        precondition(!resolvedHeroes.isEmpty && !resolvedCompanions.isEmpty && !resolvedEnemies.isEmpty)

        let resolvedPolicy = policy ?? config.policy
        let started = ContinuousClock.now
        let records = config.mode == .identity || config.mode == .all
            ? runIdentitySweep(
                config: config,
                policy: resolvedPolicy,
                heroes: resolvedHeroes,
                companions: resolvedCompanions,
                enemies: resolvedEnemies,
            )
            : []
        let comparedRecords: [BalanceBattleRecord]
        let comparedPolicyID: String?
        if config.comparePolicies, config.mode == .identity || config.mode == .all {
            let other = config.comparePolicy
            comparedPolicyID = other.id
            comparedRecords = runIdentitySweep(
                config: config,
                policy: other,
                heroes: resolvedHeroes,
                companions: resolvedCompanions,
                enemies: resolvedEnemies,
            )
        } else {
            comparedPolicyID = nil
            comparedRecords = []
        }
        let contrasts = runContrastsIfNeeded(
            config: config,
            policy: resolvedPolicy,
            heroes: resolvedHeroes,
            companions: resolvedCompanions,
            enemies: resolvedEnemies,
        )
        let progression = runProgressionIfNeeded(config: config, policy: resolvedPolicy)

        let elapsed = ContinuousClock.now - started
        return BalanceSweepReport(
            config: config,
            policyID: resolvedPolicy.id,
            records: records,
            comparedPolicyID: comparedPolicyID,
            comparedRecords: comparedRecords,
            abilityContrasts: contrasts.ability,
            affixContrasts: contrasts.affix,
            talentContrasts: contrasts.talent,
            talentKitContrasts: contrasts.talentKit,
            progressionHotspots: progression.hotspots,
            progressionRecords: progression.records,
            progressionPlayerStates: progression.playerStates,
            progressionTruncatedRuns: progression.truncatedRuns,
            elapsedSeconds: Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1e18,
        )
    }

    private static func runContrastsIfNeeded(
        config: BalanceSweepConfig,
        policy: PlayPolicy,
        heroes: [Combatant],
        companions: [Combatant],
        enemies: [Enemy],
    ) -> (
        ability: [PairedContrastSummary],
        affix: [PairedContrastSummary],
        talent: [PairedContrastSummary],
        talentKit: [PairedContrastSummary],
    ) {
        let runAbility = config.mode == .abilityContrast || config.mode == .all
        let runAffix = config.mode == .affixContrast || config.mode == .all
        let runTalent = config.mode == .talentContrast || config.mode == .all
        guard runAbility || runAffix || runTalent else { return ([], [], [], []) }

        let contrastContext = BalanceContrastContext(
            config: config,
            heroes: heroes,
            companions: companions,
            enemies: enemies,
        )
        let ability = runAbility
            ? BalanceAbilityContrastRunner.run(context: contrastContext, policy: policy)
            : []
        let affix = runAffix
            ? BalanceAffixContrastRunner.run(context: contrastContext, policy: policy)
            : []
        let talent = runTalent
            ? BalanceTalentContrastRunner.run(context: contrastContext, policy: policy)
            : (sibling: [], kit: [])
        return (ability, affix, talent.sibling, talent.kit)
    }

    private static func runProgressionIfNeeded(
        config: BalanceSweepConfig,
        policy: PlayPolicy,
    ) -> (
        records: [ProgressionBattleRecord],
        hotspots: [NodeHotspotSummary],
        playerStates: [PlayerProgressionState],
        truncatedRuns: Int,
    ) {
        guard config.mode == .modeProgression || config.mode == .all else {
            return ([], [], [], 0)
        }
        return BalanceProgressionRunner.run(config: config, policy: policy)
    }

    private static func runIdentitySweep(
        config: BalanceSweepConfig,
        policy: PlayPolicy,
        heroes: [Combatant],
        companions: [Combatant],
        enemies: [Enemy],
    ) -> [BalanceBattleRecord] {
        let roster = BalanceSweepRoster(heroes: heroes, companions: companions, enemies: enemies)
        let work: [(SimulationPowerTier, Int, Int)] = config.sliceWork(
            config.tiers.flatMap { tier in
                enemies.indices.flatMap { enemyIndex in
                    (0 ..< config.battlesPerTier).map { sample in
                        (tier, enemyIndex, sample)
                    }
                }
            },
        )
        let jobs = config.resolvedJobs
        return SweepWorkerPool.map(count: work.count, jobs: jobs) { index -> BalanceBattleRecord? in
            let entry = work[index]
            return simulateIdentityBattle(
                config: config,
                policy: policy,
                roster: roster,
                tier: entry.0,
                enemyIndex: entry.1,
                sampleIndex: entry.2,
            )
        }
    }

    private static func simulateIdentityBattle(
        config: BalanceSweepConfig,
        policy: PlayPolicy,
        roster: BalanceSweepRoster,
        tier: SimulationPowerTier,
        enemyIndex: Int,
        sampleIndex: Int,
    ) -> BalanceBattleRecord {
        let enemy = roster.enemies[enemyIndex]
        let battleSeed = config.seed
            &+ UInt64(tier.level) &* 1000003
            &+ BalanceContrastSupport.stableHash64(enemy.id) &* 10007
            &+ UInt64(sampleIndex) &* 97
        var rng = SeededRandomNumberGenerator(seed: battleSeed)

        let hero = roster.heroes[sampleIndex % roster.heroes.count]
        let companion = roster.companions[
            (sampleIndex % roster.heroes.count + sampleIndex / roster.heroes.count) % roster.companions.count,
        ]
        let partyLoadouts = SimulationMatchupBuilder.samplePartyLoadouts(
            hero: hero,
            companion: companion,
            using: &rng,
        )
        let starter = identityStarterLoadout(
            hero: hero,
            companion: companion,
            heroLoadout: partyLoadouts.hero,
            companionLoadout: partyLoadouts.companion,
            tier: tier,
            rng: &rng,
        )
        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: tier,
            heroLoadout: partyLoadouts.hero,
            companionLoadout: partyLoadouts.companion,
            seed: battleSeed,
            loadoutSampleIndex: sampleIndex,
            heroGear: starter.heroGear,
            companionGear: starter.companionGear,
            heroTalents: starter.heroTalents,
            companionTalents: starter.companionTalents,
        )
        let result = BattleSimulator.run(
            matchup: matchup,
            policy: policy,
            maxRounds: config.maxRounds,
            maxActions: config.maxActions,
            appliesFightPacing: config.appliesFightPacing,
        )
        return makeIdentityRecord(
            IdentityRecordParts(
                tier: tier,
                hero: hero,
                companion: companion,
                enemy: enemy,
                matchup: matchup,
                battleSeed: battleSeed,
                policyID: policy.id,
                result: result,
            ),
        )
    }

    private struct IdentityStarter {
        var heroGear: SimulationMatchupBuilder.GearOverride?
        var companionGear: SimulationMatchupBuilder.GearOverride?
        var heroTalents: Set<String>
        var companionTalents: Set<String>
    }

    private static func identityStarterLoadout(
        hero: Combatant,
        companion: Combatant,
        heroLoadout: AbilityLoadout,
        companionLoadout: AbilityLoadout,
        tier: SimulationPowerTier,
        rng: inout some RandomNumberGenerator,
    ) -> IdentityStarter {
        let heroGear = SimulationMatchupBuilder.generateStarterGearIfNeeded(
            for: hero,
            loadout: heroLoadout,
            tier: tier,
            idPrefix: "sim-hero",
            using: &rng,
        )
        let companionGear = SimulationMatchupBuilder.generateStarterGearIfNeeded(
            for: companion,
            loadout: companionLoadout,
            tier: tier,
            idPrefix: "sim-companion",
            using: &rng,
        )
        let heroTalents = SimulationMatchupBuilder.legalTalentKit(
            for: hero.id,
            level: tier.level,
            pointCap: tier.identityTalentPointCap,
            using: &rng,
        )
        let companionTalents = SimulationMatchupBuilder.legalTalentKit(
            for: companion.id,
            level: tier.level,
            pointCap: tier.identityTalentPointCap,
            using: &rng,
        )
        return IdentityStarter(
            heroGear: heroGear,
            companionGear: companionGear,
            heroTalents: heroTalents,
            companionTalents: companionTalents,
        )
    }

    private struct IdentityRecordParts {
        var tier: SimulationPowerTier
        var hero: Combatant
        var companion: Combatant
        var enemy: Enemy
        var matchup: ConfiguredSimulationMatchup
        var battleSeed: UInt64
        var policyID: String
        var result: BattleSimResult
    }

    private static func makeIdentityRecord(_ parts: IdentityRecordParts) -> BalanceBattleRecord {
        BalanceBattleRecord(
            tier: parts.tier,
            heroID: parts.hero.id,
            companionID: parts.companion.id,
            enemyID: parts.enemy.id,
            isBoss: parts.enemy.isBoss,
            heroAbilityIDs: parts.matchup.context.heroLoadout.abilities.map(\.id),
            companionAbilityIDs: parts.matchup.context.companionLoadout.abilities.map(\.id),
            enemyAbilityIDs: parts.matchup.enemy.abilities.map(\.id),
            enemyTraitID: parts.enemy.traitID,
            affixIDs: parts.matchup.context.heroAffixIDs + parts.matchup.context.companionAffixIDs,
            heroAffixIDs: parts.matchup.context.heroAffixIDs,
            companionAffixIDs: parts.matchup.context.companionAffixIDs,
            heroItemBaseIDs: parts.matchup.context.heroItemBaseIDs,
            companionItemBaseIDs: parts.matchup.context.companionItemBaseIDs,
            heroTalentIDs: parts.matchup.context.heroTalentIDs,
            companionTalentIDs: parts.matchup.context.companionTalentIDs,
            seed: parts.battleSeed,
            policyID: parts.policyID,
            result: parts.result,
        )
    }
}
