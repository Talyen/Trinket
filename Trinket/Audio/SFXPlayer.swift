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
    private var preparedPlayersByID: [String: [AVAudioPlayer]] = [:]
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
        if preparedPlayersByID[id] == nil {
            warm([id])
        }
        guard let players = preparedPlayersByID[id],
              let player = players.first(where: { !$0.isPlaying })
              ?? players.max(by: { $0.currentTime < $1.currentTime }) else { return }

        if player.isPlaying {
            player.stop()
        }
        player.currentTime = 0
        player.volume = min(Float(max(0, volume) * max(0, clip.volumeGain)), 1)
        player.play()
    }

    /// Prepares a small overlap pool. Battle uses two players per clip so rapid
    /// target staggers do not allocate or cut off the immediately preceding hit.
    func warm(_ ids: [String], concurrentPlayerCount: Int = 1) {
        guard !isDisabled else { return }
        configureSessionIfNeeded()
        let desiredCount = max(1, concurrentPlayerCount)

        for id in ids {
            guard let clip = SFXCatalog.clipsByID[id] else { continue }
            var players = preparedPlayersByID[id, default: []]
            while players.count < desiredCount {
                guard let player = makePreparedPlayer(for: clip) else { break }
                players.append(player)
            }
            preparedPlayersByID[id] = players
        }
    }

    func stopAll() {
        for players in preparedPlayersByID.values {
            for player in players {
                player.stop()
                player.currentTime = 0
            }
        }
    }

    private func makePreparedPlayer(for clip: SFXClip) -> AVAudioPlayer? {
        guard let url = resourceURL(for: clip) else {
            logger.warning(
                "Missing SFX resource: \(clip.resourceName, privacy: .public).\(clip.fileExtension, privacy: .public)"
            )
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            logger.error(
                "Unable to prepare SFX resource \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
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
}
