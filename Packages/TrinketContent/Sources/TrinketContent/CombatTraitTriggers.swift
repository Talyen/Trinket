import Foundation
import TrinketCore

/// Trait and affix trigger knobs authored for combat builds.
///
/// Held indirectly through a copy-on-write box: the many typed fields make this a
/// multi-KB value type, so an inline layout would bloat every profile copy through
/// the recursive damage pipeline (and overflow debug worker-thread stacks).
///
/// The trigger surface is grouped into thematic sub-structs (`DamageTriggers`,
/// `BlockTriggers`, …) so each family has a small memberwise init and its own merge.
/// `@dynamicMemberLookup` forwards those families' fields so engine reads stay
/// `triggers.holyIgnoresBlock` without naming the family.
@dynamicMemberLookup
public struct CombatTraitTriggers: Codable, Sendable, Equatable, Hashable {
    /// The COW-boxed payload: one sub-struct per trigger family.
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

    // Concurrency-Safety: `@unchecked Sendable` — COW box is mutated only through
    // `ensureUnique()` while uniquely referenced; copies clone `Fields`.
    final class Storage: @unchecked Sendable {
        var fields: Fields
        init(_ fields: Fields) {
            self.fields = fields
        }
    }

    var storage: Storage

    mutating func ensureUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage(storage.fields)
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
            onHit: onHit
        ))
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage.fields == rhs.storage.fields
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage.fields)
    }

    // MARK: - Dynamic Member Lookup: Damage

    public subscript<T>(dynamicMember keyPath: KeyPath<DamageTriggers, T>) -> T {
        storage.fields.damage[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<DamageTriggers, T>) -> T {
        get { storage.fields.damage[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.damage[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: Attack

    public subscript<T>(dynamicMember keyPath: KeyPath<AttackTriggers, T>) -> T {
        storage.fields.attack[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<AttackTriggers, T>) -> T {
        get { storage.fields.attack[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.attack[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: Block

    public subscript<T>(dynamicMember keyPath: KeyPath<BlockTriggers, T>) -> T {
        storage.fields.block[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<BlockTriggers, T>) -> T {
        get { storage.fields.block[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.block[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: Mitigation

    public subscript<T>(dynamicMember keyPath: KeyPath<MitigationTriggers, T>) -> T {
        storage.fields.mitigation[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<MitigationTriggers, T>) -> T {
        get { storage.fields.mitigation[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.mitigation[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: DoT

    public subscript<T>(dynamicMember keyPath: KeyPath<DotTriggers, T>) -> T {
        storage.fields.dot[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<DotTriggers, T>) -> T {
        get { storage.fields.dot[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.dot[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: Control

    public subscript<T>(dynamicMember keyPath: KeyPath<ControlTriggers, T>) -> T {
        storage.fields.control[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<ControlTriggers, T>) -> T {
        get { storage.fields.control[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.control[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: Dodge

    public subscript<T>(dynamicMember keyPath: KeyPath<DodgeTriggers, T>) -> T {
        storage.fields.dodge[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<DodgeTriggers, T>) -> T {
        get { storage.fields.dodge[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.dodge[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: Mana

    public subscript<T>(dynamicMember keyPath: KeyPath<ManaTriggers, T>) -> T {
        storage.fields.mana[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<ManaTriggers, T>) -> T {
        get { storage.fields.mana[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.mana[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: Gold

    public subscript<T>(dynamicMember keyPath: KeyPath<GoldTriggers, T>) -> T {
        storage.fields.gold[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<GoldTriggers, T>) -> T {
        get { storage.fields.gold[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.gold[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: Healing

    public subscript<T>(dynamicMember keyPath: KeyPath<HealingTriggers, T>) -> T {
        storage.fields.healing[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<HealingTriggers, T>) -> T {
        get { storage.fields.healing[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.healing[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: Revival

    public subscript<T>(dynamicMember keyPath: KeyPath<RevivalTriggers, T>) -> T {
        storage.fields.revival[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<RevivalTriggers, T>) -> T {
        get { storage.fields.revival[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.revival[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: Cleanse

    public subscript<T>(dynamicMember keyPath: KeyPath<CleanseTriggers, T>) -> T {
        storage.fields.cleanse[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<CleanseTriggers, T>) -> T {
        get { storage.fields.cleanse[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.cleanse[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: Enemy Turn

    public subscript<T>(dynamicMember keyPath: KeyPath<EnemyTurnTriggers, T>) -> T {
        storage.fields.enemyTurn[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<EnemyTurnTriggers, T>) -> T {
        get { storage.fields.enemyTurn[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.enemyTurn[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Dynamic Member Lookup: On-Hit

    public subscript<T>(dynamicMember keyPath: KeyPath<OnHitTriggers, T>) -> T {
        storage.fields.onHit[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<OnHitTriggers, T>) -> T {
        get { storage.fields.onHit[keyPath: keyPath] }
        set {
            ensureUnique()
            storage.fields.onHit[keyPath: keyPath] = newValue
        }
    }
}

extension CombatTraitTriggers {
    /// Trigger field names whose values differ from family defaults.
    public var populatedFieldNames: [String] {
        Self.populatedNames(storage.fields.damage, defaults: DamageTriggers())
            + Self.populatedNames(storage.fields.attack, defaults: AttackTriggers())
            + Self.populatedNames(storage.fields.block, defaults: BlockTriggers())
            + Self.populatedNames(storage.fields.mitigation, defaults: MitigationTriggers())
            + Self.populatedNames(storage.fields.dot, defaults: DotTriggers())
            + Self.populatedNames(storage.fields.control, defaults: ControlTriggers())
            + Self.populatedNames(storage.fields.dodge, defaults: DodgeTriggers())
            + Self.populatedNames(storage.fields.mana, defaults: ManaTriggers())
            + Self.populatedNames(storage.fields.gold, defaults: GoldTriggers())
            + Self.populatedNames(storage.fields.healing, defaults: HealingTriggers())
            + Self.populatedNames(storage.fields.revival, defaults: RevivalTriggers())
            + Self.populatedNames(storage.fields.cleanse, defaults: CleanseTriggers())
            + Self.populatedNames(storage.fields.enemyTurn, defaults: EnemyTurnTriggers())
            + Self.populatedNames(storage.fields.onHit, defaults: OnHitTriggers())
    }

    private static func populatedNames<Family>(_ value: Family, defaults: Family) -> [String] {
        zip(Mirror(reflecting: value).children, Mirror(reflecting: defaults).children).compactMap { child, defaultChild in
            guard let label = child.label else { return nil }
            return String(describing: child.value) == String(describing: defaultChild.value) ? nil : label
        }
    }
}
