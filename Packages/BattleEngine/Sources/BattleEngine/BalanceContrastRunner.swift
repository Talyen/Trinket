import Foundation
import TrinketContent
import TrinketCore

public enum BalanceContrastRunner {
    public static func runAbilityContrasts(
        config: BalanceSweepConfig,
        policy: some PlayerPolicy,
        heroes: [Combatant],
        pets: [Combatant],
        enemies: [Enemy]
    ) -> [PairedContrastSummary] {
        BalanceAbilityContrastRunner.run(
            context: BalanceContrastContext(
                config: config,
                heroes: heroes,
                pets: pets,
                enemies: enemies
            ),
            policy: policy
        )
    }

    public static func runAffixContrasts(
        config: BalanceSweepConfig,
        policy: some PlayerPolicy,
        heroes: [Combatant],
        pets: [Combatant],
        enemies: [Enemy]
    ) -> [PairedContrastSummary] {
        BalanceAffixContrastRunner.run(
            context: BalanceContrastContext(
                config: config,
                heroes: heroes,
                pets: pets,
                enemies: enemies
            ),
            policy: policy
        )
    }
}
