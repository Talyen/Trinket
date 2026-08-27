import Foundation
import TrinketContent
import TrinketCore

/// The immutable combat inputs required by a battle runtime.
///
/// Play owns encounter, reward, audio, and presentation context separately. The
/// runtime transports only the built combatants and deterministic engine inputs.
public struct BattleRunConfiguration: Identifiable {
    public struct PartyMember: Equatable {
        public let combatant: Combatant
        public let progression: CombatantProgression
        public let equipmentLoadout: EquipmentLoadout
        public let modifiers: CombatModifierProfile
        public let unlockedTalents: Set<String>
        /// Seed for the runtime's current health; `nil` starts at full.
        public let startingHealth: Int?
        /// Maximum health a fresh battle starts from. Excludes in-battle
        /// max-health growth (e.g. Vital Armor), which is battle-scoped.
        public var baselineMaxHealth: Int {
            CombatantMaxValues.maxHealth(for: combatant, modifiers: modifiers)
        }

        public init(
            combatant: Combatant,
            progression: CombatantProgression,
            equipmentLoadout: EquipmentLoadout,
            modifiers: CombatModifierProfile,
            unlockedTalents: Set<String> = [],
            startingHealth: Int? = nil
        ) {
            self.combatant = combatant
            self.progression = progression
            self.equipmentLoadout = equipmentLoadout
            self.modifiers = modifiers
            self.unlockedTalents = unlockedTalents
            self.startingHealth = startingHealth
        }
    }

    // EntropyCheck: allow - battle run identity is per-launch local, not seeded combat RNG.
    public let id = UUID()
    public let runKey: BattleRunKey?
    public let rngSeed: UInt64
    public let hero: PartyMember
    public let companion: PartyMember
    public let enemy: Combatant?
    public let enemyEncounterLevel: Int?
    public let enemyModifiers: CombatModifierProfile
    public let enemyFaction: EnemyFaction

    public init(
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64,
        hero: PartyMember,
        companion: PartyMember,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        enemyModifiers: CombatModifierProfile,
        enemyFaction: EnemyFaction = .mortal
    ) {
        self.runKey = runKey
        self.rngSeed = rngSeed
        self.hero = hero
        self.companion = companion
        self.enemy = enemy
        self.enemyEncounterLevel = enemyEncounterLevel
        self.enemyModifiers = enemyModifiers
        self.enemyFaction = enemyFaction
    }

    public func partyMember(for combatantID: String) -> PartyMember? {
        if combatantID == hero.combatant.id {
            return hero
        }
        if combatantID == companion.combatant.id {
            return companion
        }
        return nil
    }
}
