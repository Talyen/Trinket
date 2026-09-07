import Foundation
import TrinketCore

public extension CombatTraitTriggers {
    init(from decoder: Decoder) throws {
        let values = try DefaultingTriggerDecoder(decoder)
        try self.init(
            damage: DamageTriggers(from: values),
            attack: AttackTriggers(from: values),
            block: BlockTriggers(from: values),
            mitigation: MitigationTriggers(from: values),
            dot: DotTriggers(from: values),
            control: ControlTriggers(from: values),
            dodge: DodgeTriggers(from: values),
            mana: ManaTriggers(from: values),
            gold: GoldTriggers(from: values),
            healing: HealingTriggers(from: values),
            revival: RevivalTriggers(from: values),
            cleanse: CleanseTriggers(from: values),
            enemyTurn: EnemyTurnTriggers(from: values),
            onHit: OnHitTriggers(from: values),
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TriggerCodingKey.self)
        try fields.damage.encode(to: &container)
        try fields.attack.encode(to: &container)
        try fields.block.encode(to: &container)
        try fields.mitigation.encode(to: &container)
        try fields.dot.encode(to: &container)
        try fields.control.encode(to: &container)
        try fields.dodge.encode(to: &container)
        try fields.mana.encode(to: &container)
        try fields.gold.encode(to: &container)
        try fields.healing.encode(to: &container)
        try fields.revival.encode(to: &container)
        try fields.cleanse.encode(to: &container)
        try fields.enemyTurn.encode(to: &container)
        try fields.onHit.encode(to: &container)
    }
}
