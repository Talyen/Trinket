import Foundation
import TrinketCore

@dynamicMemberLookup
public struct CombatTraitTriggers: Codable, Sendable, Equatable, Hashable {
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

    var storage: CopyOnWriteBox<Fields>

    mutating func ensureUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = CopyOnWriteBox(storage.value)
        }
    }

    public init() {
        storage = CopyOnWriteBox(Fields(
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
            onHit: OnHitTriggers()
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
        onHit: OnHitTriggers = OnHitTriggers()
    ) {
        storage = CopyOnWriteBox(Fields(
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
            onHit: onHit
        ))
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage.value == rhs.storage.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage.value)
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DamageTriggers, T>) -> T {
        storage.value.damage[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<DamageTriggers, T>) -> T {
        get { storage.value.damage[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.damage[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<AttackTriggers, T>) -> T {
        storage.value.attack[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<AttackTriggers, T>) -> T {
        get { storage.value.attack[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.attack[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<BlockTriggers, T>) -> T {
        storage.value.block[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<BlockTriggers, T>) -> T {
        get { storage.value.block[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.block[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<MitigationTriggers, T>) -> T {
        storage.value.mitigation[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<MitigationTriggers, T>) -> T {
        get { storage.value.mitigation[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.mitigation[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DotTriggers, T>) -> T {
        storage.value.dot[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<DotTriggers, T>) -> T {
        get { storage.value.dot[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.dot[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<ControlTriggers, T>) -> T {
        storage.value.control[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<ControlTriggers, T>) -> T {
        get { storage.value.control[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.control[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DodgeTriggers, T>) -> T {
        storage.value.dodge[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<DodgeTriggers, T>) -> T {
        get { storage.value.dodge[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.dodge[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<ManaTriggers, T>) -> T {
        storage.value.mana[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<ManaTriggers, T>) -> T {
        get { storage.value.mana[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.mana[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<GoldTriggers, T>) -> T {
        storage.value.gold[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<GoldTriggers, T>) -> T {
        get { storage.value.gold[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.gold[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<HealingTriggers, T>) -> T {
        storage.value.healing[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<HealingTriggers, T>) -> T {
        get { storage.value.healing[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.healing[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<RevivalTriggers, T>) -> T {
        storage.value.revival[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<RevivalTriggers, T>) -> T {
        get { storage.value.revival[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.revival[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<CleanseTriggers, T>) -> T {
        storage.value.cleanse[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<CleanseTriggers, T>) -> T {
        get { storage.value.cleanse[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.cleanse[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<EnemyTurnTriggers, T>) -> T {
        storage.value.enemyTurn[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<EnemyTurnTriggers, T>) -> T {
        get { storage.value.enemyTurn[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.enemyTurn[keyPath: keyPath] = newValue
        }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<OnHitTriggers, T>) -> T {
        storage.value.onHit[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<OnHitTriggers, T>) -> T {
        get { storage.value.onHit[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.value.onHit[keyPath: keyPath] = newValue
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
        storage.value.damage.populatedFieldNames(comparedTo: DamageTriggers())
            + storage.value.attack.populatedFieldNames(comparedTo: AttackTriggers())
            + storage.value.block.populatedFieldNames(comparedTo: BlockTriggers())
            + storage.value.mitigation.populatedFieldNames(comparedTo: MitigationTriggers())
            + storage.value.dot.populatedFieldNames(comparedTo: DotTriggers())
            + storage.value.control.populatedFieldNames(comparedTo: ControlTriggers())
            + storage.value.dodge.populatedFieldNames(comparedTo: DodgeTriggers())
            + storage.value.mana.populatedFieldNames(comparedTo: ManaTriggers())
            + storage.value.gold.populatedFieldNames(comparedTo: GoldTriggers())
            + storage.value.healing.populatedFieldNames(comparedTo: HealingTriggers())
            + storage.value.revival.populatedFieldNames(comparedTo: RevivalTriggers())
            + storage.value.cleanse.populatedFieldNames(comparedTo: CleanseTriggers())
            + storage.value.enemyTurn.populatedFieldNames(comparedTo: EnemyTurnTriggers())
            + storage.value.onHit.populatedFieldNames(comparedTo: OnHitTriggers())
    }
}
