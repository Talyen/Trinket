import AVFoundation
import Foundation
import Observation

/// Session-scoped Ultimate cinematic player cache.
/// Keeps AVPlayers warm so cast transitions never hitch on cold load.
/// Video assets are optional; until they exist, callers use ability-art fallback.
@MainActor
@Observable
final class BattleCinematicPlayer {
    static let shared = BattleCinematicPlayer()

    private var playersByAbilityID: [String: AVPlayer] = [:]
    private var warmedAbilityIDs: Set<String> = []

    private init() {}

    func warmLoadout(heroUltimateID: String?, petUltimateID: String?) {
        if let heroUltimateID {
            warm(abilityID: heroUltimateID)
        }
        if let petUltimateID {
            warm(abilityID: petUltimateID)
        }
    }

    func warm(abilityID: String) {
        guard !abilityID.isEmpty else { return }
        warmedAbilityIDs.insert(abilityID)
        guard playersByAbilityID[abilityID] == nil else { return }
        guard let url = UltimateCinematicCatalog.videoURL(for: abilityID) else { return }

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 2
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false
        player.isMuted = true
        playersByAbilityID[abilityID] = player
        player.preroll(atRate: 1.0) { _ in }
    }

    func player(for abilityID: String) -> AVPlayer? {
        if let existing = playersByAbilityID[abilityID] {
            return existing
        }
        warm(abilityID: abilityID)
        return playersByAbilityID[abilityID]
    }

    func isReady(for abilityID: String) -> Bool {
        guard let player = playersByAbilityID[abilityID],
              let item = player.currentItem else { return false }
        return item.status == .readyToPlay
    }

    func play(abilityID: String) {
        guard let player = player(for: abilityID) else { return }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
    }

    func pause(abilityID: String) {
        playersByAbilityID[abilityID]?.pause()
    }

    func releaseAll() {
        for player in playersByAbilityID.values {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        playersByAbilityID.removeAll()
        warmedAbilityIDs.removeAll()
    }
}

/// Catalog bridge for Ultimate cinematic videos.
/// Returns nil until video assets are authored; battle uses ability-art fallback.
enum UltimateCinematicCatalog {
    struct Reference: Equatable, Sendable {
        let abilityID: String
        let videoName: String?
        let hasAudio: Bool
        /// Battle always presents cinematics in 9:16; sources may differ and are cropped.
        let displayAspectWidth: Int
        let displayAspectHeight: Int

        static func fallback(abilityID: String) -> Reference {
            Reference(
                abilityID: abilityID,
                videoName: nil,
                hasAudio: false,
                displayAspectWidth: 9,
                displayAspectHeight: 16
            )
        }
    }

    static func reference(for abilityID: String) -> Reference {
        // Placeholder until ArtManifest / generate pipeline adds ability_cinematic rows.
        .fallback(abilityID: abilityID)
    }

    static func videoURL(for abilityID: String) -> URL? {
        let reference = reference(for: abilityID)
        guard let videoName = reference.videoName else { return nil }
        return Bundle.main.url(forResource: videoName, withExtension: "mp4")
            ?? Bundle.main.url(forResource: videoName, withExtension: nil)
    }
}
