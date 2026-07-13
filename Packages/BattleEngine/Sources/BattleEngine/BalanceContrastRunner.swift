import Foundation
import TrinketContent
import TrinketCore

public enum BalanceContrastRunner {
    public static func runAbilityContrasts(
        config: BalanceSweepConfig,
        policy: some PlayerPolicy,
        heroes: [Combatant],
        companions: [Combatant],
        enemies: [Enemy]
    ) -> [PairedContrastSummary] {
        BalanceAbilityContrastRunner.run(
            context: BalanceContrastContext(
                config: config,
                heroes: heroes,
                companions: companions,
                enemies: enemies
            ),
            policy: policy
        )
    }

    public static func runAffixContrasts(
        config: BalanceSweepConfig,
        policy: some PlayerPolicy,
        heroes: [Combatant],
        companions: [Combatant],
        enemies: [Enemy]
    ) -> [PairedContrastSummary] {
        BalanceAffixContrastRunner.run(
            context: BalanceContrastContext(
                config: config,
                heroes: heroes,
                companions: companions,
                enemies: enemies
            ),
            policy: policy
        )
    }
}
