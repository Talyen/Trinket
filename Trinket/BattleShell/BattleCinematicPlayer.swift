import AVFoundation
import Foundation
import Observation
import TrinketContent

/// Session-scoped Ultimate cinematic player cache.
/// Keeps AVPlayers warm so cast transitions never hitch on cold load.
/// Video assets are optional; until they exist, callers use ability-art fallback.
@MainActor
@Observable
final class BattleCinematicPlayer {
    static let shared = BattleCinematicPlayer()

    private var playersByAbilityID: [String: AVPlayer] = [:]
    private var warmedAbilityIDs: Set<String> = []
    private var endObserversByAbilityID: [String: NSObjectProtocol] = [:]
    private var failureObserversByAbilityID: [String: NSObjectProtocol] = [:]

    private init() {}

    func warmLoadout(heroUltimateID: String?, companionUltimateID: String?) {
        if let heroUltimateID {
            warm(abilityID: heroUltimateID)
        }
        if let companionUltimateID {
            warm(abilityID: companionUltimateID)
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
        applyVolume(effectsVolume: 0, to: player, abilityID: abilityID)
        playersByAbilityID[abilityID] = player
        // Do not preroll here — AVPlayer throws if status is not ReadyToPlay yet.
        // Creating the item is enough to start buffering; play() seeks when cast begins.
    }

    func player(for abilityID: String) -> AVPlayer? {
        if let existing = playersByAbilityID[abilityID] {
            return existing
        }
        warm(abilityID: abilityID)
        return playersByAbilityID[abilityID]
    }

    func hasVideo(for abilityID: String) -> Bool {
        UltimateCinematicCatalog.reference(for: abilityID).videoName != nil
    }

    func isReady(for abilityID: String) -> Bool {
        guard let player = playersByAbilityID[abilityID],
              let item = player.currentItem else { return false }
        return item.status == .readyToPlay
    }

    /// Waits until the warmed item is `.readyToPlay`, or returns `false` on failure / missing asset.
    func whenReady(abilityID: String) async -> Bool {
        warm(abilityID: abilityID)
        guard playersByAbilityID[abilityID]?.currentItem != nil else { return false }

        let clock = SuspendingClock()
        let deadline = clock.now.advanced(by: .seconds(8))
        while clock.now < deadline {
            if Task.isCancelled {
                return false
            }
            if let item = playersByAbilityID[abilityID]?.currentItem {
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
        return isReady(for: abilityID)
    }

    func play(
        abilityID: String,
        effectsVolume: Double,
        onEnded: @escaping @MainActor () -> Void
    ) {
        guard let player = player(for: abilityID) else { return }
        applyVolume(effectsVolume: effectsVolume, to: player, abilityID: abilityID)
        clearEndObserver(for: abilityID)
        if let item = player.currentItem {
            let endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.clearEndObserver(for: abilityID)
                    onEnded()
                }
            }
            let failObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.clearEndObserver(for: abilityID)
                    onEnded()
                }
            }
            endObserversByAbilityID[abilityID] = endObserver
            failureObserversByAbilityID[abilityID] = failObserver
        }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
    }

    func pause(abilityID: String) {
        clearEndObserver(for: abilityID)
        playersByAbilityID[abilityID]?.pause()
    }

    func releaseAll() {
        let observerIDs = Set(endObserversByAbilityID.keys).union(failureObserversByAbilityID.keys)
        for abilityID in observerIDs {
            clearEndObserver(for: abilityID)
        }
        for player in playersByAbilityID.values {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        playersByAbilityID.removeAll()
        warmedAbilityIDs.removeAll()
    }

    private func applyVolume(effectsVolume: Double, to player: AVPlayer, abilityID: String) {
        let reference = UltimateCinematicCatalog.reference(for: abilityID)
        let clamped = max(0, min(effectsVolume, 1))
        if reference.hasAudio, clamped > 0 {
            player.isMuted = false
            player.volume = Float(clamped)
        } else {
            player.isMuted = true
            player.volume = 0
        }
    }

    private func clearEndObserver(for abilityID: String) {
        if let observer = endObserversByAbilityID.removeValue(forKey: abilityID) {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = failureObserversByAbilityID.removeValue(forKey: abilityID) {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
