import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

enum BalanceAffixContrastRunner {
    struct Focus {
        var definition: ItemAffixDefinition
        var owner: Combatant
        var baseType: ItemBaseType
        var baselineKind: ContrastBaselineKind
    }

    static func foci(heroes: [Combatant], companions: [Combatant], focusIDs: [String]) -> [Focus] {
        let owners = heroes + companions
        let wanted = Set(focusIDs)
        return GameContent.itemAffixDefinitions.flatMap { definition -> [Focus] in
            if !wanted.isEmpty, !wanted.contains(definition.id) {
                return []
            }
            return owners.compactMap { owner -> [Focus]? in
                guard definition.isAligned(withBuildKeywords: owner.keywordProfile),
                      owner.role.equipmentSlots.contains(where: { $0.baseItemSlot == definition.slot })
                else { return nil }
                let slot = owner.role.equipmentSlots.first {
                    $0.baseItemSlot == definition.slot
                } ?? definition.slot
                guard let baseType = GameContent.itemBaseTypes.first(where: {
                    definition.isEligible(for: $0) && $0.canEquip(in: slot)
                }) else { return nil }
                let hasReplacement = GameContent.itemAffixDefinitions.contains {
                    $0.id != definition.id && $0.isEligible(for: baseType)
                        && $0.isAligned(withBuildKeywords: owner.keywordProfile)
                }
                return [
                    Focus(definition: definition, owner: owner, baseType: baseType, baselineKind: .emptySlot),
                    Focus(
                        definition: definition,
                        owner: owner,
                        baseType: baseType,
                        baselineKind: .replacementAffix,
                    ),
                ].filter { $0.baselineKind == .emptySlot || hasReplacement }
            }
            .flatMap(\.self)
        }
    }

    static func workCount(config: BalanceSweepConfig) -> Int {
        let roster = config.resolvedRoster
        let fociCount = foci(
            heroes: roster.heroes,
            companions: roster.companions,
            focusIDs: config.focusIDs,
        ).count
        let tiers = config.tiers
        return fociCount * tiers.count * config.battlesPerTier
    }

    static func run(
        context: BalanceContrastContext,
        policy: PlayPolicy,
    ) -> [PairedContrastSummary] {
        guard !context.heroes.isEmpty,
              !context.companions.isEmpty,
              !context.enemies.isEmpty
        else { return [] }

        let foci = foci(
            heroes: context.heroes,
            companions: context.companions,
            focusIDs: context.config.focusIDs,
        )
        guard !foci.isEmpty else { return [] }

        return BalanceContrastSupport.runSweep(
            context: context,
            foci: foci,
            tiers: context.config.tiers,
            summarize: {
                let baselineID = $0.baselineKind == .emptySlot
                    ? "empty-slot"
                    : "replacement-\($0.definition.id)"
                return (
                    entityID: $0.definition.id,
                    baselineID: baselineID,
                    ownerID: $0.owner.id,
                    baselineKind: $0.baselineKind,
                    nonCombat: false,
                )
            },
            primes: (tier: 800021, pair: 151),
            makePair: { focus, tier, pairIndex, seed in
                makePairSetup(
                    focus: focus,
                    tier: tier,
                    pairIndex: pairIndex,
                    context: context,
                    pairSeed: seed,
                )
            },
            policy: policy,
        )
    }

    private static func makePairSetup(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64,
    ) -> (withEntity: ConfiguredSimulationMatchup, withBaseline: ConfiguredSimulationMatchup) {
        var rng = SeededRandomNumberGenerator(seed: pairSeed)
        let partner = BalanceContrastSupport.pickPartner(
            for: focus.owner,
            from: context,
            using: &rng,
        )
        let enemy = BalanceContrastSupport.roundRobinEnemy(
            enemies: context.enemies,
            pairIndex: pairIndex,
        )
        let ownerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: focus.owner,
            using: &rng,
        )
        let partnerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: partner,
            using: &rng,
        )
        let gears = makeAffixGearPair(
            focus: focus,
            tier: tier,
            ownerLoadout: ownerLoadout,
            pairSeed: pairSeed,
        )
        var fillRNG = SeededRandomNumberGenerator(seed: pairSeed &+ 41)
        let partnerGear = SimulationMatchupBuilder.generateStarterGearIfNeeded(
            for: partner,
            loadout: partnerLoadout,
            tier: tier,
            idPrefix: "contrast-partner",
            using: &fillRNG,
        ) ?? SimulationMatchupBuilder.generateAlignedGear(
            for: partner.withAbilityLoadoutPreservingEmptyTiers(partnerLoadout),
            tier: tier,
            keywordBias: partner.keywordProfile,
            idPrefix: "contrast-partner",
            using: &fillRNG,
        )
        return BalanceContrastSupport.buildOwnerPair(
            base: .init(
                owner: focus.owner,
                partner: partner,
                ownerLoadout: ownerLoadout,
                partnerLoadout: partnerLoadout,
                ownerGear: nil,
                partnerGear: partnerGear,
                enemy: enemy,
                tier: tier,
                seed: pairSeed,
            ),
        ) { parts, isEntity in
            parts.ownerGear = isEntity ? gears.withAffix : gears.baseline
        }
    }

    static func makeAffixGearPair(
        focus: Focus,
        tier: SimulationPowerTier,
        ownerLoadout: AbilityLoadout,
        pairSeed: UInt64,
    ) -> (withAffix: SimulationMatchupBuilder.GearOverride, baseline: SimulationMatchupBuilder.GearOverride) {
        let (withAffixItem, baselineItem) = makeAffixItems(focus: focus, tier: tier, pairSeed: pairSeed)
        let bias = focus.owner.keywordProfile
        let slot = focus.owner.role.equipmentSlots.first {
            $0.baseItemSlot == focus.definition.slot
        } ?? focus.definition.slot
        var withLoadout = EquipmentLoadout()
        withLoadout.equip(withAffixItem, in: slot, inventory: [withAffixItem])
        var baselineLoadout = EquipmentLoadout()
        baselineLoadout.equip(baselineItem, in: slot, inventory: [baselineItem])
        precondition(
            withLoadout.itemID(for: slot) == withAffixItem.id
                && baselineLoadout.itemID(for: slot) == baselineItem.id,
            "Affix contrast items must equip in their protected slot",
        )
        var fillRNG = SeededRandomNumberGenerator(seed: pairSeed &+ 41)
        let filler = SimulationMatchupBuilder.generateAlignedGear(
            for: focus.owner.withAbilityLoadoutPreservingEmptyTiers(ownerLoadout),
            tier: tier,
            keywordBias: bias,
            idPrefix: "contrast-fill",
            using: &fillRNG,
        )
        return (
            mergeGear(
                primary: .init(inventory: [withAffixItem], loadout: withLoadout),
                filler: filler,
                protectedSlot: slot,
            ),
            mergeGear(
                primary: .init(inventory: [baselineItem], loadout: baselineLoadout),
                filler: filler,
                protectedSlot: slot,
            ),
        )
    }

    private static func makeAffixItems(
        focus: Focus,
        tier: SimulationPowerTier,
        pairSeed: UInt64,
    ) -> (InventoryItem, InventoryItem) {
        let rarity = tier.rarity ?? .basic
        let affixCount = max(1, tier.fixedAffixCount ?? 1)
        let bias = focus.owner.keywordProfile
        var itemRNG = SeededRandomNumberGenerator(seed: pairSeed &+ 23)
        let replacement = ItemGenerator(
            affixDefinitions: GameContent.itemAffixDefinitions.filter { $0.id != focus.definition.id },
        ).generate(
            id: "contrast-replacement",
            baseType: focus.baseType,
            rarity: rarity,
            fixedAffixCount: focus.baselineKind == .replacementAffix ? 1 : 0,
            keywordBias: bias,
            requireBuildAlignment: true,
            using: &itemRNG,
        )
        let replacementIDs = Set(replacement.affixes.map(\.id))
        let withAffixItem = ItemGenerator(
            affixDefinitions: GameContent.itemAffixDefinitions.filter { !replacementIDs.contains($0.id) },
        ).generate(
            id: "contrast-affix-\(focus.definition.id)",
            baseType: focus.baseType,
            rarity: rarity,
            fixedAffixCount: affixCount,
            keywordBias: bias,
            requireBuildAlignment: true,
            guaranteedAffixIDs: [focus.definition.id],
            using: &itemRNG,
        )
        let retained = withAffixItem.affixes.indices.filter {
            withAffixItem.affixes[$0].id != focus.definition.id
        }
        let baselineItem = InventoryItem(
            id: "contrast-baseline-\(focus.definition.id)",
            baseType: withAffixItem.baseType,
            rarity: withAffixItem.rarity,
            displayName: withAffixItem.displayName,
            affixes: retained.map { withAffixItem.affixes[$0] } + replacement.affixes,
            affixPowers: retained.compactMap { withAffixItem.affixPowers?[$0] } + (replacement.affixPowers ?? []),
        )
        return (withAffixItem, baselineItem)
    }

    private static func mergeGear(
        primary: SimulationMatchupBuilder.GearOverride,
        filler: SimulationMatchupBuilder.GearOverride?,
        protectedSlot: ItemSlot,
    ) -> SimulationMatchupBuilder.GearOverride {
        guard let filler else { return primary }
        var inventory = primary.inventory
        var loadout = primary.loadout
        for (slot, itemID) in filler.loadout.itemIDsBySlot where slot != protectedSlot {
            guard loadout.itemID(for: slot) == nil,
                  let item = filler.inventory.first(where: { $0.id == itemID })
            else { continue }
            inventory.append(item)
            loadout.equip(item, in: slot, inventory: inventory)
        }
        return SimulationMatchupBuilder.GearOverride(inventory: inventory, loadout: loadout)
    }
}
