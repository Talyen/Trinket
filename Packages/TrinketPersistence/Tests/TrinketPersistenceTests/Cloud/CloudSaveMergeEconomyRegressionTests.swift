import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct CloudSaveMergeEconomyRegressionTests {
    @Test func `spending collected Gold does not hide a shared production claim`() {
        let start = Date(timeIntervalSince1970: 2000000000)
        let date = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        var base = PlayerSave.testSeed
        base.roster.gold = 100
        base.homestead = PlayerHomesteadState(
            resources: [:], nodeTiers: [.wishingWell: 1], lastProductionAt: start,
        )

        var collectedAndSpent = base
        let collected = collectedAndSpent.homestead.collectProduction(at: date, roster: &collectedAndSpent.roster)
        #expect(collected == [ResourceAmount(.gold, 1)])
        let spent = collectedAndSpent.roster.spendGold(20)
        #expect(spent)
        var stillPending = base
        stillPending.homestead.settleProduction(at: date, roster: stillPending.roster)
        #expect(stillPending.homestead.pendingProduction[.gold, default: 0] == 1)

        let merged = CloudSaveMerge.merge(
            incoming: collectedAndSpent, existing: stillPending, base: base, preferIncoming: true,
        )
        #expect(merged.roster.gold == 81)
        #expect(merged.homestead.pendingProduction[.gold, default: 0] == 0)
        var reopened = merged
        #expect(reopened.homestead.collectProduction(at: date, roster: &reopened.roster).isEmpty)
    }

    @Test func `collecting and spending on one device cannot restore pending production`() {
        let date = Date(timeIntervalSince1970: 100)
        var base = PlayerSave.testSeed
        base.homestead.resources[.wood] = 20
        base.homestead.resources[.herbs] = 5
        base.homestead.nodeTiers = [:]
        base.homestead.pendingProduction = [.wood: 10]
        base.homestead.lastProductionAt = date

        var collectedAndSpent = base
        let collected = collectedAndSpent.homestead.collectProduction(at: date, roster: &collectedAndSpent.roster)
        #expect(collected == [ResourceAmount(.wood, 10)])
        let field = GameContent.homesteadNode(matching: .wheatField)
        guard let field, case .success = HomesteadBuildMutation.apply(field, targetTier: 1, at: date, to: &collectedAndSpent)
        else {
            Issue.record("The collected Wood should fund a Wheat Field")
            return
        }

        let merged = CloudSaveMerge.merge(
            incoming: collectedAndSpent, existing: base, base: base, preferIncoming: true,
        )

        #expect(merged.homestead.resources[.wood] == 26)
        #expect(merged.homestead.pendingProduction[.wood, default: 0] == 0)
        var reopened = merged
        #expect(reopened.homestead.collectProduction(at: date, roster: &reopened.roster).isEmpty)
    }
}
