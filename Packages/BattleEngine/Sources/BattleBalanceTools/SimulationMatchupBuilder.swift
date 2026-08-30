import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

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
        gearGenerator: ThemedGearGenerator = ThemedGearGenerator(),
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
            gearGenerator: gearGenerator,
        )
        let companionRequest = PartyPrepareRequest(
            progression: Self.progression(level: resolvedCompanionLevel),
            tier: tier,
            idPrefix: "sim-companion",
            gearOverride: companionGear,
            unlockedTalents: companionTalents,
            gearKeywordBias: gearKeywordBias,
            gearGenerator: gearGenerator,
        )

        let heroPrepared = preparePartyMember(
            hero,
            loadout: heroLoadout,
            request: heroRequest,
            using: &rng,
        )
        let companionPrepared = preparePartyMember(
            companion,
            loadout: companionLoadout,
            request: companionRequest,
            using: &rng,
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
            companionTalentIDs: companionTalents.sorted(),
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
            isBoss: enemy.isBoss,
        )
    }

    public static func sampleLoadout(
        for combatant: Combatant,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> AbilityLoadout {
        let choices = combatant.abilityChoices
        let basic = choices.basics.randomElement(using: &randomNumberGenerator)
        let skill = choices.skills.randomElement(using: &randomNumberGenerator)
        let ultimate = choices.ultimates.randomElement(using: &randomNumberGenerator)
        return AbilityLoadout(basic: basic, skill: skill, ultimate: ultimate)
    }

    public static let minimumPartyDamagingAbilities = 3

    public static func damagingAbilityCount(hero: AbilityLoadout, companion: AbilityLoadout) -> Int {
        (hero.abilities + companion.abilities).filter(\.dealsCombatDamage).count
    }

    public static func samplePartyLoadouts(
        hero: Combatant,
        companion: Combatant,
        minimumDamagingAbilities: Int = minimumPartyDamagingAbilities,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> (hero: AbilityLoadout, companion: AbilityLoadout) {
        var bestHero = sampleLoadout(for: hero, using: &randomNumberGenerator)
        var bestCompanion = sampleLoadout(for: companion, using: &randomNumberGenerator)
        var bestCount = damagingAbilityCount(hero: bestHero, companion: bestCompanion)
        if bestCount >= minimumDamagingAbilities {
            return (bestHero, bestCompanion)
        }
        for _ in 0 ..< 63 {
            let nextHero = sampleLoadout(for: hero, using: &randomNumberGenerator)
            let nextCompanion = sampleLoadout(for: companion, using: &randomNumberGenerator)
            let count = damagingAbilityCount(hero: nextHero, companion: nextCompanion)
            if count > bestCount {
                bestHero = nextHero
                bestCompanion = nextCompanion
                bestCount = count
            }
            if bestCount >= minimumDamagingAbilities {
                break
            }
        }
        return (bestHero, bestCompanion)
    }

    public static func generateAlignedGear(
        for combatant: Combatant,
        tier: SimulationPowerTier,
        keywordBias: Set<Keyword>,
        idPrefix: String,
        gearGenerator: ThemedGearGenerator = ThemedGearGenerator(),
        using randomNumberGenerator: inout some RandomNumberGenerator,
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
            using: &randomNumberGenerator,
        )
        return GearOverride(gear)
    }

    public static func generateStarterGear(
        for combatant: Combatant,
        loadout: AbilityLoadout,
        level: Int,
        idPrefix: String,
        gearKeywordBias: Set<Keyword>? = nil,
        gearGenerator: ThemedGearGenerator = ThemedGearGenerator(),
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> GearOverride? {
        let withLoadout = combatant.withAbilityLoadoutPreservingEmptyTiers(loadout)
        let scaled = CombatantLevelScaler.scale(combatant: withLoadout, level: level)
        let bias = gearKeywordBias ?? Set(scaled.abilities.flatMap(\.keywords))
        let build = gearGenerator.generateSinglePiece(
            for: scaled,
            rarity: .basic,
            fixedAffixCount: 1,
            idPrefix: idPrefix,
            keywordBias: bias,
            requireBuildAlignment: true,
            using: &randomNumberGenerator,
        )
        guard !build.inventory.isEmpty else { return nil }
        return GearOverride(build)
    }

    public static func generateStarterGearIfNeeded(
        for combatant: Combatant,
        loadout: AbilityLoadout,
        tier: SimulationPowerTier,
        level: Int? = nil,
        idPrefix: String,
        gearKeywordBias: Set<Keyword>? = nil,
        gearGenerator: ThemedGearGenerator = ThemedGearGenerator(),
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> GearOverride? {
        guard tier.usesStarterGear else { return nil }
        return generateStarterGear(
            for: combatant,
            loadout: loadout,
            level: level ?? tier.level,
            idPrefix: idPrefix,
            gearKeywordBias: gearKeywordBias,
            gearGenerator: gearGenerator,
            using: &randomNumberGenerator,
        )
    }

    public static func legalTalentKit(
        for combatantID: String,
        level: Int,
        pointCap: Int? = nil,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> Set<String> {
        let nodes = CombatantTalentCatalog.validNodeIDs(for: combatantID)
        let earned = CombatantProgression.at(level: level).totalTalentPoints
        let points = pointCap.map { min(earned, max(0, $0)) } ?? earned
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

    public static func minimalPrefix(for tree: TalentTree, throughRow row: Int) -> Set<String> {
        Set(tree.nodes.filter { $0.row < row }.map(\.id))
    }

    public static func progression(level: Int) -> CombatantProgression {
        CombatantProgression(
            level: level,
            currentXP: 0,
            requiredXP: CombatantProgression.requiredXP(forLevel: level),
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
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> PreparedPartyMember {
        let withLoadout = combatant.withAbilityLoadoutPreservingEmptyTiers(loadout)
        let scaled = CombatantLevelScaler.scale(combatant: withLoadout, level: request.progression.level)

        if let gearOverride = request.gearOverride {
            let sanitized = gearOverride.loadout.sanitized(for: scaled, inventory: gearOverride.inventory)
            let build = CombatBuildResolver.build(
                combatant: scaled,
                equipmentLoadout: sanitized,
                inventory: gearOverride.inventory,
                unlockedTalents: request.unlockedTalents,
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
                unlockedTalents: request.unlockedTalents,
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
            using: &randomNumberGenerator,
        )
        let sanitized = gear.loadout.sanitized(for: scaled, inventory: gear.inventory)
        let build = CombatBuildResolver.build(
            combatant: scaled,
            equipmentLoadout: sanitized,
            inventory: gear.inventory,
            unlockedTalents: request.unlockedTalents,
        )
        let affixIDs = gear.inventory.flatMap { $0.affixes.map(\.id) }
        return PreparedPartyMember(build: build, loadout: loadout, affixIDs: affixIDs)
    }
}
