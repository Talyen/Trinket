import BattleEngine
import Foundation
import TrinketFeatureSupport

@MainActor
final class BattleArtworkPreparation {
    private var names: Set<String> = []
    private var generation = 0
    private let warmup: (CGFloat) async -> Void
    private let acquire: (Set<String>) async -> Void
    private let releasePins: (Set<String>) -> Void

    init(
        warmup: @escaping (CGFloat) async -> Void = { await BattlePresentationWarmup.prepareAndWait(displayScale: $0) },
        acquire: @escaping (Set<String>) async -> Void = { await PreparedArtworkCache.shared.prepareAndPin(names: Array($0)) },
        release: @escaping (Set<String>) -> Void = { PreparedArtworkCache.shared.releasePins(names: Array($0)) },
    ) {
        self.warmup = warmup
        self.acquire = acquire
        releasePins = release
    }

    static func artworkNames(for configuration: BattleRunConfiguration) -> Set<String> {
        let combatants = [configuration.hero.combatant, configuration.companion.combatant]
            + [configuration.enemy].compactMap(\.self)
        return Set(combatants.flatMap { combatant in
            let portrait = combatant.artReference.map { [$0.imageName, $0.thumbnailImageName].compactMap(\.self) } ?? []
            let abilities = combatant.abilityLoadout.abilities.flatMap { ability in
                ability.artReference.map { [$0.imageName, $0.thumbnailImageName].compactMap(\.self) } ?? []
            }
            return portrait + abilities
        })
    }

    func prepare(names desired: Set<String>, displayScale: CGFloat, warmLoadouts: () -> Void) async {
        generation &+= 1
        let request = generation
        await warmup(displayScale)
        guard !Task.isCancelled, request == generation else { return }
        warmLoadouts()
        let added = desired.subtracting(names)
        if !added.isEmpty {
            await acquire(added)
        }
        guard !Task.isCancelled, request == generation else {
            releasePins(added)
            return
        }
        releasePins(names.subtracting(desired))
        names = desired
    }

    func retain(names desired: Set<String>) {
        generation &+= 1
        releasePins(names.subtracting(desired))
        names.formIntersection(desired)
    }

    func release() {
        retain(names: [])
    }
}
