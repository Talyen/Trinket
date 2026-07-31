import BattleEngine
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

        public init(
            combatant: Combatant,
            progression: CombatantProgression,
            equipmentLoadout: EquipmentLoadout,
            modifiers: CombatModifierProfile
        ) {
            self.combatant = combatant
            self.progression = progression
            self.equipmentLoadout = equipmentLoadout
            self.modifiers = modifiers
        }
    }

    public let id = UUID()
    public let runKey: BattleRunKey?
    public let rngSeed: UInt64
    public let hero: PartyMember
    public let companion: PartyMember
    public let enemy: Combatant?
    public let enemyEncounterLevel: Int?
    public let enemyModifiers: CombatModifierProfile

    public init(
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64,
        hero: PartyMember,
        companion: PartyMember,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        enemyModifiers: CombatModifierProfile
    ) {
        self.runKey = runKey
        self.rngSeed = rngSeed
        self.hero = hero
        self.companion = companion
        self.enemy = enemy
        self.enemyEncounterLevel = enemyEncounterLevel
        self.enemyModifiers = enemyModifiers
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
