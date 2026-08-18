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
            onHit: OnHitTriggers(from: values)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TriggerCodingKey.self)
        try storage.fields.damage.encode(to: &container)
        try storage.fields.attack.encode(to: &container)
        try storage.fields.block.encode(to: &container)
        try storage.fields.mitigation.encode(to: &container)
        try storage.fields.dot.encode(to: &container)
        try storage.fields.control.encode(to: &container)
        try storage.fields.dodge.encode(to: &container)
        try storage.fields.mana.encode(to: &container)
        try storage.fields.gold.encode(to: &container)
        try storage.fields.healing.encode(to: &container)
        try storage.fields.revival.encode(to: &container)
        try storage.fields.cleanse.encode(to: &container)
        try storage.fields.enemyTurn.encode(to: &container)
        try storage.fields.onHit.encode(to: &container)
    }
}
