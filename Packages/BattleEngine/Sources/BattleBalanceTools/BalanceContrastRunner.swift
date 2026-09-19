import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

/// Shared execution shell for the three isolated-contrast modes. Each mode owns
/// its focus scan and pair construction; the parallel sweep plumbing lives here.
enum BalanceContrastRunner {
    typealias Summary = (
        entityID: String,
        baselineID: String,
        ownerID: String,
        baselineKind: ContrastBaselineKind,
        nonCombat: Bool,
    )

    static func run<Focus: Sendable>(
        context: BalanceContrastContext,
        policy: PlayPolicy,
        foci: [Focus],
        summarize: @escaping @Sendable (Focus) -> Summary,
        primes: @escaping @Sendable (Focus) -> (tier: UInt64, pair: UInt64),
        makePair: @escaping @Sendable (Focus, SimulationPowerTier, Int, UInt64) -> BalanceContrastSupport.Pair?,
    ) -> [PairedContrastSummary] {
        BalanceContrastSupport.runSweep(
            context: context,
            foci: foci,
            tiers: context.config.tiers,
            summarize: summarize,
            primes: primes,
            makePair: makePair,
            policy: policy,
        )
    }
}

enum BalanceAbilityContrastRunner {
    struct Focus {
        var owner: Combatant
        var focus: Ability
        var sibling: Ability
    }

    static func foci(heroes: [Combatant], companions: [Combatant], focusIDs: [String]) -> [Focus] {
        let wanted = Set(focusIDs)
        return (heroes + companions).flatMap { owner -> [Focus] in
            AbilityTier.allCases.flatMap { tier -> [Focus] in
                let choices = owner.abilityChoices.abilities(for: tier).sorted { $0.id < $1.id }
                guard choices.count >= 2 else { return [] }
                var pairs: [Focus] = []
                for i in 0 ..< choices.count {
                    for j in (i + 1) ..< choices.count {
                        guard wanted.isEmpty
                            || wanted.contains(choices[i].id)
                            || wanted.contains(choices[j].id)
                        else {
                            continue
                        }
                        pairs.append(Focus(owner: owner, focus: choices[i], sibling: choices[j]))
                    }
                }
                return pairs
            }
        }
    }

    static func workCount(config: BalanceSweepConfig) -> Int {
        BalanceContrastSupport.rosterFociWorkCount(config: config) {
            foci(heroes: $0, companions: $1, focusIDs: $2).count
        }
    }

    static func run(
        context: BalanceContrastContext,
        policy: PlayPolicy,
    ) -> [PairedContrastSummary] {
        BalanceContrastRunner.run(
            context: context,
            policy: policy,
            foci: foci(
                heroes: context.heroes,
                companions: context.companions,
                focusIDs: context.config.focusIDs,
            ),
            summarize: {
                (
                    entityID: $0.focus.id,
                    baselineID: $0.sibling.id,
                    ownerID: $0.owner.id,
                    baselineKind: .sibling,
                    nonCombat: false,
                )
            },
            primes: { _ in (tier: 900011, pair: 131) },
            makePair: { focus, tier, pairIndex, seed in
                makePairSetup(
                    focus: focus,
                    tier: tier,
                    pairIndex: pairIndex,
                    context: context,
                    pairSeed: seed,
                )
            },
        )
    }

    private static func makePairSetup(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64,
    ) -> BalanceContrastSupport.Pair {
        let sampled = BalanceContrastSupport.sampleBasePair(
            owner: focus.owner,
            pairIndex: pairIndex,
            context: context,
            pairSeed: pairSeed,
        )
        let focusLoadout = sampled.ownerLoadout.selecting(focus.focus)
        let siblingLoadout = sampled.ownerLoadout.selecting(focus.sibling)
        // Gear stays aligned to the focus loadout, matching historical
        // sampling: both sides of the pair wear the same gear so only the
        // loadout choice varies.
        let gears = BalanceContrastSupport.sharedGear(
            owner: focus.owner,
            partner: sampled.partner,
            ownerLoadout: focusLoadout,
            partnerLoadout: sampled.partnerLoadout,
            tier: tier,
            pairSeed: pairSeed,
        )
        let base = ContrastMatchupBase(
            owner: focus.owner,
            partner: sampled.partner,
            enemy: sampled.enemy,
            ownerLoadout: focusLoadout,
            partnerLoadout: sampled.partnerLoadout,
            ownerGear: gears.owner,
            partnerGear: gears.partner,
            tier: tier,
            seed: pairSeed,
        )
        return (
            base.matchup(ownerLoadout: focusLoadout),
            base.matchup(ownerLoadout: siblingLoadout),
        )
    }
}

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
        BalanceContrastSupport.rosterFociWorkCount(config: config) {
            foci(heroes: $0, companions: $1, focusIDs: $2).count
        }
    }

    static func run(
        context: BalanceContrastContext,
        policy: PlayPolicy,
    ) -> [PairedContrastSummary] {
        BalanceContrastRunner.run(
            context: context,
            policy: policy,
            foci: foci(
                heroes: context.heroes,
                companions: context.companions,
                focusIDs: context.config.focusIDs,
            ),
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
            primes: { _ in (tier: 800021, pair: 151) },
            makePair: { focus, tier, pairIndex, seed in
                makePairSetup(
                    focus: focus,
                    tier: tier,
                    pairIndex: pairIndex,
                    context: context,
                    pairSeed: seed,
                )
            },
        )
    }

    private static func makePairSetup(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64,
    ) -> BalanceContrastSupport.Pair {
        let sampled = BalanceContrastSupport.sampleBasePair(
            owner: focus.owner,
            pairIndex: pairIndex,
            context: context,
            pairSeed: pairSeed,
        )
        let gears = makeAffixGearPair(
            focus: focus,
            tier: tier,
            ownerLoadout: sampled.ownerLoadout,
            pairSeed: pairSeed,
        )
        var fillRNG = SeededRandomNumberGenerator(seed: pairSeed &+ 41)
        let partnerGear = SimulationMatchupBuilder.generateStarterGearIfNeeded(
            for: sampled.partner,
            loadout: sampled.partnerLoadout,
            tier: tier,
            idPrefix: "contrast-partner",
            using: &fillRNG,
        ) ?? SimulationMatchupBuilder.generateAlignedGear(
            for: sampled.partner.withAbilityLoadoutPreservingEmptyTiers(sampled.partnerLoadout),
            tier: tier,
            keywordBias: sampled.partner.keywordProfile,
            idPrefix: "contrast-partner",
            using: &fillRNG,
        )
        let base = ContrastMatchupBase(
            owner: focus.owner,
            partner: sampled.partner,
            enemy: sampled.enemy,
            ownerLoadout: sampled.ownerLoadout,
            partnerLoadout: sampled.partnerLoadout,
            ownerGear: nil,
            partnerGear: partnerGear,
            tier: tier,
            seed: pairSeed,
        )
        return (
            base.matchup(ownerGear: gears.withAffix),
            base.matchup(ownerGear: gears.baseline),
        )
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

enum BalanceTalentContrastRunner {
    struct SiblingFocus {
        var owner: Combatant
        var focusID: String
        var siblingID: String?
        var prefix: Set<String>
        var treeKeyword: Keyword
    }

    struct KitFocus {
        var owner: Combatant
        var kit: Set<String>
    }

    static func siblingFoci(heroes: [Combatant], companions: [Combatant], focusIDs: [String]) -> [SiblingFocus] {
        let wanted = Set(focusIDs)
        return (heroes + companions).flatMap { owner -> [SiblingFocus] in
            CombatantTalentCatalog.config(for: owner.id).trees.flatMap { tree -> [SiblingFocus] in
                tree.rows.compactMap { row -> SiblingFocus? in
                    let nodes = tree.nodes(forRow: row).sorted { $0.id < $1.id }
                    guard let focus = nodes.first(where: { wanted.isEmpty || wanted.contains($0.id) }) else { return nil }
                    return SiblingFocus(
                        owner: owner,
                        focusID: focus.id,
                        siblingID: nodes.first(where: { $0.id != focus.id })?.id,
                        prefix: SimulationMatchupBuilder.minimalPrefix(for: tree, throughRow: row),
                        treeKeyword: tree.keyword,
                    )
                }
            }
        }
    }

    static func kitFoci(heroes: [Combatant], companions: [Combatant], focusIDs: [String]) -> [KitFocus] {
        let wanted = Set(focusIDs)
        return (heroes + companions).compactMap { owner -> KitFocus? in
            if !wanted.isEmpty, !wanted.contains(owner.id), !wanted.contains("full-kit") {
                return nil
            }
            let kit = CombatantTalentCatalog.validNodeIDs(for: owner.id)
            guard !kit.isEmpty else { return nil }
            return KitFocus(owner: owner, kit: kit)
        }
    }

    static func isSiblingLegal(focus: SiblingFocus, tier: SimulationPowerTier) -> Bool {
        let points = CombatantProgression.at(level: tier.level).totalTalentPoints
        let needed = focus.prefix.count + 1
        return points >= needed
    }

    static func isKitLegal(focus: KitFocus, tier: SimulationPowerTier) -> Bool {
        CombatantProgression.at(level: tier.level).totalTalentPoints >= focus.kit.count
    }

    static func workCount(config: BalanceSweepConfig) -> Int {
        siblingWorkCount(config: config) + kitWorkCount(config: config)
    }

    static func siblingWorkCount(config: BalanceSweepConfig) -> Int {
        BalanceContrastSupport.rosterFociWorkCount(config: config) {
            siblingFoci(heroes: $0, companions: $1, focusIDs: $2).count
        }
    }

    static func kitWorkCount(config: BalanceSweepConfig) -> Int {
        BalanceContrastSupport.rosterFociWorkCount(config: config) {
            kitFoci(heroes: $0, companions: $1, focusIDs: $2).count
        }
    }

    enum Focus: Sendable {
        case sibling(SiblingFocus)
        case kit(KitFocus)
    }

    static func run(
        context: BalanceContrastContext,
        policy: PlayPolicy,
    ) -> (sibling: [PairedContrastSummary], kit: [PairedContrastSummary]) {
        guard !context.heroes.isEmpty,
              !context.companions.isEmpty,
              !context.enemies.isEmpty
        else { return ([], []) }

        let foci = siblingFoci(
            heroes: context.heroes,
            companions: context.companions,
            focusIDs: context.config.focusIDs,
        ).map(Focus.sibling) + kitFoci(
            heroes: context.heroes,
            companions: context.companions,
            focusIDs: context.config.focusIDs,
        ).map(Focus.kit)

        let summaries = BalanceContrastRunner.run(
            context: context,
            policy: policy,
            foci: foci,
            summarize: summarize,
            primes: primes,
            makePair: { focus, tier, pairIndex, seed in
                makePair(focus: focus, tier: tier, pairIndex: pairIndex, seed: seed, context: context)
            },
        )

        return (
            summaries.filter { $0.baselineKind != .fullKit },
            summaries.filter { $0.baselineKind == .fullKit },
        )
    }

    private static func summarize(_ focus: Focus) -> BalanceContrastRunner.Summary {
        switch focus {
        case let .sibling(f):
            (
                entityID: f.focusID,
                baselineID: f.siblingID ?? "none",
                ownerID: f.owner.id,
                baselineKind: f.siblingID == nil ? .none : .sibling,
                nonCombat: f.treeKeyword == .gold,
            )
        case let .kit(f):
            (
                entityID: "full-kit",
                baselineID: "none",
                ownerID: f.owner.id,
                baselineKind: .fullKit,
                nonCombat: false,
            )
        }
    }

    private static func primes(for focus: Focus) -> (tier: UInt64, pair: UInt64) {
        switch focus {
        case .sibling: (tier: 700031, pair: 173)
        case .kit: (tier: 700041, pair: 179)
        }
    }

    private static func makePair(
        focus: Focus,
        tier: SimulationPowerTier,
        pairIndex: Int,
        seed: UInt64,
        context: BalanceContrastContext,
    ) -> BalanceContrastSupport.Pair? {
        switch focus {
        case let .sibling(f):
            guard isSiblingLegal(focus: f, tier: tier) else { return nil }
            return makeTalentPair(
                owner: f.owner,
                entityTalents: f.prefix.union([f.focusID]),
                baselineTalents: f.prefix.union([f.siblingID].compactMap(\.self)),
                tier: tier,
                pairIndex: pairIndex,
                context: context,
                pairSeed: seed,
            )
        case let .kit(f):
            guard isKitLegal(focus: f, tier: tier) else { return nil }
            return makeTalentPair(
                owner: f.owner,
                entityTalents: f.kit,
                baselineTalents: [],
                tier: tier,
                pairIndex: pairIndex,
                context: context,
                pairSeed: seed,
            )
        }
    }

    private static func makeTalentPair(
        owner: Combatant,
        entityTalents: Set<String>,
        baselineTalents: Set<String>,
        tier: SimulationPowerTier,
        pairIndex: Int,
        context: BalanceContrastContext,
        pairSeed: UInt64,
    ) -> BalanceContrastSupport.Pair {
        let base = BalanceContrastSupport.base(
            owner: owner,
            tier: tier,
            pairIndex: pairIndex,
            context: context,
            pairSeed: pairSeed,
        )
        return (
            base.matchup(ownerTalents: entityTalents),
            base.matchup(ownerTalents: baselineTalents),
        )
    }
}
