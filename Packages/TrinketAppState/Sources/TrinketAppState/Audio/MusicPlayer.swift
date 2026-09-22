import Foundation

@MainActor
final class MusicPlayer {
    private struct Track {
        let voice: any MusicPlaybackVoice
        let request: MusicPlaybackRequest
        var canSavePosition = true
    }

    private struct Load {
        let id: UUID
        let request: MusicPlaybackRequest
        let task: Task<Void, Never>
        var startVolume: Float?
    }

    private enum PendingTrack {
        case idle
        case loading(Load)
        case prepared(Track)

        var request: MusicPlaybackRequest? {
            switch self {
            case .idle: nil
            case let .loading(load): load.request
            case let .prepared(track): track.request
            }
        }
    }

    private struct Fade {
        let id: UUID
        let outgoing: any MusicPlaybackVoice
        let task: Task<Void, Never>
    }

    private let isDisabled: Bool
    private let fadeDuration: TimeInterval
    private let backend: any MusicPlaybackBackend
    private var current: Track?
    private var pending: PendingTrack = .idle
    private var fade: Fade?
    private var resumePositions: [MusicResumeKey: TimeInterval] = [:]
    private static let maxResumePositions = 32

    init(
        isDisabled: Bool,
        fadeDuration: TimeInterval = 0.9,
        backend: any MusicPlaybackBackend = SystemMusicPlaybackBackend(),
    ) {
        self.isDisabled = isDisabled
        self.fadeDuration = fadeDuration
        self.backend = backend
    }

    // Concurrency-Safety: isolated teardown owns every voice and task on MainActor.
    isolated deinit {
        if case let .loading(load) = pending {
            load.task.cancel()
        }
        if case let .prepared(track) = pending {
            track.voice.stop()
        }
        fade?.task.cancel()
        fade?.outgoing.stop()
        current?.voice.stop()
    }

    var canPreviewVolume: Bool {
        current != nil || pending.request != nil
    }

    func update(route: MusicRoute, volume: Double, immediate: Bool = false) {
        guard !isDisabled else { return }
        switch route {
        case let .silence(preservingPosition):
            silence(preservingPosition: preservingPosition, immediate: immediate)
        case let .track(request):
            play(request, volume: AudioSupport.clampedVolume(volume))
        }
    }

    func prepare(_ request: MusicPlaybackRequest) {
        guard !isDisabled,
              current?.request.resumeKey != request.resumeKey,
              pending.request?.resumeKey != request.resumeKey else { return }
        enqueueLoad(request, startVolume: nil)
    }

    func setVolume(_ volume: Double) {
        guard !isDisabled else { return }
        let volume = AudioSupport.clampedVolume(volume)
        if case var .loading(load) = pending {
            load.startVolume = volume
            pending = .loading(load)
        }
        if let current {
            cancelActiveFades()
            current.voice.volume = targetVolume(for: current.request, appVolume: volume)
        } else if volume > 0, case let .prepared(track) = pending {
            pending = .idle
            activate(track, volume: volume, crossfade: false)
        }
    }

    func silenceImmediately(preservingPosition: Bool) {
        silence(preservingPosition: preservingPosition, immediate: true)
    }

    func cancelActiveFades() {
        let previous = fade
        fade = nil
        previous?.task.cancel()
        previous?.outgoing.stop()
    }

    func clearEncounterResumePositions() {
        if current?.request.resumeKey.contextKind != .menu {
            current?.canSavePosition = false
        }
        resumePositions = resumePositions.filter { $0.key.contextKind == .menu }
    }

    private func play(_ request: MusicPlaybackRequest, volume: Float) {
        if let current, current.request.resumeKey == request.resumeKey {
            clearPending()
            cancelActiveFades()
            configure(current.voice, request: request, volume: targetVolume(for: request, appVolume: volume))
            if !current.voice.isPlaying {
                current.voice.start()
            }
            return
        }
        if case let .prepared(track) = pending, track.request.resumeKey == request.resumeKey {
            pending = .idle
            activate(track, volume: volume, crossfade: false)
        } else if case var .loading(load) = pending, load.request.resumeKey == request.resumeKey {
            load.startVolume = volume
            pending = .loading(load)
        } else {
            enqueueLoad(request, startVolume: volume)
        }
    }

    private func enqueueLoad(_ request: MusicPlaybackRequest, startVolume: Float?) {
        clearPending()
        let id = UUID()
        let backend = backend
        let task = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            let voice = await backend.load(request.track)
            guard let self else {
                voice?.stop()
                return
            }
            attach(voice, loadID: id)
        }
        pending = .loading(Load(id: id, request: request, task: task, startVolume: startVolume))
    }

    private func attach(_ voice: (any MusicPlaybackVoice)?, loadID: UUID) {
        guard case let .loading(load) = pending, load.id == loadID else {
            voice?.stop()
            return
        }
        pending = .idle
        guard let voice else { return }
        let track = Track(voice: voice, request: load.request)
        if let volume = load.startVolume, volume > 0 {
            activate(track, volume: volume, crossfade: true)
        } else {
            configure(voice, request: load.request, volume: 0)
            pending = .prepared(track)
        }
    }

    private func activate(_ track: Track, volume: Float, crossfade: Bool) {
        backend.activateSession()
        saveCurrentPosition()
        cancelActiveFades()
        let outgoing = current?.voice
        current = track
        applyResumePosition(track)
        let target = targetVolume(for: track.request, appVolume: volume)
        let shouldFade = crossfade && outgoing != nil
        configure(track.voice, request: track.request, volume: shouldFade ? 0 : target)
        if !shouldFade {
            outgoing?.stop()
        }
        track.voice.start()
        if shouldFade, let outgoing {
            startFade(outgoing: outgoing, incoming: track.voice, target: target)
        }
    }

    private func silence(preservingPosition: Bool, immediate: Bool) {
        clearPending()
        if preservingPosition {
            saveCurrentPosition()
        }
        cancelActiveFades()
        let outgoing = current?.voice
        current = nil
        guard let outgoing else { return }
        if immediate {
            outgoing.stop()
        } else {
            startFade(outgoing: outgoing, incoming: nil, target: 0)
        }
    }

    private func startFade(outgoing: any MusicPlaybackVoice, incoming: (any MusicPlaybackVoice)?, target: Float) {
        let id = UUID()
        let backend = backend
        let duration = Duration.seconds(max(0, fadeDuration) / 18)
        let startingVolume = outgoing.volume
        let task = Task { @MainActor [weak self] in
            for step in 1 ... 18 {
                guard !Task.isCancelled else { return }
                let progress = Float(step) / 18
                outgoing.volume = startingVolume * (1 - progress)
                incoming?.volume = target * progress
                do {
                    try await backend.waitForFadeStep(duration)
                } catch {
                    break
                }
            }
            // Cancellation may arrive during the final suspension. Teardown owns
            // stopping the outgoing voice; an obsolete task must never touch gain.
            guard !Task.isCancelled, self?.fade?.id == id else { return }
            incoming?.volume = target
            self?.cancelActiveFades()
        }
        fade = Fade(id: id, outgoing: outgoing, task: task)
    }

    private func clearPending() {
        let previous = pending
        pending = .idle
        switch previous {
        case .idle: break
        case let .loading(load): load.task.cancel()
        case let .prepared(track): track.voice.stop()
        }
    }

    private func applyResumePosition(_ track: Track) {
        let saved = resumePositions[track.request.resumeKey, default: 0]
        track.voice.currentTime = max(0, min(saved, track.voice.duration - 0.05))
    }

    private func configure(_ voice: any MusicPlaybackVoice, request: MusicPlaybackRequest, volume: Float) {
        voice.numberOfLoops = request.track.isLooping ? -1 : 0
        voice.volume = volume
    }

    private func saveCurrentPosition() {
        guard let current, current.canSavePosition else { return }
        resumePositions[current.request.resumeKey] = current.voice.currentTime
        if resumePositions.count > Self.maxResumePositions,
           let key = resumePositions.keys.first(where: { $0.contextKind != .menu }) ?? resumePositions.keys.first {
            resumePositions.removeValue(forKey: key)
        }
    }

    private func targetVolume(for request: MusicPlaybackRequest, appVolume: Float) -> Float {
        AudioSupport.targetVolume(appVolume: appVolume, gain: request.track.volumeGain)
    }
}
