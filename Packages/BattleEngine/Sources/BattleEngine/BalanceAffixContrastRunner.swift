import BattleEngine
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
        policy: GreedyHeuristicPolicy
    ) -> [PairedContrastSummary] {
        guard !context.heroes.isEmpty,
              !context.companions.isEmpty,
              !context.enemies.isEmpty
        else { return [] }

        let foci = makeFoci(heroes: context.heroes, companions: context.companions)
        guard !foci.isEmpty else { return [] }

        return BalanceContrastSupport.runSweep(
            context: context,
            foci: foci,
            tiers: context.config.tiers.filter(\.includesGear),
            summarize: {
                (entityID: $0.definition.id, baselineID: "no-\($0.definition.id)", ownerID: $0.owner.id)
            },
            primes: (tier: 800021, pair: 151),
            makePair: { focus, tier, pairIndex, seed in
                makePairSetup(
                    focus: focus,
                    tier: tier,
                    pairIndex: pairIndex,
                    context: context,
                    pairSeed: seed
                )
            },
            policy: policy
        )
    }

    private static func makeFoci(heroes: [Combatant], companions: [Combatant]) -> [Focus] {
        let owners = heroes + companions
        return GameContent.itemAffixDefinitions.compactMap { definition in
            let owner = owners.first { candidate in
                definition.isAligned(withBuildKeywords: candidate.keywordProfile)
                    && candidate.role.equipmentSlots.contains {
                        $0.baseItemSlot == definition.slot
                    }
            }
            guard let owner else { return nil }
            let slot = owner.role.equipmentSlots.first {
                $0.baseItemSlot == definition.slot
            } ?? definition.slot
            guard let baseType = GameContent.itemBaseTypes.first(where: {
                $0.slot == definition.slot
                    && $0.canEquip(in: slot)
                    && !definition.keywords.isDisjoint(with: $0.keywordAffinities)
            }) else { return nil }
            return Focus(definition: definition, owner: owner, baseType: baseType)
        }
    }

    private static func makePairSetup(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64
    ) -> (withEntity: ConfiguredSimulationMatchup, withBaseline: ConfiguredSimulationMatchup) {
        var rng = SeededRandomNumberGenerator(seed: pairSeed)
        let partner = BalanceContrastSupport.pickPartner(
            for: focus.owner,
            from: context,
            using: &rng
        )
        let enemy = BalanceSampling.stratifiedEnemy(
            enemies: context.enemies,
            battleIndex: pairIndex,
            using: &rng
        )
        let ownerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: focus.owner,
            using: &rng
        )
        let partnerLoadout = SimulationMatchupBuilder.sampleLoadout(
            for: partner,
            using: &rng
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
        return BalanceContrastSupport.buildOwnerGearPair(
            base: .init(
                owner: focus.owner,
                partner: partner,
                ownerLoadout: ownerLoadout,
                partnerLoadout: partnerLoadout,
                ownerGear: nil,
                partnerGear: partnerGear,
                enemy: enemy,
                tier: tier,
                seed: pairSeed
            ),
            entityOwnerGear: gears.withAffix,
            baselineOwnerGear: gears.withoutAffix
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
        withLoadout.equip(withAffixItem, in: slot, inventory: [withAffixItem])
        var withoutLoadout = EquipmentLoadout()
        withoutLoadout.equip(withoutAffixItem, in: slot, inventory: [withoutAffixItem])
        precondition(
            withLoadout.itemID(for: slot) == withAffixItem.id
                && withoutLoadout.itemID(for: slot) == withoutAffixItem.id,
            "Affix contrast items must equip in their protected slot"
        )
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
            loadout.equip(item, in: slot, inventory: inventory)
        }
        return SimulationMatchupBuilder.GearOverride(inventory: inventory, loadout: loadout)
    }
}
