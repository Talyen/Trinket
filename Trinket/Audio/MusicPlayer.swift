import AVFoundation
import Foundation
import os
import TrinketContent

private enum AudioLogging {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.ryanmcintire.Trinket"
}

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
        subsystem: AudioLogging.subsystem,
        category: "Audio"
    )

    init(isDisabled: Bool, fadeDuration: TimeInterval = 0.9) {
        self.isDisabled = isDisabled
        self.fadeDuration = fadeDuration
    }

    deinit {
        fadeTask?.cancel()
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

    func trimMemoryFootprint() {
        clearEncounterResumePositions()
    }

    func clearEncounterResumePositions() {
        resumePositions = resumePositions.filter { entry in
            entry.key.contextKind == .menu
        }
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
        cancelActiveFades()
        currentPlayer = nil
        currentRequest = nil

        let duration = fadeDuration
        fadeTask = Task { @MainActor [weak self] in
            await self?.ramp(oldPlayer: oldPlayer, newPlayer: nil, targetVolume: 0, duration: duration)
            oldPlayer?.stop()
        }
    }

    private func crossfade(to newPlayer: AVAudioPlayer, request: MusicPlaybackRequest, targetVolume: Float) {
        let oldPlayer = currentPlayer
        cancelActiveFades()
        currentPlayer = newPlayer
        currentRequest = request

        let duration = fadeDuration
        fadeTask = Task { @MainActor [weak self] in
            await self?.ramp(
                oldPlayer: oldPlayer,
                newPlayer: newPlayer,
                targetVolume: targetVolume,
                duration: duration
            )
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
            logger.error(
                "Unable to configure audio session: \(error.localizedDescription, privacy: .public)"
            )
        }
        hasConfiguredSession = true
    }
}
