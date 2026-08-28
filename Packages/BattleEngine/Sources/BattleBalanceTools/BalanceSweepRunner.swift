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
        enemies: [Enemy]? = nil
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
                enemies: resolvedEnemies
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
                enemies: resolvedEnemies
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
            enemies: resolvedEnemies
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
                + Double(elapsed.components.attoseconds) / 1e18
        )
    }

    private static func runContrastsIfNeeded(
        config: BalanceSweepConfig,
        policy: PlayPolicy,
        heroes: [Combatant],
        companions: [Combatant],
        enemies: [Enemy]
    ) -> (
        ability: [PairedContrastSummary],
        affix: [PairedContrastSummary],
        talent: [PairedContrastSummary],
        talentKit: [PairedContrastSummary]
    ) {
        let runAbility = config.mode == .abilityContrast || config.mode == .all
        let runAffix = config.mode == .affixContrast || config.mode == .all
        let runTalent = config.mode == .talentContrast || config.mode == .all
        guard runAbility || runAffix || runTalent else { return ([], [], [], []) }

        let contrastContext = BalanceContrastContext(
            config: config,
            heroes: heroes,
            companions: companions,
            enemies: enemies
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
        policy: PlayPolicy
    ) -> (
        records: [ProgressionBattleRecord],
        hotspots: [NodeHotspotSummary],
        playerStates: [PlayerProgressionState],
        truncatedRuns: Int
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
        enemies: [Enemy]
    ) -> [BalanceBattleRecord] {
        let work: [(SimulationPowerTier, Int, Int)] = config.sliceWork(
            config.tiers.flatMap { tier in
                enemies.indices.flatMap { enemyIndex in
                    (0 ..< config.battlesPerTier).map { sample in
                        (tier, enemyIndex, sample)
                    }
                }
            }
        )
        return ParallelMap.map(work) { entry in
            simulateIdentityBattle(
                IdentityBattleWork(
                    config: config,
                    policy: policy,
                    heroes: heroes,
                    companions: companions,
                    enemies: enemies,
                    tier: entry.0,
                    enemyIndex: entry.1,
                    sampleIndex: entry.2
                )
            )
        }
    }

    private struct IdentityBattleWork {
        var config: BalanceSweepConfig
        var policy: PlayPolicy
        var heroes: [Combatant]
        var companions: [Combatant]
        var enemies: [Enemy]
        var tier: SimulationPowerTier
        var enemyIndex: Int
        var sampleIndex: Int
    }

    private static func identityBattleSeed(_ work: IdentityBattleWork) -> UInt64 {
        work.config.seed
            &+ UInt64(work.tier.level) &* 1000003
            &+ UInt64(work.enemyIndex) &* 10007
            &+ UInt64(work.sampleIndex) &* 97
    }

    private static func simulateIdentityBattle(_ work: IdentityBattleWork) -> BalanceBattleRecord {
        let config = work.config
        let battleSeed = identityBattleSeed(work)
        var rng = SeededRandomNumberGenerator(seed: battleSeed)

        let slot = work.enemyIndex * config.battlesPerTier + work.sampleIndex
        let hero = work.heroes[slot % work.heroes.count]
        let companion = work.companions[(slot / max(work.heroes.count, 1)) % work.companions.count]
        let enemy = work.enemies[work.enemyIndex]
        let partyLoadouts = SimulationMatchupBuilder.samplePartyLoadouts(
            hero: hero,
            companion: companion,
            using: &rng
        )
        let heroLoadout = partyLoadouts.hero
        let companionLoadout = partyLoadouts.companion
        let starter = identityStarterLoadout(
            hero: hero,
            companion: companion,
            heroLoadout: heroLoadout,
            companionLoadout: companionLoadout,
            tier: work.tier,
            rng: &rng
        )
        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: work.tier,
            heroLoadout: heroLoadout,
            companionLoadout: companionLoadout,
            seed: battleSeed,
            loadoutSampleIndex: slot,
            heroGear: starter.heroGear,
            companionGear: starter.companionGear,
            heroTalents: starter.heroTalents,
            companionTalents: starter.companionTalents
        )

        let result = BattleSimulator.run(
            matchup: matchup,
            policy: work.policy,
            maxRounds: config.maxRounds,
            maxActions: config.maxActions,
            appliesFightPacing: config.appliesFightPacing
        )
        return makeIdentityRecord(
            IdentityRecordParts(
                work: work,
                hero: hero,
                companion: companion,
                enemy: enemy,
                matchup: matchup,
                battleSeed: battleSeed,
                result: result
            )
        )
    }

    private struct IdentityStarterLoadout {
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
        rng: inout some RandomNumberGenerator
    ) -> IdentityStarterLoadout {
        IdentityStarterLoadout(
            heroGear: SimulationMatchupBuilder.generateStarterGearIfNeeded(
                for: hero,
                loadout: heroLoadout,
                tier: tier,
                idPrefix: "sim-hero",
                using: &rng
            ),
            companionGear: SimulationMatchupBuilder.generateStarterGearIfNeeded(
                for: companion,
                loadout: companionLoadout,
                tier: tier,
                idPrefix: "sim-companion",
                using: &rng
            ),
            heroTalents: SimulationMatchupBuilder.legalTalentKit(
                for: hero.id,
                level: tier.level,
                pointCap: tier.identityTalentPointCap,
                using: &rng
            ),
            companionTalents: SimulationMatchupBuilder.legalTalentKit(
                for: companion.id,
                level: tier.level,
                pointCap: tier.identityTalentPointCap,
                using: &rng
            )
        )
    }

    private struct IdentityRecordParts {
        var work: IdentityBattleWork
        var hero: Combatant
        var companion: Combatant
        var enemy: Enemy
        var matchup: ConfiguredSimulationMatchup
        var battleSeed: UInt64
        var result: BattleSimResult
    }

    private static func makeIdentityRecord(_ parts: IdentityRecordParts) -> BalanceBattleRecord {
        let matchup = parts.matchup
        let enemy = parts.enemy
        return BalanceBattleRecord(
            tier: parts.work.tier,
            heroID: parts.hero.id,
            companionID: parts.companion.id,
            enemyID: enemy.id,
            isBoss: enemy.isBoss,
            heroAbilityIDs: matchup.context.heroLoadout.abilities.map(\.id),
            companionAbilityIDs: matchup.context.companionLoadout.abilities.map(\.id),
            enemyAbilityIDs: matchup.enemy.abilities.map(\.id),
            enemyTraitID: enemy.traitID,
            affixIDs: matchup.context.heroAffixIDs + matchup.context.companionAffixIDs,
            heroAffixIDs: matchup.context.heroAffixIDs,
            companionAffixIDs: matchup.context.companionAffixIDs,
            heroTalentIDs: matchup.context.heroTalentIDs,
            companionTalentIDs: matchup.context.companionTalentIDs,
            seed: parts.battleSeed,
            policyID: parts.work.policy.id,
            result: parts.result
        )
    }
}

enum ParallelMap {
    static func map<Input: Sendable, Output: Sendable>(
        _ inputs: [Input],
        transform: @escaping @Sendable (Input) -> Output
    ) -> [Output] {
        guard !inputs.isEmpty else { return [] }
        var results: [Output] = []
        results.reserveCapacity(inputs.count)
        for input in inputs {
            results.append(transform(input))
        }
        return results
    }
}
