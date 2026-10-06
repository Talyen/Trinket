import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct CloudSaveMergeEconomyRegressionTests {
    @Test @MainActor func `shared upgrades charge once while distinct builds retain their costs through reload`() throws {
        let date = Date(timeIntervalSince1970: 2000000000)
        var base = PlayerSave.testSeed
        base.roster.gold = 100
        base.homestead = PlayerHomesteadState(
            resources: [.wood: 100, .herbs: 100, .food: 100, .gems: 100], nodeTiers: [:], lastProductionAt: date,
        )
        let well = try #require(GameContent.homesteadNode(matching: .wishingWell))
        let field = try #require(GameContent.homesteadNode(matching: .wheatField))
        let coop = try #require(GameContent.homesteadNode(matching: .chickenCoop))
        let garden = try #require(GameContent.homesteadNode(matching: .herbGarden))
        var first = base
        var second = base
        for definition in [well, field, coop] {
            guard case .success = HomesteadBuildMutation.apply(definition, targetTier: 1, at: date, to: &first, recordReceipt: { _ in })
            else {
                Issue.record("The first device should afford its buildings")
                return
            }
        }
        for definition in [well, field, garden] {
            guard case .success = HomesteadBuildMutation.apply(definition, targetTier: 1, at: date, to: &second, recordReceipt: { _ in })
            else {
                Issue.record("The second device should afford its buildings")
                return
            }
        }
        for preferIncoming in [true, false] {
            let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: preferIncoming)
            let context = try PersistenceTestContext()
            let reloaded = try context.seedAndReload(merged).currentSave
            let costs = [well, field, coop, garden].flatMap { $0.tier(1)?.cost ?? [] }
            for resource in HomesteadResource.allCases {
                let spent = costs.filter { $0.resource == resource }.reduce(0) { $0 + $1.quantity }
                #expect(reloaded.homestead.balance(for: resource, roster: reloaded.roster)
                    == base.homestead.balance(for: resource, roster: base.roster) - spent)
            }
            for definition in [well, field, coop, garden] {
                #expect(reloaded.homestead.tier(for: definition.id) == 1)
            }
        }
    }

    @Test @MainActor func `spent overlapping collections neither duplicate Gold nor restore pending credit after reload`() throws {
        let start = Date(timeIntervalSince1970: 2000000000)
        let firstDay = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        let secondDay = firstDay.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        var base = PlayerSave.testSeed
        base.roster.gold = 100
        base.homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.wishingWell: 1], lastProductionAt: start)
        var first = base
        var second = base
        #expect(first.homestead.collectProduction(at: firstDay, roster: &first.roster) == [ResourceAmount(.gold, 1)])
        #expect(second.homestead.collectProduction(at: secondDay, roster: &second.roster) == [ResourceAmount(.gold, 2)])
        let firstSpent = first.roster.spendGold(20)
        let secondSpent = second.roster.spendGold(10)
        #expect(firstSpent && secondSpent)
        for preferIncoming in [true, false] {
            let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: preferIncoming)
            let context = try PersistenceTestContext()
            var reloaded = try context.seedAndReload(merged).currentSave
            #expect(reloaded.roster.gold == 72)
            #expect(reloaded.homestead.lastProductionAt == secondDay)
            #expect(reloaded.homestead.collectProduction(at: secondDay, roster: &reloaded.roster).isEmpty)
            #expect(reloaded.roster.gold == 72)
        }
    }

    @Test(arguments: [false, true]) @MainActor
    func `overlapping Food collections preserve independent Herbs and Gold rewards through reload`(reverseBranches: Bool) throws {
        let start = Date(timeIntervalSince1970: 2000000000)
        let date = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        var base = PlayerSave.testSeed
        base.roster.gold = 0
        base.homestead = PlayerHomesteadState(
            resources: [:], nodeTiers: [.wheatField: 1], lastProductionAt: start,
        )
        var first = base
        var second = base
        #expect(first.grantMaterials([ResourceAmount(.herbs, 5)], at: date) == [ResourceAmount(.herbs, 5)])
        #expect(second.grantMaterials([ResourceAmount(.herbs, 7)], at: date) == [ResourceAmount(.herbs, 7)])
        #expect(first.grantGold(11, at: date) == 11)
        #expect(second.grantGold(13, at: date) == 13)
        #expect(first.homestead.collectProduction(at: date, roster: &first.roster) == [ResourceAmount(.food, 1)])
        #expect(second.homestead.collectProduction(at: date, roster: &second.roster) == [ResourceAmount(.food, 1)])

        let merged = CloudSaveMerge.merge(
            incoming: reverseBranches ? second : first, existing: reverseBranches ? first : second,
            base: base, preferIncoming: true,
        )
        let restored = try CloudSaveSnapshot(merged).restored()
        let context = try PersistenceTestContext()
        var reloaded = try context.seedAndReload(restored).currentSave
        #expect(reloaded.homestead.resources[.herbs] == 12)
        #expect(reloaded.roster.gold == 24)
        #expect(reloaded.homestead.resources[.food] == 1)
        #expect(reloaded.homestead.collectProduction(at: date, roster: &reloaded.roster).isEmpty)
    }

    @Test(arguments: [false, true]) @MainActor
    func `an earlier collection preserves later production through reload`(reverseBranches: Bool) throws {
        let start = Date(timeIntervalSince1970: 2000000000)
        let firstDay = start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        let secondDay = firstDay.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        var base = PlayerSave.testSeed
        base.homestead = PlayerHomesteadState(
            resources: [:], nodeTiers: [.wheatField: 1], lastProductionAt: start,
        )
        var collected = base
        #expect(collected.homestead.collectProduction(at: firstDay, roster: &collected.roster) == [ResourceAmount(.food, 1)])
        var stillPending = base
        stillPending.homestead.settleProduction(at: secondDay, roster: stillPending.roster)
        #expect(stillPending.homestead.pendingProduction[.food] == 2)

        let merged = CloudSaveMerge.merge(
            incoming: reverseBranches ? stillPending : collected, existing: reverseBranches ? collected : stillPending,
            base: base, preferIncoming: true,
        )
        let restored = try CloudSaveSnapshot(merged).restored()
        let context = try PersistenceTestContext()
        var reloaded = try context.seedAndReload(restored).currentSave
        #expect(reloaded.homestead.lastProductionAt == secondDay)
        #expect(reloaded.homestead.resources[.food] == 1)
        #expect(reloaded.homestead.pendingProduction[.food] == 1)
        #expect(reloaded.homestead.collectProduction(at: secondDay, roster: &reloaded.roster) == [ResourceAmount(.food, 1)])
        #expect(reloaded.homestead.resources[.food] == 2)
        #expect(reloaded.homestead.collectProduction(at: secondDay, roster: &reloaded.roster).isEmpty)
    }

    @Test(arguments: [false, true])
    func `a shared build preserves Food spent on another building`(reverseBranches: Bool) throws {
        let date = Date(timeIntervalSince1970: 2000000000)
        var base = PlayerSave.testSeed
        base.homestead.nodeTiers = [:]
        base.homestead.lastProductionAt = date
        let field = try #require(GameContent.homesteadNode(matching: .wheatField))
        let coop = try #require(GameContent.homesteadNode(matching: .chickenCoop))
        var first = base
        var second = base
        guard case .success = HomesteadBuildMutation.apply(field, targetTier: 1, at: date, to: &first, recordReceipt: { _ in }),
              case .success = HomesteadBuildMutation.apply(field, targetTier: 1, at: date, to: &second, recordReceipt: { _ in }),
              case .success = HomesteadBuildMutation.apply(coop, targetTier: 1, at: date, to: &first, recordReceipt: { _ in })
        else {
            Issue.record("Both devices should afford the Wheat Field and one should afford the Chicken Coop")
            return
        }
        #expect(second.homestead.resources[.food] == base.homestead.resources[.food])
        #expect(first.homestead.resources[.food] == 13)

        let merged = CloudSaveMerge.merge(
            incoming: reverseBranches ? second : first, existing: reverseBranches ? first : second,
            base: base, preferIncoming: true,
        )
        #expect(merged.homestead.resources[.food] == 13)
        #expect(merged.homestead.tier(for: .wheatField) == 1)
        #expect(merged.homestead.tier(for: .chickenCoop) == 1)
    }

    @Test(arguments: [false, true]) @MainActor
    func `shared salvage preserves unrelated Gold spending through reload`(reverseBranches: Bool) throws {
        let item = try #require(GameContent.sampleInventoryItems.first { ItemSalvage.isEligible($0) })
        let well = try #require(GameContent.homesteadNode(matching: .wishingWell))
        let date = Date(timeIntervalSince1970: 2000000000)
        var base = PlayerSave.testSeed
        base.roster.gold = 100
        base.inventory.items = [item]
        base.homestead = PlayerHomesteadState(resources: [.gems: 10], nodeTiers: [:], lastProductionAt: date)
        var first = base
        var second = base
        let firstSalvage = ItemSalvageApplier.salvage(itemID: item.id, save: &first, recordReceipt: { _ in })
        let secondSalvage = ItemSalvageApplier.salvage(itemID: item.id, save: &second, recordReceipt: { _ in })
        guard case let .success(yields) = firstSalvage,
              case .success = HomesteadBuildMutation.apply(well, targetTier: 1, at: date, to: &first, recordReceipt: { _ in })
        else {
            Issue.record("Salvage and the Wishing Well build should succeed")
            return
        }
        #expect(secondSalvage == firstSalvage)
        #expect(second.roster.gold == base.roster.gold)
        #expect(first.roster.gold == 95)
        #expect(CloudSaveMerge.hasDuplicateClaim(incoming: first, existing: second, base: base))

        let merged = CloudSaveMerge.merge(
            incoming: reverseBranches ? second : first, existing: reverseBranches ? first : second,
            base: base, preferIncoming: true,
        )
        let restored = try CloudSaveSnapshot(merged).restored()
        let context = try PersistenceTestContext()
        let reloaded = try context.seedAndReload(restored).currentSave
        #expect(reloaded.roster.gold == 95)
        #expect(reloaded.homestead.tier(for: .wishingWell) == 1)
        #expect(reloaded.inventory.item(matching: item.id) == nil)
        for yield in yields where yield.resource != .gems {
            #expect(reloaded.homestead.resources[yield.resource, default: 0] == yield.quantity)
        }
    }

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
        guard let field, case .success = HomesteadBuildMutation.apply(
            field,
            targetTier: 1,
            at: date,
            to: &collectedAndSpent,
            recordReceipt: { _ in },
        )
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
