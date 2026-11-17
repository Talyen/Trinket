#if DEBUG
import TrinketAppState
import TrinketContent
import TrinketPersistence

@MainActor
struct BossCaptureFixture {
    let floor: SpireFloor
    let heroID: String
    let companionID: String

    static func fromArguments(_ arguments: [String]) throws -> Self? {
        guard let flag = arguments.firstIndex(of: "-boss-capture") else { return nil }
        guard arguments.contains("-development-unlocked"), arguments.count > flag + 3,
              let floor = GameContent.spireFloor(spireID: SpireID(arguments[flag + 1]), floor: 10),
              GameContent.enemy(matching: floor.enemyID)?.isBoss == true
        else {
            throw PlayerSavePersistenceError.invalidSave("Invalid boss capture checkpoint.")
        }
        return Self(floor: floor, heroID: arguments[flag + 2], companionID: arguments[flag + 3])
    }

    func start(in state: AppState) throws {
        guard state.playerSave.prepareBossCapture(heroID: heroID, companionID: companionID, floor: floor),
              state.play.spires.startBattle(for: floor) == nil
        else {
            throw PlayerSavePersistenceError.invalidSave("Couldn't start the boss capture encounter.")
        }
    }
}
#endif
