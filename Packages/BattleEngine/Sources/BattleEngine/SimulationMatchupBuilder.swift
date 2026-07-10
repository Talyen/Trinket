import Foundation
import TrinketContent
import TrinketCore

/// Assembles leveled, loadout-selected, optionally geared matchups for balance sweeps.
public enum SimulationMatchupBuilder {
    public static func build(
        hero: Combatant,
        pet: Combatant,
        enemy: Enemy,
        tier: SimulationPowerTier,
        heroLoadout: AbilityLoadout,
        petLoadout: AbilityLoadout,
        seed: UInt64,
        loadoutSampleIndex: Int = 0,
        gearGenerator: ThemedGearGenerator = ThemedGearGenerator()
    ) -> ConfiguredSimulationMatchup {
        var rng = SeededRandomNumberGenerator(seed: seed)
        let progression = Self.progression(level: tier.level)

        let heroPrepared = preparePartyMember(
            hero,
            loadout: heroLoadout,
            progression: progression,
            tier: tier,
            idPrefix: "sim-hero",
            gearGenerator: gearGenerator,
            using: &rng
        )
        let petPrepared = preparePartyMember(
            pet,
            loadout: petLoadout,
            progression: progression,
            tier: tier,
            idPrefix: "sim-pet",
            gearGenerator: gearGenerator,
            using: &rng
        )

        let scaledEnemy = CombatantLevelScaler.scale(enemy: enemy, level: tier.level)
        let enemyBuild = CombatBuildResolver.build(enemy: enemy)

        let context = SimulationBuildContext(
            tier: tier,
            heroLoadout: heroPrepared.loadout,
            petLoadout: petPrepared.loadout,
            loadoutSampleIndex: loadoutSampleIndex,
            seed: seed,
            heroAffixIDs: heroPrepared.affixIDs,
            petAffixIDs: petPrepared.affixIDs
        )

        return ConfiguredSimulationMatchup(
            hero: heroPrepared.build.combatant,
            pet: petPrepared.build.combatant,
            enemy: scaledEnemy,
            heroModifiers: heroPrepared.build.modifiers,
            petModifiers: petPrepared.build.modifiers,
            enemyModifiers: enemyBuild.modifiers,
            context: context,
            enemyID: enemy.id,
            isBoss: enemy.isBoss || enemy.isElite
        )
    }

    /// Random legal loadout from a combatant's choice pools, respecting unlock level.
    public static func sampleLoadout<RNG: RandomNumberGenerator>(
        for combatant: Combatant,
        level: Int,
        using randomNumberGenerator: inout RNG
    ) -> AbilityLoadout {
        let progression = Self.progression(level: level)
        let choices = combatant.abilityChoices
        let basic = choices.basics.randomElement(using: &randomNumberGenerator)
        let skill = choices.skills.randomElement(using: &randomNumberGenerator)
        let ultimate = choices.ultimates.randomElement(using: &randomNumberGenerator)
        return AbilityLoadout(basic: basic, skill: skill, ultimate: ultimate)
            .unlocked(for: progression)
    }

    private static func progression(level: Int) -> CombatantProgression {
        CombatantProgression(
            level: level,
            currentXP: 0,
            requiredXP: CombatantProgression.requiredXP(forLevel: level)
        )
    }

    private struct PreparedPartyMember {
        var build: CombatBuild
        var loadout: AbilityLoadout
        var affixIDs: [String]
    }

    private static func preparePartyMember<RNG: RandomNumberGenerator>(
        _ combatant: Combatant,
        loadout: AbilityLoadout,
        progression: CombatantProgression,
        tier: SimulationPowerTier,
        idPrefix: String,
        gearGenerator: ThemedGearGenerator,
        using randomNumberGenerator: inout RNG
    ) -> PreparedPartyMember {
        let unlocked = loadout.unlocked(for: progression)
        let withLoadout = combatant.withAbilityLoadoutPreservingEmptyTiers(unlocked)
        let scaled = CombatantLevelScaler.scale(combatant: withLoadout, level: tier.level)

        guard tier.includesGear,
              let rarity = tier.rarity,
              let affixCount = tier.fixedAffixCount
        else {
            let build = CombatBuildResolver.build(
                combatant: scaled,
                equipmentLoadout: EquipmentLoadout(),
                inventory: []
            )
            return PreparedPartyMember(build: build, loadout: unlocked, affixIDs: [])
        }

        let buildKeywords = Set(scaled.abilities.flatMap(\.keywords))
        let gear = gearGenerator.generate(
            for: scaled,
            rarity: rarity,
            fixedAffixCount: affixCount,
            idPrefix: idPrefix,
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
