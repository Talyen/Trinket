import Foundation
import TrinketCore

public extension CombatTraitTriggers {
    init(from decoder: Decoder) throws {
        let values = try DefaultingTriggerDecoder(decoder)
        let legacyAffix = try values.nested("affixReactions")

        try self.init(
            damage: DamageTriggers(from: values, legacyAffix: legacyAffix),
            attack: AttackTriggers(from: values, legacyAffix: legacyAffix),
            block: BlockTriggers(from: values, legacyAffix: legacyAffix),
            mitigation: MitigationTriggers(from: values, legacyAffix: legacyAffix),
            dot: DotTriggers(from: values, legacyAffix: legacyAffix),
            control: ControlTriggers(from: values, legacyAffix: legacyAffix),
            dodge: DodgeTriggers(from: values, legacyAffix: legacyAffix),
            mana: ManaTriggers(from: values, legacyAffix: legacyAffix),
            gold: GoldTriggers(from: values, legacyAffix: legacyAffix),
            healing: HealingTriggers(from: values, legacyAffix: legacyAffix),
            revival: RevivalTriggers(from: values, legacyAffix: legacyAffix),
            cleanse: CleanseTriggers(from: values, legacyAffix: legacyAffix),
            enemyTurn: EnemyTurnTriggers(from: values, legacyAffix: legacyAffix),
            onHit: OnHitTriggers(from: values, legacyAffix: legacyAffix)
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
