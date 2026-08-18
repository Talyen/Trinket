import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

/// Assembles leveled, loadout-selected, optionally geared matchups for balance sweeps.
public enum SimulationMatchupBuilder {
    public struct GearOverride: Equatable, Sendable {
        public var inventory: [InventoryItem]
        public var loadout: EquipmentLoadout

        public init(inventory: [InventoryItem], loadout: EquipmentLoadout) {
            self.inventory = inventory
            self.loadout = loadout
        }

        public init(_ build: ThemedGearBuild) {
            inventory = build.inventory
            loadout = build.loadout
        }
    }

    public static func build(
        hero: Combatant,
        companion: Combatant,
        enemy: Enemy,
        tier: SimulationPowerTier,
        heroLevel: Int? = nil,
        companionLevel: Int? = nil,
        enemyLevel: Int? = nil,
        heroLoadout: AbilityLoadout,
        companionLoadout: AbilityLoadout,
        seed: UInt64,
        loadoutSampleIndex: Int = 0,
        heroGear: GearOverride? = nil,
        companionGear: GearOverride? = nil,
        heroTalents: Set<String> = [],
        companionTalents: Set<String> = [],
        gearKeywordBias: Set<Keyword>? = nil,
        gearGenerator: ThemedGearGenerator = ThemedGearGenerator()
    ) -> ConfiguredSimulationMatchup {
        var rng = SeededRandomNumberGenerator(seed: seed)
        let resolvedHeroLevel = heroLevel ?? tier.level
        let resolvedCompanionLevel = companionLevel ?? tier.level
        let resolvedEnemyLevel = enemyLevel ?? tier.level

        let heroRequest = PartyPrepareRequest(
            progression: Self.progression(level: resolvedHeroLevel),
            tier: tier,
            idPrefix: "sim-hero",
            gearOverride: heroGear,
            unlockedTalents: heroTalents,
            gearKeywordBias: gearKeywordBias,
            gearGenerator: gearGenerator
        )
        let companionRequest = PartyPrepareRequest(
            progression: Self.progression(level: resolvedCompanionLevel),
            tier: tier,
            idPrefix: "sim-companion",
            gearOverride: companionGear,
            unlockedTalents: companionTalents,
            gearKeywordBias: gearKeywordBias,
            gearGenerator: gearGenerator
        )

        let heroPrepared = preparePartyMember(
            hero,
            loadout: heroLoadout,
            request: heroRequest,
            using: &rng
        )
        let companionPrepared = preparePartyMember(
            companion,
            loadout: companionLoadout,
            request: companionRequest,
            using: &rng
        )

        let scaledEnemy = CombatantLevelScaler.scale(enemy: enemy, level: resolvedEnemyLevel)
        let enemyBuild = CombatBuildResolver.build(enemy: enemy)

        let context = SimulationBuildContext(
            tier: tier,
            heroLoadout: heroPrepared.loadout,
            companionLoadout: companionPrepared.loadout,
            loadoutSampleIndex: loadoutSampleIndex,
            seed: seed,
            heroAffixIDs: heroPrepared.affixIDs,
            companionAffixIDs: companionPrepared.affixIDs,
            heroTalentIDs: heroTalents.sorted(),
            companionTalentIDs: companionTalents.sorted()
        )

        return ConfiguredSimulationMatchup(
            hero: heroPrepared.build.combatant,
            companion: companionPrepared.build.combatant,
            enemy: scaledEnemy,
            heroModifiers: heroPrepared.build.modifiers,
            companionModifiers: companionPrepared.build.modifiers,
            enemyModifiers: enemyBuild.modifiers,
            context: context,
            enemyID: enemy.id,
            isBoss: enemy.isBoss
        )
    }

    /// Random legal loadout from a combatant's choice pools.
    public static func sampleLoadout(
        for combatant: Combatant,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> AbilityLoadout {
        let choices = combatant.abilityChoices
        let basic = choices.basics.randomElement(using: &randomNumberGenerator)
        let skill = choices.skills.randomElement(using: &randomNumberGenerator)
        let ultimate = choices.ultimates.randomElement(using: &randomNumberGenerator)
        return AbilityLoadout(basic: basic, skill: skill, ultimate: ultimate)
    }

    public static func generateAlignedGear(
        for combatant: Combatant,
        tier: SimulationPowerTier,
        keywordBias: Set<Keyword>,
        idPrefix: String,
        gearGenerator: ThemedGearGenerator = ThemedGearGenerator(),
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> GearOverride? {
        guard tier.includesGear,
              let rarity = tier.rarity,
              let affixCount = tier.fixedAffixCount
        else { return nil }

        let scaled = CombatantLevelScaler.scale(combatant: combatant, level: tier.level)
        let gear = gearGenerator.generate(
            for: scaled,
            rarity: rarity,
            fixedAffixCount: affixCount,
            idPrefix: idPrefix,
            keywordBias: keywordBias,
            requireBuildAlignment: true,
            using: &randomNumberGenerator
        )
        return GearOverride(gear)
    }

    /// Spends available talent points on a legal row-gated kit.
    /// Full catalog when points cover every node; otherwise a random legal walk.
    public static func legalTalentKit(
        for combatantID: String,
        level: Int,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> Set<String> {
        let nodes = CombatantTalentCatalog.validNodeIDs(for: combatantID)
        let points = CombatantProgression.at(level: level).totalTalentPoints
        guard points > 0, !nodes.isEmpty else { return [] }
        if points >= nodes.count {
            return nodes
        }

        let config = CombatantTalentCatalog.config(for: combatantID)
        var unlocked = Set<String>()
        for _ in 0 ..< points {
            let candidates = config.trees.flatMap { tree in
                tree.nodes.filter {
                    tree.canUnlock(node: $0, unlockedNodeIDs: unlocked, availablePoints: 1)
                }
            }
            guard let pick = candidates.randomElement(using: &randomNumberGenerator) else { break }
            unlocked.insert(pick.id)
        }
        return unlocked
    }

    /// Both nodes in rows strictly below `row` in `tree` (row-gate prefix for sibling contrast).
    public static func minimalPrefix(for tree: TalentTree, throughRow row: Int) -> Set<String> {
        Set(tree.nodes.filter { $0.row < row }.map(\.id))
    }

    public static func progression(level: Int) -> CombatantProgression {
        CombatantProgression(
            level: level,
            currentXP: 0,
            requiredXP: CombatantProgression.requiredXP(forLevel: level)
        )
    }

    private struct PartyPrepareRequest {
        var progression: CombatantProgression
        var tier: SimulationPowerTier
        var idPrefix: String = ""
        var gearOverride: GearOverride?
        var unlockedTalents: Set<String> = []
        var gearKeywordBias: Set<Keyword>?
        var gearGenerator: ThemedGearGenerator

        func with(idPrefix: String, gearOverride: GearOverride?) -> Self {
            var copy = self
            copy.idPrefix = idPrefix
            copy.gearOverride = gearOverride
            return copy
        }
    }

    private struct PreparedPartyMember {
        var build: CombatBuild
        var loadout: AbilityLoadout
        var affixIDs: [String]
    }

    private static func preparePartyMember(
        _ combatant: Combatant,
        loadout: AbilityLoadout,
        request: PartyPrepareRequest,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> PreparedPartyMember {
        let withLoadout = combatant.withAbilityLoadoutPreservingEmptyTiers(loadout)
        let scaled = CombatantLevelScaler.scale(combatant: withLoadout, level: request.progression.level)

        if let gearOverride = request.gearOverride {
            let sanitized = gearOverride.loadout.sanitized(for: scaled, inventory: gearOverride.inventory)
            let build = CombatBuildResolver.build(
                combatant: scaled,
                equipmentLoadout: sanitized,
                inventory: gearOverride.inventory,
                unlockedTalents: request.unlockedTalents
            )
            let affixIDs = gearOverride.inventory.flatMap { $0.affixes.map(\.id) }
            return PreparedPartyMember(build: build, loadout: loadout, affixIDs: affixIDs)
        }

        guard request.tier.includesGear,
              let rarity = request.tier.rarity,
              let affixCount = request.tier.fixedAffixCount
        else {
            let build = CombatBuildResolver.build(
                combatant: scaled,
                equipmentLoadout: EquipmentLoadout(),
                inventory: [],
                unlockedTalents: request.unlockedTalents
            )
            return PreparedPartyMember(build: build, loadout: loadout, affixIDs: [])
        }

        let buildKeywords = request.gearKeywordBias ?? Set(scaled.abilities.flatMap(\.keywords))
        let gear = request.gearGenerator.generate(
            for: scaled,
            rarity: rarity,
            fixedAffixCount: affixCount,
            idPrefix: request.idPrefix,
            keywordBias: buildKeywords,
            requireBuildAlignment: true,
            using: &randomNumberGenerator
        )
        let sanitized = gear.loadout.sanitized(for: scaled, inventory: gear.inventory)
        let build = CombatBuildResolver.build(
            combatant: scaled,
            equipmentLoadout: sanitized,
            inventory: gear.inventory,
            unlockedTalents: request.unlockedTalents
        )
        let affixIDs = gear.inventory.flatMap { $0.affixes.map(\.id) }
        return PreparedPartyMember(build: build, loadout: loadout, affixIDs: affixIDs)
    }
}
