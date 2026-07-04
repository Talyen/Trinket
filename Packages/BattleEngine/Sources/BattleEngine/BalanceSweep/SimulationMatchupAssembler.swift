import Foundation
import TrinketCore
import TrinketContent

public enum SimulationMatchupAssembler {
    public static func assemble(
        hero: Combatant,
        pet: Combatant,
        enemy: Enemy,
        tier: SimulationPowerTier,
        heroLoadout: AbilityLoadout,
        petLoadout: AbilityLoadout,
        heroGear: ThemedGearBuild? = nil,
        petGear: ThemedGearBuild? = nil,
        loadoutSampleIndex: Int = 0,
        seed: UInt64 = 0
    ) -> ConfiguredSimulationMatchup {
        let progression = CombatantProgression(level: tier.level, currentXP: 0, requiredXP: 100)

        let configuredHero = battleConfigured(hero, loadout: heroLoadout, progression: progression)
        let configuredPet = battleConfigured(pet, loadout: petLoadout, progression: progression)
        let scaledHero = CombatantLevelScaler.scale(combatant: configuredHero, level: tier.level)
        let scaledPet = CombatantLevelScaler.scale(combatant: configuredPet, level: tier.level)
        let scaledEnemy = CombatantLevelScaler.scale(enemy: enemy, level: tier.level)

        let heroBuild = buildCombatant(
            scaledHero,
            gear: heroGear
        )
        let petBuild = buildCombatant(
            scaledPet,
            gear: petGear
        )

        let context = SimulationBuildContext(
            tier: tier,
            heroLoadout: heroLoadout,
            petLoadout: petLoadout,
            loadoutSampleIndex: loadoutSampleIndex,
            seed: seed
        )

        return ConfiguredSimulationMatchup(
            hero: heroBuild.combatant,
            pet: petBuild.combatant,
            enemy: scaledEnemy,
            heroModifiers: heroBuild.modifiers,
            petModifiers: petBuild.modifiers,
            context: context,
            enemyID: enemy.id,
            isBoss: enemy.isBoss
        )
    }

    private static func battleConfigured(
        _ combatant: Combatant,
        loadout: AbilityLoadout,
        progression: CombatantProgression
    ) -> Combatant {
        let configured = combatant.withAbilityLoadout(loadout)
        let unlockedLoadout = configured.abilityLoadout.unlocked(for: progression)
        return configured.withAbilityLoadoutPreservingEmptyTiers(unlockedLoadout)
    }

    private static func buildCombatant(
        _ combatant: Combatant,
        gear: ThemedGearBuild?
    ) -> CombatBuild {
        guard let gear else {
            return CombatBuild(combatant: combatant, modifiers: .zero)
        }

        return CombatBuildResolver.build(
            combatant: combatant,
            equipmentLoadout: gear.loadout,
            inventory: gear.inventory
        )
    }
}
