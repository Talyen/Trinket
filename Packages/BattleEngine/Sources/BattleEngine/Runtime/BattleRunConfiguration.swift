import Foundation
import TrinketContent
import TrinketCore

public struct BattleRunConfiguration: Identifiable {
    public struct PartyMember: Equatable {
        public let combatant: Combatant
        public let progression: CombatantProgression
        public let equipmentLoadout: EquipmentLoadout
        public let modifiers: CombatModifierProfile
        public let unlockedTalents: Set<String>
        public let startingHealth: Int?

        public init(
            combatant: Combatant,
            progression: CombatantProgression,
            equipmentLoadout: EquipmentLoadout,
            modifiers: CombatModifierProfile,
            unlockedTalents: Set<String> = [],
            startingHealth: Int? = nil,
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
    private struct Inputs: Equatable {
        let runKey: BattleRunKey?
        let rngSeed: UInt64
        let hero: PartyMember
        let companion: PartyMember
        let enemy: Combatant?
        let enemyEncounterLevel: Int?
        let enemyModifiers: CombatModifierProfile
        let enemyFaction: EnemyFaction
    }

    private let inputs: Inputs

    public var runKey: BattleRunKey? {
        inputs.runKey
    }

    public var rngSeed: UInt64 {
        inputs.rngSeed
    }

    public var hero: PartyMember {
        inputs.hero
    }

    public var companion: PartyMember {
        inputs.companion
    }

    public var enemy: Combatant? {
        inputs.enemy
    }

    public var enemyEncounterLevel: Int? {
        inputs.enemyEncounterLevel
    }

    public var enemyModifiers: CombatModifierProfile {
        inputs.enemyModifiers
    }

    public var enemyFaction: EnemyFaction {
        inputs.enemyFaction
    }

    public init(
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64,
        hero: PartyMember,
        companion: PartyMember,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        enemyModifiers: CombatModifierProfile,
        enemyFaction: EnemyFaction = .mortal,
    ) {
        inputs = Inputs(
            runKey: runKey,
            rngSeed: rngSeed,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            enemyModifiers: enemyModifiers,
            enemyFaction: enemyFaction,
        )
    }

    /// Preparation can retain its identity and simulation only when all configuration
    /// inputs match. App-level reward and inventory projections have separate lifetimes.
    public func hasSameInputs(as other: Self) -> Bool {
        inputs == other.inputs
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
