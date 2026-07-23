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
            gearKeywordBias: gearKeywordBias,
            gearGenerator: gearGenerator
        )
        let companionRequest = PartyPrepareRequest(
            progression: Self.progression(level: resolvedCompanionLevel),
            tier: tier,
            idPrefix: "sim-companion",
            gearOverride: companionGear,
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
            companionAffixIDs: companionPrepared.affixIDs
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

    /// Random legal loadout from a combatant's choice pools, respecting unlock level.
    public static func sampleLoadout(
        for combatant: Combatant,
        level: Int,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> AbilityLoadout {
        let progression = Self.progression(level: level)
        let choices = combatant.abilityChoices
        let basic = choices.basics.randomElement(using: &randomNumberGenerator)
        let skill = choices.skills.randomElement(using: &randomNumberGenerator)
        let ultimate = choices.ultimates.randomElement(using: &randomNumberGenerator)
        return AbilityLoadout(basic: basic, skill: skill, ultimate: ultimate)
            .unlocked(for: progression)
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
        var gearKeywordBias: Set<Keyword>?
        var gearGenerator: ThemedGearGenerator

        func with(idPrefix: String, gearOverride: GearOverride?) -> PartyPrepareRequest {
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
        let unlocked = loadout.unlocked(for: request.progression)
        let withLoadout = combatant.withAbilityLoadoutPreservingEmptyTiers(unlocked)
        let scaled = CombatantLevelScaler.scale(combatant: withLoadout, level: request.progression.level)

        if let gearOverride = request.gearOverride {
            let sanitized = gearOverride.loadout.sanitized(for: scaled, inventory: gearOverride.inventory)
            let build = CombatBuildResolver.build(
                combatant: scaled,
                equipmentLoadout: sanitized,
                inventory: gearOverride.inventory
            )
            let affixIDs = gearOverride.inventory.flatMap { $0.affixes.map(\.id) }
            return PreparedPartyMember(build: build, loadout: unlocked, affixIDs: affixIDs)
        }

        guard request.tier.includesGear,
              let rarity = request.tier.rarity,
              let affixCount = request.tier.fixedAffixCount
        else {
            let build = CombatBuildResolver.build(
                combatant: scaled,
                equipmentLoadout: EquipmentLoadout(),
                inventory: []
            )
            return PreparedPartyMember(build: build, loadout: unlocked, affixIDs: [])
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
            inventory: gear.inventory
        )
        let affixIDs = gear.inventory.flatMap { $0.affixes.map(\.id) }
        return PreparedPartyMember(build: build, loadout: unlocked, affixIDs: affixIDs)
    }
}
