import SwiftUI

@Observable
final class BattleSession {
    var activeBattle: ActiveBattleConfiguration?
    var isPaused = false

    func end() {
        activeBattle = nil
        isPaused = false
    }
}
