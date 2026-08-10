import AVFoundation
import Foundation
import Observation
import TrinketContent
import TrinketFeatureSupport

/// Key for a Hero/Companion-specific Ultimate cinematic. Same ability cast by a
/// different actor resolves to a distinct video (or none).
struct CinematicCastKey: Hashable {
    let actorID: String
    let abilityID: String
}

/// Session-scoped Ultimate cinematic player cache.
/// Keeps AVPlayers warm so cast transitions never hitch on cold load.
/// Video assets are optional; until they exist, callers use ability-art fallback.
@MainActor
@Observable
final class BattleCinematicPlayer {
    static let shared = BattleCinematicPlayer()

    private var playersByCastKey: [CinematicCastKey: AVPlayer] = [:]
    private var warmedCastKeys: Set<CinematicCastKey> = []
    private var endObserversByCastKey: [CinematicCastKey: NSObjectProtocol] = [:]
    private var failureObserversByCastKey: [CinematicCastKey: NSObjectProtocol] = [:]

    private init() {}

    func warmLoadout(
        heroActorID: String?,
        heroUltimateID: String?,
        companionActorID: String?,
        companionUltimateID: String?
    ) {
        if let heroActorID, let heroUltimateID {
            warm(actorID: heroActorID, abilityID: heroUltimateID)
        }
        if let companionActorID, let companionUltimateID {
            warm(actorID: companionActorID, abilityID: companionUltimateID)
        }
    }

    func warm(actorID: String, abilityID: String) {
        let key = CinematicCastKey(actorID: actorID, abilityID: abilityID)
        warmedCastKeys.insert(key)
        guard playersByCastKey[key] == nil else { return }
        guard let url = UltimateCinematicCatalog.videoURL(for: actorID, abilityID: abilityID) else { return }

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 2
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false
        applyVolume(effectsVolume: 0, to: player, actorID: actorID, abilityID: abilityID)
        playersByCastKey[key] = player
        // Do not preroll here — AVPlayer throws if status is not ReadyToPlay yet.
        // Creating the item is enough to start buffering; play() seeks when cast begins.
    }

    func player(for actorID: String, abilityID: String) -> AVPlayer? {
        let key = CinematicCastKey(actorID: actorID, abilityID: abilityID)
        if let existing = playersByCastKey[key] {
            return existing
        }
        warm(actorID: actorID, abilityID: abilityID)
        return playersByCastKey[key]
    }

    func hasVideo(for actorID: String, abilityID: String) -> Bool {
        UltimateCinematicCatalog.reference(for: actorID, abilityID: abilityID).videoName != nil
    }

    func isReady(for actorID: String, abilityID: String) -> Bool {
        let key = CinematicCastKey(actorID: actorID, abilityID: abilityID)
        guard let player = playersByCastKey[key],
              let item = player.currentItem else { return false }
        return item.status == .readyToPlay
    }

    /// Waits until the warmed item is `.readyToPlay`, or returns `false` on failure / missing asset.
    func whenReady(actorID: String, abilityID: String) async -> Bool {
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
        onEnded: @escaping @MainActor () -> Void
    ) {
        let key = CinematicCastKey(actorID: actorID, abilityID: abilityID)
        guard let player = player(for: actorID, abilityID: abilityID) else { return }
        applyVolume(effectsVolume: effectsVolume, to: player, actorID: actorID, abilityID: abilityID)
        clearEndObserver(for: actorID, abilityID: abilityID)
        if let item = player.currentItem {
            let endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.clearEndObserver(for: actorID, abilityID: abilityID)
                    onEnded()
                }
            }
            let failObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.clearEndObserver(for: actorID, abilityID: abilityID)
                    onEnded()
                }
            }
            endObserversByCastKey[key] = endObserver
            failureObserversByCastKey[key] = failObserver
        }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
    }

    func pause(actorID: String, abilityID: String) {
        clearEndObserver(for: actorID, abilityID: abilityID)
        playersByCastKey[CinematicCastKey(actorID: actorID, abilityID: abilityID)]?.pause()
    }

    func releaseAll() {
        let observerKeys = Set(endObserversByCastKey.keys).union(failureObserversByCastKey.keys)
        for key in observerKeys {
            clearEndObserver(for: key.actorID, abilityID: key.abilityID)
        }
        for player in playersByCastKey.values {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        playersByCastKey.removeAll()
        warmedCastKeys.removeAll()
    }

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

    private func clearEndObserver(for actorID: String, abilityID: String) {
        let key = CinematicCastKey(actorID: actorID, abilityID: abilityID)
        if let observer = endObserversByCastKey.removeValue(forKey: key) {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = failureObserversByCastKey.removeValue(forKey: key) {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
