import AVFoundation
import Foundation
import os
import TrinketContent

@MainActor
final class MusicPlayer {
    private let isDisabled: Bool
    private let fadeDuration: TimeInterval
    private var currentPlayer: AVAudioPlayer?
    private var currentRequest: MusicPlaybackRequest?
    private var preparedPlayer: AVAudioPlayer?
    private var preparedRequest: MusicPlaybackRequest?
    private var fadeTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var inFlightRequest: MusicPlaybackRequest?
    private var pendingStartVolume: Float?
    private var resumePositions: [MusicResumeKey: TimeInterval] = [:]
    private var hasConfiguredSession = false
    private let logger = Logger(
        subsystem: AudioLogging.subsystem,
        category: "Audio",
    )

    init(isDisabled: Bool, fadeDuration: TimeInterval = 0.9) {
        self.isDisabled = isDisabled
        self.fadeDuration = fadeDuration
    }

    // Concurrency-Safety: isolated deinit runs on MainActor so cancelling the
    isolated deinit {
        fadeTask?.cancel()
        loadTask?.cancel()
    }

    var canPreviewVolume: Bool {
        currentPlayer != nil || preparedPlayer != nil || inFlightRequest != nil
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

    func prepare(_ request: MusicPlaybackRequest) {
        guard !isDisabled else { return }
        if currentRequest?.resumeKey == request.resumeKey {
            return
        }
        if preparedRequest?.resumeKey == request.resumeKey {
            return
        }
        if inFlightRequest?.resumeKey == request.resumeKey {
            return
        }
        enqueueLoad(request, startVolume: nil)
    }

    func setVolume(_ volume: Double) {
        guard !isDisabled else { return }
        let resolvedVolume = Float(max(0, min(volume, 1)))

        if let currentPlayer, let currentRequest {
            currentPlayer.volume = targetVolume(for: currentRequest, appVolume: resolvedVolume)
            cancelActiveFades()
            return
        }

        pendingStartVolume = resolvedVolume
        if resolvedVolume > 0, let preparedPlayer, let preparedRequest {
            startLoadedPlayer(
                preparedPlayer,
                request: preparedRequest,
                volume: resolvedVolume,
                shouldCrossfade: false,
            )
            clearPrepared()
        }
    }

    func stop() {
        cancelPendingLoad()
        clearPrepared()
        cancelActiveFades()
        saveCurrentPosition()
        currentPlayer?.stop()
        currentPlayer = nil
        currentRequest = nil
    }

    func cancelActiveFades() {
        fadeTask?.cancel()
        fadeTask = nil
    }

    func clearEncounterResumePositions() {
        resumePositions = resumePositions.filter { entry in
            entry.key.contextKind == .menu
        }
    }

    private func play(_ request: MusicPlaybackRequest, volume: Float) {
        if let currentPlayer,
           currentRequest?.resumeKey == request.resumeKey {
            currentPlayer.numberOfLoops = request.track.isLooping ? -1 : 0
            currentPlayer.volume = targetVolume(for: request, appVolume: volume)
            if !currentPlayer.isPlaying {
                currentPlayer.play()
            }
            return
        }

        if let preparedPlayer,
           preparedRequest?.resumeKey == request.resumeKey {
            startLoadedPlayer(
                preparedPlayer,
                request: request,
                volume: volume,
                shouldCrossfade: false,
            )
            clearPrepared()
            return
        }

        if inFlightRequest?.resumeKey == request.resumeKey {
            pendingStartVolume = volume
            return
        }

        saveCurrentPosition()
        enqueueLoad(request, startVolume: volume)
    }

    private func enqueueLoad(_ request: MusicPlaybackRequest, startVolume: Float?) {
        guard let url = resourceURL(for: request.track) else {
            logger.warning(
                "Missing music resource: \(request.track.resourceName, privacy: .public).\(request.track.fileExtension, privacy: .public)",
            )
            return
        }

        cancelPendingLoad()
        if preparedRequest?.resumeKey != request.resumeKey {
            clearPrepared()
        }

        loadGeneration += 1
        let generation = loadGeneration
        inFlightRequest = request
        pendingStartVolume = startVolume

        loadTask = Task { @MainActor [weak self] in
            let loaded = await Self.loadPlayer(url: url)
            self?.attachLoadedPlayer(loaded, request: request, generation: generation)
        }
    }

    private func attachLoadedPlayer(
        _ loaded: LoadedMusicPlayer?,
        request: MusicPlaybackRequest,
        generation: Int,
    ) {
        guard generation == loadGeneration else {
            loaded?.player.stop()
            return
        }

        loadTask = nil
        inFlightRequest = nil
        let startVolume = pendingStartVolume
        pendingStartVolume = nil

        guard let loaded else {
            logger.error(
                "Unable to load music resource \(request.track.resourceName, privacy: .public).\(request.track.fileExtension, privacy: .public)",
            )
            return
        }

        if currentRequest?.resumeKey == request.resumeKey, currentPlayer != nil {
            loaded.player.stop()
            if let startVolume, let currentPlayer, let currentRequest {
                currentPlayer.volume = targetVolume(for: currentRequest, appVolume: startVolume)
            }
            return
        }

        if let startVolume, startVolume > 0 {
            startLoadedPlayer(
                loaded.player,
                request: request,
                volume: startVolume,
                shouldCrossfade: currentPlayer != nil,
            )
            return
        }

        if currentPlayer != nil {
            loaded.player.stop()
            return
        }

        applyResumePosition(loaded.player, request: request)
        loaded.player.numberOfLoops = request.track.isLooping ? -1 : 0
        loaded.player.volume = 0
        preparedPlayer = loaded.player
        preparedRequest = request
    }

    private func startLoadedPlayer(
        _ player: AVAudioPlayer,
        request: MusicPlaybackRequest,
        volume: Float,
        shouldCrossfade: Bool,
    ) {
        configureSessionIfNeeded()
        applyResumePosition(player, request: request)
        player.numberOfLoops = request.track.isLooping ? -1 : 0
        let target = targetVolume(for: request, appVolume: volume)

        if shouldCrossfade, currentPlayer != nil {
            player.volume = 0
            player.play()
            crossfade(to: player, request: request, targetVolume: target)
            return
        }

        player.volume = target
        player.play()
        cancelActiveFades()
        currentPlayer = player
        currentRequest = request
    }

    private func fadeOutCurrent(preservingPosition: Bool) {
        guard currentPlayer != nil else { return }
        cancelPendingLoad()
        clearPrepared()

        if preservingPosition {
            saveCurrentPosition()
        }

        let oldPlayer = currentPlayer
        cancelActiveFades()
        currentPlayer = nil
        currentRequest = nil

        let duration = fadeDuration
        fadeTask = Task { @MainActor [weak self] in
            defer { oldPlayer?.stop() }
            await self?.ramp(oldPlayer: oldPlayer, newPlayer: nil, targetVolume: 0, duration: duration)
        }
    }

    private func crossfade(to newPlayer: AVAudioPlayer, request: MusicPlaybackRequest, targetVolume: Float) {
        let oldPlayer = currentPlayer
        cancelActiveFades()
        currentPlayer = newPlayer
        currentRequest = request

        let duration = fadeDuration
        fadeTask = Task { @MainActor [weak self] in
            defer { oldPlayer?.stop() }
            await self?.ramp(
                oldPlayer: oldPlayer,
                newPlayer: newPlayer,
                targetVolume: targetVolume,
                duration: duration,
            )
        }
    }

    private func ramp(
        oldPlayer: AVAudioPlayer?,
        newPlayer: AVAudioPlayer?,
        targetVolume: Float,
        duration: TimeInterval,
    ) async {
        let steps = 18
        let oldStartVolume = oldPlayer?.volume ?? 0
        let clock = SuspendingClock()
        let stepDuration = Duration.seconds(duration / Double(steps))
        let stepTolerance = Duration.milliseconds(20)

        for step in 1 ... steps {
            guard !Task.isCancelled else { return }
            let progress = Float(step) / Float(steps)
            oldPlayer?.volume = oldStartVolume * (1 - progress)
            newPlayer?.volume = targetVolume * progress
            try? await clock.sleep(for: stepDuration, tolerance: stepTolerance)
        }

        oldPlayer?.volume = 0
        newPlayer?.volume = targetVolume
    }

    private func cancelPendingLoad() {
        loadGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        inFlightRequest = nil
        pendingStartVolume = nil
    }

    private func clearPrepared() {
        if preparedPlayer !== currentPlayer {
            preparedPlayer?.stop()
        }
        preparedPlayer = nil
        preparedRequest = nil
    }

    private func applyResumePosition(_ player: AVAudioPlayer, request: MusicPlaybackRequest) {
        player.currentTime = request.shouldResume ? resumePositions[request.resumeKey, default: 0] : 0
    }

    private static func loadPlayer(url: URL) async -> LoadedMusicPlayer? {
        await Task.detached(priority: .utility) {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                return LoadedMusicPlayer(player: player)
            } catch {
                return nil
            }
        }.value
    }

    private func resourceURL(for track: TrinketContent.MusicTrack) -> URL? {
        AudioResourceLocator.url(
            resourceName: track.resourceName,
            fileExtension: track.fileExtension,
            subdirectory: "Music",
        )
    }

    private func saveCurrentPosition() {
        guard let currentRequest, let currentPlayer else { return }
        resumePositions[currentRequest.resumeKey] = currentPlayer.currentTime
    }

    private func targetVolume(for request: MusicPlaybackRequest, appVolume: Float) -> Float {
        min(appVolume * Float(max(0, request.track.volumeGain)), 1)
    }

    private func configureSessionIfNeeded() {
        AmbientAudioSession.configureIfNeeded(configured: &hasConfiguredSession, logger: logger)
    }
}

// Concurrency-Safety: `@unchecked Sendable` — AVAudioPlayer is not Sendable;
private final class LoadedMusicPlayer: @unchecked Sendable {
    let player: AVAudioPlayer

    init(player: AVAudioPlayer) {
        self.player = player
    }
}
