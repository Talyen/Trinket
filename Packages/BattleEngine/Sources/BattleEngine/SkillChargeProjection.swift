import Foundation
import TrinketContent
import TrinketCore

/// Presentation projection for the Skill-only bottom-up art charge wipe.
///
/// Non-`nil` only when the combatant's **next** cast will resolve to a Skill
/// (cadence + mana fallback). Basics and ultimates never produce a projection.
public struct SkillChargeProjection: Hashable, Sendable {
    public let ability: Ability
    /// Elapsed fraction of the current action interval (`0...1`).
    public let progress: Double

    public init(ability: Ability, progress: Double) {
        self.ability = ability
        self.progress = min(1, max(0, progress))
    }
}
