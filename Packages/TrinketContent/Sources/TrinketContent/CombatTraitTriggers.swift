import Foundation
import TrinketCore

/// Concurrency-Safety: Private storage holds Sendable fields and is uniquely owned before every mutation.
@dynamicMemberLookup
public struct CombatTraitTriggers: Codable, @unchecked Sendable, Equatable, Hashable {
    struct Fields: Equatable, Hashable, Sendable {
        var damage: DamageTriggers
        var attack: AttackTriggers
        var block: BlockTriggers
        var mitigation: MitigationTriggers
        var dot: DotTriggers
        var control: ControlTriggers
        var dodge: DodgeTriggers
        var mana: ManaTriggers
        var gold: GoldTriggers
        var healing: HealingTriggers
        var revival: RevivalTriggers
        var cleanse: CleanseTriggers
        var enemyTurn: EnemyTurnTriggers
        var onHit: OnHitTriggers
    }

    private final class Storage {
        var value: Fields

        init(_ value: Fields) {
            self.value = value
        }
    }

    private var storage: Storage

    var fields: Fields {
        get { storage.value }
        _modify {
            if !isKnownUniquelyReferenced(&storage) {
                storage = Storage(storage.value)
            }
            yield &storage.value
        }
    }

    public init() {
        storage = Storage(Fields(
            damage: DamageTriggers(),
            attack: AttackTriggers(),
            block: BlockTriggers(),
            mitigation: MitigationTriggers(),
            dot: DotTriggers(),
            control: ControlTriggers(),
            dodge: DodgeTriggers(),
            mana: ManaTriggers(),
            gold: GoldTriggers(),
            healing: HealingTriggers(),
            revival: RevivalTriggers(),
            cleanse: CleanseTriggers(),
            enemyTurn: EnemyTurnTriggers(),
            onHit: OnHitTriggers(),
        ))
    }

    public init(
        damage: DamageTriggers = DamageTriggers(),
        attack: AttackTriggers = AttackTriggers(),
        block: BlockTriggers = BlockTriggers(),
        mitigation: MitigationTriggers = MitigationTriggers(),
        dot: DotTriggers = DotTriggers(),
        control: ControlTriggers = ControlTriggers(),
        dodge: DodgeTriggers = DodgeTriggers(),
        mana: ManaTriggers = ManaTriggers(),
        gold: GoldTriggers = GoldTriggers(),
        healing: HealingTriggers = HealingTriggers(),
        revival: RevivalTriggers = RevivalTriggers(),
        cleanse: CleanseTriggers = CleanseTriggers(),
        enemyTurn: EnemyTurnTriggers = EnemyTurnTriggers(),
        onHit: OnHitTriggers = OnHitTriggers(),
    ) {
        storage = Storage(Fields(
            damage: damage,
            attack: attack,
            block: block,
            mitigation: mitigation,
            dot: dot,
            control: control,
            dodge: dodge,
            mana: mana,
            gold: gold,
            healing: healing,
            revival: revival,
            cleanse: cleanse,
            enemyTurn: enemyTurn,
            onHit: onHit,
        ))
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.fields == rhs.fields
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(fields)
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DamageTriggers, T>) -> T {
        fields.damage[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<DamageTriggers, T>) -> T {
        get { fields.damage[keyPath: keyPath] }
        set {
            fields.damage[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<AttackTriggers, T>) -> T {
        fields.attack[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<AttackTriggers, T>) -> T {
        get { fields.attack[keyPath: keyPath] }
        set {
            fields.attack[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<BlockTriggers, T>) -> T {
        fields.block[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<BlockTriggers, T>) -> T {
        get { fields.block[keyPath: keyPath] }
        set {
            fields.block[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<MitigationTriggers, T>) -> T {
        fields.mitigation[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<MitigationTriggers, T>) -> T {
        get { fields.mitigation[keyPath: keyPath] }
        set {
            fields.mitigation[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DotTriggers, T>) -> T {
        fields.dot[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<DotTriggers, T>) -> T {
        get { fields.dot[keyPath: keyPath] }
        set {
            fields.dot[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<ControlTriggers, T>) -> T {
        fields.control[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<ControlTriggers, T>) -> T {
        get { fields.control[keyPath: keyPath] }
        set {
            fields.control[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DodgeTriggers, T>) -> T {
        fields.dodge[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<DodgeTriggers, T>) -> T {
        get { fields.dodge[keyPath: keyPath] }
        set {
            fields.dodge[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<ManaTriggers, T>) -> T {
        fields.mana[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<ManaTriggers, T>) -> T {
        get { fields.mana[keyPath: keyPath] }
        set {
            fields.mana[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<GoldTriggers, T>) -> T {
        fields.gold[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<GoldTriggers, T>) -> T {
        get { fields.gold[keyPath: keyPath] }
        set {
            fields.gold[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<HealingTriggers, T>) -> T {
        fields.healing[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<HealingTriggers, T>) -> T {
        get { fields.healing[keyPath: keyPath] }
        set {
            fields.healing[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<RevivalTriggers, T>) -> T {
        fields.revival[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<RevivalTriggers, T>) -> T {
        get { fields.revival[keyPath: keyPath] }
        set {
            fields.revival[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<CleanseTriggers, T>) -> T {
        fields.cleanse[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<CleanseTriggers, T>) -> T {
        get { fields.cleanse[keyPath: keyPath] }
        set {
            fields.cleanse[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<EnemyTurnTriggers, T>) -> T {
        fields.enemyTurn[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<EnemyTurnTriggers, T>) -> T {
        get { fields.enemyTurn[keyPath: keyPath] }
        set {
            fields.enemyTurn[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<OnHitTriggers, T>) -> T {
        fields.onHit[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<OnHitTriggers, T>) -> T {
        get { fields.onHit[keyPath: keyPath] }
        set {
            fields.onHit[keyPath: keyPath] = newValue
        }
    }
}

public extension CombatTraitTriggers {
    static var allFieldNames: [String] {
        DamageTriggers.fieldNames
            + AttackTriggers.fieldNames
            + BlockTriggers.fieldNames
            + MitigationTriggers.fieldNames
            + DotTriggers.fieldNames
            + ControlTriggers.fieldNames
            + DodgeTriggers.fieldNames
            + ManaTriggers.fieldNames
            + GoldTriggers.fieldNames
            + HealingTriggers.fieldNames
            + RevivalTriggers.fieldNames
            + CleanseTriggers.fieldNames
            + EnemyTurnTriggers.fieldNames
            + OnHitTriggers.fieldNames
    }

    var populatedFieldNames: [String] {
        fields.damage.populatedFieldNames(comparedTo: DamageTriggers())
            + fields.attack.populatedFieldNames(comparedTo: AttackTriggers())
            + fields.block.populatedFieldNames(comparedTo: BlockTriggers())
            + fields.mitigation.populatedFieldNames(comparedTo: MitigationTriggers())
            + fields.dot.populatedFieldNames(comparedTo: DotTriggers())
            + fields.control.populatedFieldNames(comparedTo: ControlTriggers())
            + fields.dodge.populatedFieldNames(comparedTo: DodgeTriggers())
            + fields.mana.populatedFieldNames(comparedTo: ManaTriggers())
            + fields.gold.populatedFieldNames(comparedTo: GoldTriggers())
            + fields.healing.populatedFieldNames(comparedTo: HealingTriggers())
            + fields.revival.populatedFieldNames(comparedTo: RevivalTriggers())
            + fields.cleanse.populatedFieldNames(comparedTo: CleanseTriggers())
            + fields.enemyTurn.populatedFieldNames(comparedTo: EnemyTurnTriggers())
            + fields.onHit.populatedFieldNames(comparedTo: OnHitTriggers())
    }
}
