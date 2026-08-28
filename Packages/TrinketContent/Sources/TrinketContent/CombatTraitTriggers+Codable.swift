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
        try storage.value.damage.encode(to: &container)
        try storage.value.attack.encode(to: &container)
        try storage.value.block.encode(to: &container)
        try storage.value.mitigation.encode(to: &container)
        try storage.value.dot.encode(to: &container)
        try storage.value.control.encode(to: &container)
        try storage.value.dodge.encode(to: &container)
        try storage.value.mana.encode(to: &container)
        try storage.value.gold.encode(to: &container)
        try storage.value.healing.encode(to: &container)
        try storage.value.revival.encode(to: &container)
        try storage.value.cleanse.encode(to: &container)
        try storage.value.enemyTurn.encode(to: &container)
        try storage.value.onHit.encode(to: &container)
    }
}
