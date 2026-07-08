import Foundation
@testable import TrinketPersistence

@MainActor
extension PlayerSaveStore {
    func setGoldForTests(_ gold: Int) {
        var updated = roster
        updated.gold = gold
        roster = updated
    }

    func grantGoldForTests(_ amount: Int) {
        var updated = roster
        updated.grantGold(amount)
        roster = updated
    }
}
