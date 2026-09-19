import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Registry of prepared battle runs keyed by `BattleRunKey`.
///
/// Owned by `PlaySession` and shared with `PlayBattleLaunch` (which registers
/// and prunes) and the completion path (which reads route/presentation).
/// Prepared runs remain until pruning, restart, or end; ending clears both
/// runtime resources and registrations together.
@MainActor
final class PlayBattleRunRegistry {
    private var battleRuns: [BattleRunKey: PlayBattleRunRegistration] = [:]

    func register(_ registration: PlayBattleRunRegistration) {
        battleRuns[registration.route.origin.runKey] = registration
    }

    func remove(_ runKey: BattleRunKey) {
        battleRuns.removeValue(forKey: runKey)
    }

    func keep(_ keys: Set<BattleRunKey>) {
        battleRuns = battleRuns.filter { keys.contains($0.key) }
    }

    func registration(for runKey: BattleRunKey?) -> PlayBattleRunRegistration? {
        guard let runKey else { return nil }
        return battleRuns[runKey]
    }

    func runKeys() -> Set<BattleRunKey> {
        Set(battleRuns.keys)
    }

    func origin(for runKey: BattleRunKey) -> PlayBattleOrigin? {
        battleRuns[runKey]?.route.origin
    }

    func route(for runKey: BattleRunKey?) -> PlayBattleRoute? {
        registration(for: runKey)?.route
    }

    func presentation(for runKey: BattleRunKey?) -> BattlePresentationContext? {
        registration(for: runKey)?.presentation
    }

    func universalModifiers(for runKey: BattleRunKey?) -> [AffixModifier] {
        registration(for: runKey)?.universalModifiers ?? []
    }

    func removeAll() {
        battleRuns.removeAll(keepingCapacity: true)
    }
}
