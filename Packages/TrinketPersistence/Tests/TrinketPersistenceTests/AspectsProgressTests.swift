import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
import TrinketTestSupport

@Suite("AspectsProgress")
struct AspectsProgressTests {
    @Test func markFloorClearedAdvancesSequentiallyOnly() {
        var progress = PlayerAspectsState()
        let cleared1 = progress.markFloorCleared(1, aspectID: AspectID.ironVein.rawValue)
        let cleared3Early = progress.markFloorCleared(3, aspectID: AspectID.ironVein.rawValue)
        #expect(cleared1)
        #expect(!cleared3Early)
        #expect(progress.highestClearedFloor(for: AspectID.ironVein.rawValue) == 1)
        let cleared2 = progress.markFloorCleared(2, aspectID: AspectID.ironVein.rawValue)
        #expect(cleared2)
        #expect(progress.highestClearedFloor(for: AspectID.ironVein.rawValue) == 2)
        let cleared2Again = progress.markFloorCleared(2, aspectID: AspectID.ironVein.rawValue)
        #expect(!cleared2Again)
        #expect(progress.activeFloor(for: AspectID.ironVein.rawValue, floorCount: 10) == 3)
    }

    @Test func sanitizeDropsUnknownAspectsAndClampsFloors() {
        let dirty = PlayerAspectsState(
            highestClearedFloorByAspectID: [
                AspectID.ironVein.rawValue: 99,
                "missingAspect": 4
            ]
        )
        let sanitized = PlayerSaveSanitizer.sanitizeAspects(dirty)
        #expect(sanitized.highestClearedFloorByAspectID["missingAspect"] == nil)
        #expect(sanitized.highestClearedFloor(for: AspectID.ironVein.rawValue) == 10)
    }

    @Test @MainActor func aspectsProgressPersistsThroughStore() throws {
        let directory = try SaveTestSupport.makeTempDirectory(prefix: "aspects-progress")
        defer { SaveTestSupport.removeTempDirectory(directory) }

        let first = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        var progress = first.aspects
        progress.markFloorCleared(1, aspectID: AspectID.cinderSpire.rawValue)
        progress.markFloorCleared(2, aspectID: AspectID.cinderSpire.rawValue)
        progress.markFloorCleared(3, aspectID: AspectID.cinderSpire.rawValue)
        progress.markFloorCleared(4, aspectID: AspectID.cinderSpire.rawValue)
        first.aspects = progress

        let second = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        #expect(second.aspects.highestClearedFloor(for: AspectID.cinderSpire.rawValue) == 4)
    }

    @Test func aspectCompletionGrantsGoldAndProgress() throws {
        var save = PlayerSave.fresh
        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "bear" })
        let goldBefore = save.roster.gold
        let loot = AspectCompletion.resolveLoot(for: floor)

        AspectCompletion.complete(
            floor: floor,
            hero: hero,
            companion: companion,
            battleEarnedGold: 3,
            loot: loot,
            save: &save
        )

        #expect(save.roster.gold == goldBefore + loot.gold + 3)
        #expect(save.aspects.highestClearedFloor(for: AspectID.ironVein.rawValue) == 1)
        #expect(save.aspects.isFloorStartable(2, aspectID: AspectID.ironVein.rawValue))
        #expect(!save.aspects.isFloorStartable(1, aspectID: AspectID.ironVein.rawValue))
        #expect(loot.materials.count == 2)
        #expect(loot.item.rarity == .basic)
    }

    @Test func aspectCompletionFallbackItemIsDeterministic() throws {
        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "bear" })

        var first = PlayerSave.fresh
        AspectCompletion.complete(floor: floor, hero: hero, companion: companion, save: &first)
        let firstItem = try #require(first.inventory.items.last)

        var second = PlayerSave.fresh
        AspectCompletion.complete(floor: floor, hero: hero, companion: companion, save: &second)
        let secondItem = try #require(second.inventory.items.last)

        #expect(firstItem.id == secondItem.id)
        #expect(firstItem.baseType.id == secondItem.baseType.id)
        #expect(firstItem.baseType.keywordAffinities.contains(.physical))
    }

    @Test func floorCompletionGrantsBiasedItemAndIsIdempotent() throws {
        var save = PlayerSave.fresh
        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "bear" })

        var rng = SeededRandomNumberGenerator(seed: 7)
        let item = try #require(AspectCompletion.makeAspectFloorItem(for: floor, using: &rng))
        #expect(item.baseType.keywordAffinities.contains(.physical))

        AspectCompletion.complete(
            floor: floor,
            hero: hero,
            companion: companion,
            rewardItem: item,
            save: &save
        )
        let goldAfterFirst = save.roster.gold
        let itemCountAfterFirst = save.inventory.items.count

        AspectCompletion.complete(
            floor: floor,
            hero: hero,
            companion: companion,
            rewardItem: item,
            save: &save
        )

        #expect(save.roster.gold == goldAfterFirst)
        #expect(save.inventory.items.count == itemCountAfterFirst)
        #expect(save.aspects.highestClearedFloor(for: AspectID.ironVein.rawValue) == 1)
    }

    @Test func bossFloorCompletionGrantsAstralItem() throws {
        var save = PlayerSave.fresh
        for floorIndex in 1 ... 9 {
            let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: floorIndex))
            let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
            let companion = try #require(GameContent.companions.first { $0.id == "bear" })
            AspectCompletion.complete(floor: floor, hero: hero, companion: companion, save: &save)
        }

        let bossFloor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 10))
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "bear" })
        let countBefore = save.inventory.items.count
        let loot = AspectCompletion.resolveLoot(for: bossFloor)

        AspectCompletion.complete(
            floor: bossFloor,
            hero: hero,
            companion: companion,
            loot: loot,
            save: &save
        )

        #expect(save.inventory.items.count == countBefore + 1)
        #expect(loot.item.rarity == .astral)
        #expect(loot.item.baseType.keywordAffinities.contains(.physical))
        #expect(save.aspects.highestClearedFloor(for: AspectID.ironVein.rawValue) == 10)
    }

    @Test func unlockGatesFollowIronVeinProgress() throws {
        var progress = PlayerAspectsState()
        let ironVein = try #require(GameContent.aspect(id: .ironVein))
        let cinder = try #require(GameContent.aspect(id: .cinderSpire))
        let rime = try #require(GameContent.aspect(id: .rimeVault))
        #expect(AspectUnlock.isUnlocked(ironVein, progress: progress))
        #expect(!AspectUnlock.isUnlocked(cinder, progress: progress))
        for floor in 1 ... 5 {
            _ = progress.markFloorCleared(floor, aspectID: AspectID.ironVein.rawValue)
        }
        #expect(AspectUnlock.isUnlocked(cinder, progress: progress))
        #expect(!AspectUnlock.isUnlocked(rime, progress: progress))
        for floor in 6 ... 10 {
            _ = progress.markFloorCleared(floor, aspectID: AspectID.ironVein.rawValue)
        }
        #expect(AspectUnlock.isUnlocked(rime, progress: progress))
    }

    @Test func unlockAllClearsEveryAspectClimb() {
        var progress = PlayerAspectsState.freshStart
        progress.unlockAll()

        for aspect in GameContent.aspects {
            #expect(progress.highestClearedFloor(for: aspect.id.rawValue) == aspect.floorCount)
            #expect(AspectUnlock.isUnlocked(aspect, progress: progress))
        }
    }

    @Test func aspectLootAlwaysIncludesTwoMaterials() throws {
        let burnFloor = try #require(GameContent.aspectFloor(aspectID: .cinderSpire, floor: 3))
        let burnLoot = AspectCompletion.resolveLoot(for: burnFloor)
        #expect(burnLoot.materials.count == 2)
        let poisonFloor = try #require(GameContent.aspectFloor(aspectID: .serpentHollow, floor: 3))
        let poisonLoot = AspectCompletion.resolveLoot(for: poisonFloor)
        #expect(poisonLoot.materials.count == 2)
    }
}
