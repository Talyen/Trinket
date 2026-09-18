import AVFoundation
import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketFeatureSupport

struct CinematicCastKey: Hashable {
    let actorID: String
    let abilityID: String
}

@MainActor
@Observable
final class BattleCinematicPlayer {
    var isEnabled: Bool = BattleFeatureFlags.ultimateCinematicAnimationsEnabled

    private var playersByCastKey: [CinematicCastKey: AVPlayer] = [:]
    private var observersByCastKey: [CinematicCastKey: CinematicPlaybackObservers] = [:]

    isolated deinit {
        releaseAll()
    }

    func warmLoadout(
        heroActorID: String?,
        heroUltimateID: String?,
        companionActorID: String?,
        companionUltimateID: String?,
    ) {
        guard isEnabled else { return }
        if let heroActorID, let heroUltimateID {
            warm(actorID: heroActorID, abilityID: heroUltimateID)
        }
        if let companionActorID, let companionUltimateID {
            warm(actorID: companionActorID, abilityID: companionUltimateID)
        }
    }

    func warm(actorID: String, abilityID: String) {
        guard let key = enabledKey(actorID: actorID, abilityID: abilityID) else { return }
        guard playersByCastKey[key] == nil else { return }
        guard let url = UltimateCinematicCatalog.videoURL(for: actorID, abilityID: abilityID) else { return }

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 2
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false
        applyVolume(effectsVolume: 0, to: player, actorID: actorID, abilityID: abilityID)
        playersByCastKey[key] = player
    }

    func player(for actorID: String, abilityID: String) -> AVPlayer? {
        guard let key = enabledKey(actorID: actorID, abilityID: abilityID) else { return nil }
        if let existing = playersByCastKey[key] {
            return existing
        }
        warm(actorID: actorID, abilityID: abilityID)
        return playersByCastKey[key]
    }

    func hasVideo(for actorID: String, abilityID: String) -> Bool {
        guard isEnabled else { return false }
        return UltimateCinematicCatalog.reference(for: actorID, abilityID: abilityID).videoName != nil
    }

    func isReady(for actorID: String, abilityID: String) -> Bool {
        guard let key = enabledKey(actorID: actorID, abilityID: abilityID) else { return false }
        guard let player = playersByCastKey[key],
              let item = player.currentItem else { return false }
        return item.status == .readyToPlay
    }

    func whenReady(actorID: String, abilityID: String) async -> Bool {
        guard enabledKey(actorID: actorID, abilityID: abilityID) != nil else { return false }
        warm(actorID: actorID, abilityID: abilityID)
        let key = CinematicCastKey(actorID: actorID, abilityID: abilityID)
        guard playersByCastKey[key]?.currentItem != nil else { return false }

        let clock = SuspendingClock()
        let deadline = clock.now.advanced(by: .seconds(8))
        while clock.now < deadline {
            if Task.isCancelled {
                return false
            }
            if let item = playersByCastKey[key]?.currentItem {
                switch item.status {
                case .readyToPlay:
                    return true
                case .failed:
                    return false
                case .unknown:
                    break
                @unknown default:
                    break
                }
            } else {
                return false
            }
            try? await clock.sleep(for: .milliseconds(40), tolerance: .milliseconds(20))
        }
        return isReady(for: actorID, abilityID: abilityID)
    }

    func play(
        actorID: String,
        abilityID: String,
        effectsVolume: Double,
        rate: Float = 1,
        onEnded: @escaping @MainActor () -> Void,
    ) {
        guard let key = enabledKey(actorID: actorID, abilityID: abilityID) else { return }
        guard let player = player(for: actorID, abilityID: abilityID) else { return }
        applyVolume(effectsVolume: effectsVolume, to: player, actorID: actorID, abilityID: abilityID)
        clearObservers(for: actorID, abilityID: abilityID)
        if let item = player.currentItem {
            observersByCastKey[key] = observe(item: item, actorID: actorID, abilityID: abilityID, onEnded: onEnded)
        }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
        player.rate = rate
    }

    func pause(actorID: String, abilityID: String) {
        clearObservers(for: actorID, abilityID: abilityID)
        playersByCastKey[CinematicCastKey(actorID: actorID, abilityID: abilityID)]?.pause()
    }

    func releaseAll() {
        for key in observersByCastKey.keys {
            clearObservers(for: key.actorID, abilityID: key.abilityID)
        }
        for player in playersByCastKey.values {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        playersByCastKey.removeAll()
    }

    /// Clamps to the 0...1 app-volume range shared with music/SFX volume math.
    /// `hasAudio == false` masters stay muted regardless of volume; the per-player
    /// clamp lives here because BattleFeature cannot import TrinketAppState.
    private func applyVolume(effectsVolume: Double, to player: AVPlayer, actorID: String, abilityID: String) {
        let reference = UltimateCinematicCatalog.reference(for: actorID, abilityID: abilityID)
        let clamped = max(0, min(effectsVolume, 1))
        if reference.hasAudio, clamped > 0 {
            player.isMuted = false
            player.volume = Float(clamped)
        } else {
            player.isMuted = true
            player.volume = 0
        }
    }

    private func clearObservers(for actorID: String, abilityID: String) {
        let key = CinematicCastKey(actorID: actorID, abilityID: abilityID)
        guard let observers = observersByCastKey.removeValue(forKey: key) else { return }
        NotificationCenter.default.removeObserver(observers.endObserver)
        NotificationCenter.default.removeObserver(observers.failureObserver)
    }

    private func enabledKey(actorID: String, abilityID: String) -> CinematicCastKey? {
        guard isEnabled else { return nil }
        return CinematicCastKey(actorID: actorID, abilityID: abilityID)
    }

    private func observe(
        item: AVPlayerItem,
        actorID: String,
        abilityID: String,
        onEnded: @escaping @MainActor () -> Void,
    ) -> CinematicPlaybackObservers {
        func makeObserver(for name: Notification.Name) -> NSObjectProtocol {
            NotificationCenter.default.addObserver(
                forName: name,
                object: item,
                queue: .main,
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.clearObservers(for: actorID, abilityID: abilityID)
                    onEnded()
                }
            }
        }
        return CinematicPlaybackObservers(
            endObserver: makeObserver(for: .AVPlayerItemDidPlayToEndTime),
            failureObserver: makeObserver(for: .AVPlayerItemFailedToPlayToEndTime),
        )
    }
}

private struct CinematicPlaybackObservers {
    let endObserver: NSObjectProtocol
    let failureObserver: NSObjectProtocol
}
