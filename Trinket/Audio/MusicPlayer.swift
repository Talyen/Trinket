import AVFoundation
import Foundation
import os
import TrinketContent
import TrinketPersistence

@MainActor
final class MusicPlayer {
    private let isDisabled: Bool
    private let fadeDuration: TimeInterval
    private var currentPlayer: AVAudioPlayer?
    private var currentRequest: MusicPlaybackRequest?
    private var fadeTask: Task<Void, Never>?
    private var resumePositions: [MusicResumeKey: TimeInterval] = [:]
    private var hasConfiguredSession = false
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "Audio"
    )

    init(isDisabled: Bool, fadeDuration: TimeInterval = 0.9) {
        self.isDisabled = isDisabled
        self.fadeDuration = fadeDuration
    }

    func update(route: MusicRoute, volume: Double) {
        guard !isDisabled else { return }

        let resolvedVolume = Float(max(0, min(volume, 1)))

        switch route {
        case let .silence(preservingPosition):
            fadeOutCurrent(preservingPosition: preservingPosition)
        case let .track(request):
            play(request, volume: resolvedVolume)
        }
    }

    func stop() {
        fadeTask?.cancel()
        saveCurrentPosition()
        currentPlayer?.stop()
        currentPlayer = nil
        currentRequest = nil
    }

    func clearEncounterResumePositions() {
        resumePositions = resumePositions.filter { entry in
            entry.key.contextKind == .menu
        }
    }

    static func route(
        selectedTab: AppTab,
        preview: BattleMusicPreview?,
        activeBattle: ActiveBattleConfiguration?,
        sceneIsActive: Bool,
        musicVolume: Double
    ) -> MusicRoute {
        guard sceneIsActive, musicVolume > 0 else {
            return .silence(preservingPosition: true)
        }

        guard selectedTab == .play else {
            return menuRoute()
        }

        if let activeBattle, let enemyID = activeBattle.enemy?.id {
            return encounterRoute(stageID: activeBattle.stageID, enemyID: enemyID)
        }

        if let preview {
            return encounterRoute(stageID: preview.stageID, enemyID: preview.enemyID)
        }

        return menuRoute()
    }

    private static func menuRoute() -> MusicRoute {
        guard let trackID = MusicCatalog.menuTrackIDs.first,
              let track = MusicCatalog.track(matching: trackID)
        else {
            return .silence(preservingPosition: false)
        }

        return .track(
            MusicPlaybackRequest(
                track: track,
                resumeKey: MusicResumeKey(contextKind: .menu, stageID: nil, enemyID: nil, trackID: track.id),
                shouldResume: true
            )
        )
    }

    private static func encounterRoute(stageID: String?, enemyID: String) -> MusicRoute {
        if let bossTrackID = MusicCatalog.bossTrackIDByEnemyID[enemyID],
           let bossTrack = MusicCatalog.track(matching: bossTrackID) {
            return .track(
                MusicPlaybackRequest(
                    track: bossTrack,
                    resumeKey: MusicResumeKey(contextKind: .boss, stageID: stageID, enemyID: enemyID, trackID: bossTrack.id),
                    shouldResume: true
                )
            )
        }

        guard let track = normalBattleTrack(stageID: stageID, enemyID: enemyID) else {
            return menuRoute()
        }

        return .track(
            MusicPlaybackRequest(
                track: track,
                resumeKey: MusicResumeKey(contextKind: .battle, stageID: stageID, enemyID: enemyID, trackID: track.id),
                shouldResume: true
            )
        )
    }

    private static func normalBattleTrack(stageID: String?, enemyID: String) -> MusicTrack? {
        guard !MusicCatalog.battleTrackIDs.isEmpty else { return nil }

        let seed = [stageID, enemyID].compactMap(\.self).joined(separator: ":")
        let index = stableIndex(for: seed, count: MusicCatalog.battleTrackIDs.count)
        let trackID = MusicCatalog.battleTrackIDs[index]
        return MusicCatalog.track(matching: trackID)
    }

    private static func stableIndex(for seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }

        var hash = UInt64(5381)
        for byte in seed.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return Int(hash % UInt64(count))
    }

    private func play(_ request: MusicPlaybackRequest, volume: Float) {
        configureSessionIfNeeded()

        if let currentPlayer,
           currentRequest?.resumeKey == request.resumeKey {
            currentPlayer.numberOfLoops = request.track.isLooping ? -1 : 0
            currentPlayer.volume = targetVolume(for: request, appVolume: volume)
            if !currentPlayer.isPlaying {
                currentPlayer.play()
            }
            return
        }

        saveCurrentPosition()

        guard let newPlayer = makePlayer(for: request) else { return }
        newPlayer.numberOfLoops = request.track.isLooping ? -1 : 0
        newPlayer.currentTime = request.shouldResume ? resumePositions[request.resumeKey, default: 0] : 0
        newPlayer.volume = 0
        newPlayer.prepareToPlay()
        newPlayer.play()

        crossfade(to: newPlayer, request: request, targetVolume: targetVolume(for: request, appVolume: volume))
    }

    private func fadeOutCurrent(preservingPosition: Bool) {
        guard currentPlayer != nil else { return }

        if preservingPosition {
            saveCurrentPosition()
        }

        let oldPlayer = currentPlayer
        fadeTask?.cancel()
        currentPlayer = nil
        currentRequest = nil

        fadeTask = Task { @MainActor in
            await ramp(oldPlayer: oldPlayer, newPlayer: nil, targetVolume: 0, duration: fadeDuration)
            oldPlayer?.stop()
        }
    }

    private func crossfade(to newPlayer: AVAudioPlayer, request: MusicPlaybackRequest, targetVolume: Float) {
        let oldPlayer = currentPlayer
        fadeTask?.cancel()
        currentPlayer = newPlayer
        currentRequest = request

        fadeTask = Task { @MainActor in
            await ramp(oldPlayer: oldPlayer, newPlayer: newPlayer, targetVolume: targetVolume, duration: fadeDuration)
            oldPlayer?.stop()
        }
    }

    private func ramp(
        oldPlayer: AVAudioPlayer?,
        newPlayer: AVAudioPlayer?,
        targetVolume: Float,
        duration: TimeInterval
    ) async {
        let steps = 18
        let oldStartVolume = oldPlayer?.volume ?? 0

        for step in 1 ... steps {
            guard !Task.isCancelled else { return }
            let progress = Float(step) / Float(steps)
            oldPlayer?.volume = oldStartVolume * (1 - progress)
            newPlayer?.volume = targetVolume * progress

            let delay = UInt64((duration / Double(steps)) * Double(1000000000))
            try? await Task.sleep(nanoseconds: delay)
        }

        oldPlayer?.volume = 0
        newPlayer?.volume = targetVolume
    }

    private func makePlayer(for request: MusicPlaybackRequest) -> AVAudioPlayer? {
        guard let url = resourceURL(for: request.track) else {
            logger.warning(
                "Missing music resource: \(request.track.resourceName, privacy: .public).\(request.track.fileExtension, privacy: .public)"
            )
            return nil
        }

        do {
            return try AVAudioPlayer(contentsOf: url)
        } catch {
            logger.error(
                "Unable to load music resource \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func resourceURL(for track: TrinketContent.MusicTrack) -> URL? {
        Bundle.main.url(forResource: track.resourceName, withExtension: track.fileExtension) ??
            Bundle.main.url(forResource: track.resourceName, withExtension: track.fileExtension, subdirectory: "Music") ??
            Bundle.main.url(forResource: track.resourceName, withExtension: track.fileExtension, subdirectory: "Resources/Music")
    }

    private func saveCurrentPosition() {
        guard let currentRequest, let currentPlayer else { return }
        resumePositions[currentRequest.resumeKey] = currentPlayer.currentTime
    }

    private func targetVolume(for request: MusicPlaybackRequest, appVolume: Float) -> Float {
        min(appVolume * Float(max(0, request.track.volumeGain)), 1)
    }

    private func configureSessionIfNeeded() {
        guard !hasConfiguredSession else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("Unable to configure audio session: \(error.localizedDescription)")
            #endif
        }
        hasConfiguredSession = true
    }
}
