import Testing
import TrinketContent
@testable import TrinketPersistence

struct CloudFractionalReplayTests {
    @Test(arguments: [false, true]) @MainActor
    func `fractional Gem corrections precede replay capacity limits and survive reload`(historical: Bool) throws {
        let cases = [
            (balance: Int.max, remainder: 0, delta: 1, fraction: -90, expectedBalance: Int.max, expectedRemainder: 10),
            (balance: 0, remainder: 99, delta: -1, fraction: 1, expectedBalance: 0, expectedRemainder: 0),
            (balance: 0, remainder: 99, delta: 0, fraction: 1, expectedBalance: 1, expectedRemainder: 0),
        ]
        for values in cases {
            var save = PlayerSave.testSeed
            save.homestead.resources[.gems] = values.balance
            save.homestead.rewardRemainders = HomesteadRewardRemainders(gems: values.remainder)
            let action = CloudEconomicAction.committed(
                materials: values.delta == 0 ? [:] : [.gems: values.delta], gemsRemainder: values.fraction,
            )
            try action.validate()
            if historical {
                let existing = save
                try action.replay(onto: &save, existing: existing, before: existing)
            } else {
                action.applyEffects(to: &save)
            }
            #expect(save.homestead.resources[.gems] == values.expectedBalance)
            #expect(save.homestead.rewardRemainders?.gems ?? 0 == values.expectedRemainder)

            let context = try PersistenceTestContext()
            let restored = try context.seedAndReload(save).currentSave
            #expect(restored.homestead.resources[.gems] == values.expectedBalance)
            #expect(restored.homestead.rewardRemainders?.gems ?? 0 == values.expectedRemainder)
        }
    }
}
