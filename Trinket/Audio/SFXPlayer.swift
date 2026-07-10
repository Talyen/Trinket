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
}

@MainActor
final class SFXPlayer {
    private let isDisabled: Bool
    private var hasConfiguredSession = false
    private var activePlayers: [AVAudioPlayer] = []
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.ryanmcintire.Trinket",
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
        pruneFinishedPlayers()

        guard let url = resourceURL(for: clip) else {
            logger.warning(
                "Missing SFX resource: \(clip.resourceName, privacy: .public).\(clip.fileExtension, privacy: .public)"
            )
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = min(Float(max(0, volume) * max(0, clip.volumeGain)), 1)
            player.prepareToPlay()
            player.play()
            activePlayers.append(player)
        } catch {
            logger.error(
                "Unable to load SFX resource \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func stopAll() {
        for player in activePlayers {
            player.stop()
        }
        activePlayers = []
    }

    private func pruneFinishedPlayers() {
        activePlayers.removeAll { !$0.isPlaying }
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
