import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureSupport

@MainActor
final class BattleArtworkPreparation {
    private let pins: PreparedArtworkPinSet
    private var generation = 0
    private let warmup: (CGFloat) async -> Void

    init(
        warmup: @escaping (CGFloat) async -> Void = { await BattlePresentationWarmup.prepareAndWait(displayScale: $0) },
        pins: PreparedArtworkPinSet = PreparedArtworkPinSet(),
    ) {
        self.warmup = warmup
        self.pins = pins
    }

    static func artworkNames(for configuration: BattleRunConfiguration) -> Set<String> {
        var names: Set<String> = []
        func insert(_ imageName: String, _ thumbnail: String?) {
            names.insert(imageName)
            if let thumbnail {
                names.insert(thumbnail)
            }
        }
        func insertCombatant(_ combatant: Combatant?) {
            guard let combatant else { return }
            if let ref = combatant.artReference {
                insert(ref.imageName, ref.thumbnailImageName)
            }
            for ability in combatant.abilityLoadout.abilities {
                if let ref = ability.artReference {
                    insert(ref.imageName, ref.thumbnailImageName)
                }
            }
        }
        insertCombatant(configuration.hero.combatant)
        insertCombatant(configuration.companion.combatant)
        insertCombatant(configuration.enemy)
        // Consolation Prize can add any catalog card; decoding cannot delay its play.
        if configuration.hero.modifiers.triggers.blockedAttackFirstRandomCard
            || configuration.companion.modifiers.triggers.blockedAttackFirstRandomCard {
            for ability in AbilityCatalog.all {
                if let ref = ability.artReference {
                    insert(ref.imageName, ref.thumbnailImageName)
                }
            }
        }
        return names
    }

    func prepare(names desired: Set<String>, displayScale: CGFloat) async {
        generation &+= 1
        let request = generation
        await warmup(displayScale)
        guard !Task.isCancelled, request == generation else { return }
        await pins.prepare(names: Array(desired), isCurrent: { request == self.generation })
    }

    /// Synchronous pruning only. Acquisition happens in async `prepare`, so
    /// callers use this after adding/removing runs to release pins for runs
    /// that are no longer desired without pinning anything new.
    func releaseExtraneousPins(names desired: Set<String>) {
        generation &+= 1
        pins.retain(names: desired)
    }

    func release() {
        releaseExtraneousPins(names: [])
    }
}
