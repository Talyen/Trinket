import Foundation
import TrinketContent
import TrinketCore

enum BalanceAffixContrastRunner {
    struct Focus {
        var definition: ItemAffixDefinition
        var owner: Combatant
        var baseType: ItemBaseType
    }

    static func run(
        context: BalanceContrastContext,
        policy: some PlayerPolicy
    ) -> [PairedContrastSummary] {
        let gearTiers = context.config.tiers.filter(\.includesGear)
        guard !gearTiers.isEmpty else { return [] }

        let foci = makeFoci(heroes: context.heroes, companions: context.companions)
        guard !foci.isEmpty else { return [] }

        let work = BalanceContrastSupport.workItems(
            fociCount: foci.count,
            tiers: gearTiers,
            battlesPerTier: context.config.battlesPerTier
        )

        let pairResults = ParallelMap.map(work, jobs: context.config.resolvedJobs) { item in
            let focus = foci[item.focusIndex]
            let pair = runPair(
                focus: focus,
                tier: item.tier,
                pairIndex: item.pairIndex,
                context: context,
                policy: policy
            )
            return (item.focusIndex, item.tier, pair.entityWon, pair.baselineWon)
        }

        return BalanceContrastSupport.aggregate(
            foci: foci.map { ($0.definition.id, "no-\($0.definition.id)", $0.owner.id) },
            pairResults: pairResults,
            threshold: context.config.peerDeltaFlagThreshold
        )
    }

    private static func makeFoci(heroes: [Combatant], companions: [Combatant]) -> [Focus] {
        let owners = heroes + companions
        return GameContent.itemAffixDefinitions.compactMap { definition in
            guard let baseType = GameContent.itemBaseTypes.first(where: {
                $0.slot == definition.slot
                    && !definition.keywords.isDisjoint(with: $0.keywordAffinities)
            }) else { return nil }

            let owner = owners.first { candidate in
                definition.isAligned(withBuildKeywords: candidate.keywordProfile)
                    && candidate.role.equipmentSlots.contains {
                        $0.baseItemSlot == definition.slot
                    }
            }
            guard let owner else { return nil }
            return Focus(definition: definition, owner: owner, baseType: baseType)
        }
    }

    private static func runPair(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        policy: some PlayerPolicy
    ) -> (entityWon: Bool, baselineWon: Bool) {
        let pairSeed = context.config.seed
            &+ UInt64(tier.level) &* 800021
            &+ UInt64(pairIndex) &* 151
            &+ BalanceContrastSupport.stableHash64(focus.definition.id)
        var rng = SeededRandomNumberGenerator(seed: pairSeed)
        let setup = makePairSetup(
            focus: focus,
            tier: tier,
            pairIndex: pairIndex,
            context: context,
            pairSeed: pairSeed,
            using: &rng
        )
        return (
            BattleSimulator.run(
                matchup: setup.withEntity,
                policy: policy,
                maxRounds: context.config.maxRounds,
                maxActions: context.config.maxActions
            ).isVictory,
            BattleSimulator.run(
                matchup: setup.withBaseline,
                policy: policy,
                maxRounds: context.config.maxRounds,
                maxActions: context.config.maxActions
            ).isVictory
        )
    }

    private static func makePairSetup(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> (withEntity: ConfiguredSimulationMatchup, withBaseline: ConfiguredSimulationMatchup) {
        let partnerPool = focus.owner.role == .hero ? context.companions : context.heroes
        let partner = partnerPool.randomElement(using: &randomNumberGenerator) ?? partnerPool[0]
        let enemy = BalanceSampling.stratifiedEnemy(
            enemies: context.enemies,
            battleIndex: pairIndex,
            using: &randomNumberGenerator
        )
        let ownerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: focus.owner,
            level: tier.level,
            using: &randomNumberGenerator
        )
        let partnerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: partner,
            level: tier.level,
            using: &randomNumberGenerator
        )
        let gears = makeAffixGearPair(
            focus: focus,
            tier: tier,
            ownerLoadout: ownerLoadout,
            pairSeed: pairSeed
        )
        var fillRNG = SeededRandomNumberGenerator(seed: pairSeed &+ 41)
        let partnerGear = SimulationMatchupBuilder.generateAlignedGear(
            for: partner.withAbilityLoadoutPreservingEmptyTiers(partnerLoadout),
            tier: tier,
            keywordBias: partner.keywordProfile,
            idPrefix: "contrast-partner",
            using: &fillRNG
        )
        return (
            BalanceContrastSupport.buildMatchup(
                .init(
                    owner: focus.owner,
                    partner: partner,
                    ownerLoadout: ownerLoadout,
                    partnerLoadout: partnerLoadout,
                    ownerGear: gears.withAffix,
                    partnerGear: partnerGear,
                    enemy: enemy,
                    tier: tier,
                    seed: pairSeed
                )
            ),
            BalanceContrastSupport.buildMatchup(
                .init(
                    owner: focus.owner,
                    partner: partner,
                    ownerLoadout: ownerLoadout,
                    partnerLoadout: partnerLoadout,
                    ownerGear: gears.withoutAffix,
                    partnerGear: partnerGear,
                    enemy: enemy,
                    tier: tier,
                    seed: pairSeed
                )
            )
        )
    }

    private static func makeAffixGearPair(
        focus: Focus,
        tier: SimulationPowerTier,
        ownerLoadout: AbilityLoadout,
        pairSeed: UInt64
    ) -> (withAffix: SimulationMatchupBuilder.GearOverride, withoutAffix: SimulationMatchupBuilder.GearOverride) {
        let rarity = tier.rarity ?? .basic
        let affixCount = max(1, tier.fixedAffixCount ?? 1)
        let bias = focus.owner.keywordProfile
        var itemRNG = SeededRandomNumberGenerator(seed: pairSeed &+ 23)
        let withAffixItem = ItemGenerator().generate(
            id: "contrast-affix-\(focus.definition.id)",
            baseType: focus.baseType,
            rarity: rarity,
            fixedAffixCount: affixCount,
            keywordBias: bias,
            requireBuildAlignment: true,
            guaranteedAffixIDs: [focus.definition.id],
            using: &itemRNG
        )
        let withoutAffixItem = ItemGenerator(
            affixDefinitions: GameContent.itemAffixDefinitions.filter { $0.id != focus.definition.id }
        ).generate(
            id: "contrast-baseline-\(focus.definition.id)",
            baseType: focus.baseType,
            rarity: rarity,
            fixedAffixCount: affixCount,
            keywordBias: bias,
            requireBuildAlignment: true,
            using: &itemRNG
        )
        let slot = focus.owner.role.equipmentSlots.first {
            $0.baseItemSlot == focus.definition.slot
        } ?? focus.definition.slot
        var withLoadout = EquipmentLoadout()
        withLoadout.equip(withAffixItem, in: slot)
        var withoutLoadout = EquipmentLoadout()
        withoutLoadout.equip(withoutAffixItem, in: slot)
        var fillRNG = SeededRandomNumberGenerator(seed: pairSeed &+ 41)
        let filler = SimulationMatchupBuilder.generateAlignedGear(
            for: focus.owner.withAbilityLoadoutPreservingEmptyTiers(ownerLoadout),
            tier: tier,
            keywordBias: bias,
            idPrefix: "contrast-fill",
            using: &fillRNG
        )
        return (
            mergeGear(
                primary: .init(inventory: [withAffixItem], loadout: withLoadout),
                filler: filler,
                protectedSlot: slot
            ),
            mergeGear(
                primary: .init(inventory: [withoutAffixItem], loadout: withoutLoadout),
                filler: filler,
                protectedSlot: slot
            )
        )
    }

    private static func mergeGear(
        primary: SimulationMatchupBuilder.GearOverride,
        filler: SimulationMatchupBuilder.GearOverride?,
        protectedSlot: ItemSlot
    ) -> SimulationMatchupBuilder.GearOverride {
        guard let filler else { return primary }
        var inventory = primary.inventory
        var loadout = primary.loadout
        for (slot, itemID) in filler.loadout.itemIDsBySlot where slot != protectedSlot {
            guard loadout.itemID(for: slot) == nil,
                  let item = filler.inventory.first(where: { $0.id == itemID })
            else { continue }
            inventory.append(item)
            loadout.equip(item, in: slot)
        }
        return SimulationMatchupBuilder.GearOverride(inventory: inventory, loadout: loadout)
    }
}
