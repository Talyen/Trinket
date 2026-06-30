import SwiftUI

@Observable
final class BattleSession {
    var activeBattle: ActiveBattleConfiguration?
    var isPaused = false
    var preview: BattleMusicPreview?

    func end() {
        activeBattle = nil
        isPaused = false
        preview = nil
    }
}
