#if DEBUG
import Foundation
import TrinketAppState
import TrinketContent
import TrinketPersistence

@MainActor
struct BossCaptureFixture {
    let floor: SpireFloor
    let heroID: String
    let companionID: String
    let lyricCapture: Bool

    static func fromArguments(_ arguments: [String]) throws -> Self? {
        guard let flag = arguments.firstIndex(of: "-boss-capture") else { return nil }
        guard arguments.contains("-development-unlocked"), arguments.count > flag + 3,
              let floor = GameContent.spireFloor(spireID: SpireID(arguments[flag + 1]), floor: 10),
              GameContent.enemy(matching: floor.enemyID)?.isBoss == true
        else {
            throw PlayerSavePersistenceError.invalidSave("Invalid boss capture checkpoint.")
        }
        return Self(
            floor: floor, heroID: arguments[flag + 2], companionID: arguments[flag + 3],
            lyricCapture: arguments.contains("-boss-lyric-capture"),
        )
    }

    func captureDefaults() -> UserDefaults? {
        guard lyricCapture, let defaults = UserDefaults(suiteName: "TrinketBossLyricCapture") else { return nil }
        defaults.set(0.85, forKey: "options.musicVolume")
        defaults.set(0.18, forKey: "options.effectsVolume")
        defaults.set(true, forKey: "options.bossLyricsEnabled")
        defaults.set(true, forKey: "options.rememberAutoBattlePreference")
        defaults.set(true, forKey: "options.autoBattleEnabled")
        return defaults
    }

    func start(in state: AppState) throws {
        guard state.playerSave.prepareBossCapture(heroID: heroID, companionID: companionID, floor: floor),
              state.play.spires.startBattle(for: floor) == nil
        else {
            throw PlayerSavePersistenceError.invalidSave("Couldn't start the boss capture encounter.")
        }
        if lyricCapture, !state.cueBossLyricsForCapture(enemyID: floor.enemyID) {
            throw PlayerSavePersistenceError.invalidSave("The boss capture track needs timed lyrics.")
        }
    }
}
#endif
