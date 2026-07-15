import AVFoundation
import Foundation
import os
import TrinketContent

/// Stable SFX catalog IDs curated in `SoundManifest/sfx.tsv`.
enum SFXID {
    static let uiTap = "ui_tap"
    static let uiConfirm = "ui_confirm"
    static let uiCancel = "ui_cancel"
    static let uiDecline = "ui_decline"
    static let uiDeny = "ui_deny"
    static let uiToggleOn = "ui_toggle_on"
    static let uiToggleOff = "ui_toggle_off"
    static let uiEquip = "ui_equip"
    static let uiUnequip = "ui_unequip"
    static let uiBuySell = "ui_buy_sell"
    static let abilityDraw = "ability_draw"
    static let hit = "hit"
    static let hitBurn = "hit_burn"
    static let hitFreeze = "hit_freeze"
    static let heal = "heal"
    static let buff = "buff"
    static let block = "block"
    static let controlFreeze = "control_freeze"
    static let controlStun = "control_stun"
    static let purge = "purge"
    static let deathsDoor = "deaths_door"
    static let victory = "victory"
    static let defeat = "defeat"
    static let mysteryEvent = "mystery_event"

    /// Battle clips are prepared before the battlefield becomes interactive so
    /// an impact frame never performs resource lookup or decoder setup.
    static let battlePrewarmIDs = [
        abilityDraw,
        hit,
        hitBurn,
        hitFreeze,
        heal,
        buff,
        block,
        controlFreeze,
        controlStun,
        purge,
        deathsDoor,
        victory,
        defeat
    ]
}

@MainActor
final class SFXPlayer {
    private let isDisabled: Bool
    private var hasConfiguredSession = false
    private let engine = AVAudioEngine()
    private var preparedVoicesByID: [String: [PreparedSFXVoice]] = [:]
    private var buffersByID: [String: AVAudioPCMBuffer] = [:]
    private var nextVoiceIndexByID: [String: Int] = [:]
    private let logger = Logger(
        subsystem: AudioLogging.subsystem,
        category: "Audio"
    )

    init(isDisabled: Bool) {
        self.isDisabled = isDisabled
    }

    func play(_ id: String, volume: Double) {
        guard !isDisabled else { return }
        guard volume > 0 else { return }
        guard let clip = SFXCatalog.clipsByID[id] else {
            logger.warning("Unknown SFX id: \(id, privacy: .public)")
            return
        }

        configureSessionIfNeeded()
        if preparedVoicesByID[id] == nil {
            warm([id])
        }
        guard startEngineIfNeeded(),
              let voices = preparedVoicesByID[id],
              !voices.isEmpty else { return }

        let voiceIndex = (nextVoiceIndexByID[id] ?? 0) % voices.count
        nextVoiceIndexByID[id] = (voiceIndex + 1) % voices.count
        let voice = voices[voiceIndex]
        voice.node.stop()
        voice.node.volume = min(Float(max(0, volume) * max(0, clip.volumeGain)), 1)
        voice.node.scheduleBuffer(voice.buffer)
        voice.node.play()
    }

    /// Prepares a small overlap pool. Battle uses two players per clip so rapid
    /// target staggers do not allocate or cut off the immediately preceding hit.
    func warm(_ ids: [String], concurrentPlayerCount: Int = 1) {
        guard !isDisabled else { return }
        let desiredCount = max(1, concurrentPlayerCount)
        let idsNeedingWork = ids.filter { id in
            (preparedVoicesByID[id]?.count ?? 0) < desiredCount
        }
        guard !idsNeedingWork.isEmpty else { return }

        configureSessionIfNeeded()

        for id in idsNeedingWork {
            guard let clip = SFXCatalog.clipsByID[id] else { continue }
            guard let buffer = preparedBuffer(for: clip) else { continue }
            var voices = preparedVoicesByID[id, default: []]
            while voices.count < desiredCount {
                let node = AVAudioPlayerNode()
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: buffer.format)
                voices.append(PreparedSFXVoice(node: node, buffer: buffer))
            }
            preparedVoicesByID[id] = voices
        }
        engine.prepare()
        _ = startEngineIfNeeded()
    }

    func stopAll() {
        for voices in preparedVoicesByID.values {
            for voice in voices {
                voice.node.stop()
            }
        }
    }

    private func preparedBuffer(for clip: SFXClip) -> AVAudioPCMBuffer? {
        if let buffer = buffersByID[clip.id] {
            return buffer
        }
        guard let url = resourceURL(for: clip) else {
            logger.warning(
                "Missing SFX resource: \(clip.resourceName, privacy: .public).\(clip.fileExtension, privacy: .public)"
            )
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            guard file.length > 0,
                  file.length <= AVAudioFramePosition(AVAudioFrameCount.max),
                  let buffer = AVAudioPCMBuffer(
                      pcmFormat: file.processingFormat,
                      frameCapacity: AVAudioFrameCount(file.length)
                  ) else { return nil }
            try file.read(into: buffer)
            buffersByID[clip.id] = buffer
            return buffer
        } catch {
            logger.error(
                "Unable to decode SFX resource \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func resourceURL(for clip: SFXClip) -> URL? {
        Bundle.main.url(forResource: clip.resourceName, withExtension: clip.fileExtension) ??
            Bundle.main.url(forResource: clip.resourceName, withExtension: clip.fileExtension, subdirectory: "SFX") ??
            Bundle.main.url(
                forResource: clip.resourceName,
                withExtension: clip.fileExtension,
                subdirectory: "Resources/SFX"
            )
    }

    private func configureSessionIfNeeded() {
        AmbientAudioSession.configureIfNeeded(configured: &hasConfiguredSession, logger: logger)
    }

    private func startEngineIfNeeded() -> Bool {
        guard !engine.isRunning else { return true }
        do {
            try engine.start()
            return true
        } catch {
            logger.error(
                "Unable to start SFX engine: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}

private struct PreparedSFXVoice {
    let node: AVAudioPlayerNode
    let buffer: AVAudioPCMBuffer
}
