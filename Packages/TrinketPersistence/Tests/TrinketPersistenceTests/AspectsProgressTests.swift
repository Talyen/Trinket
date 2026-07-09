import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
import TrinketTestSupport

@Suite("AspectsProgress")
struct AspectsProgressTests {
    @Test func markFloorClearedAdvancesSequentiallyOnly() {
        var progress = PlayerAspectsState()
        #expect(progress.markFloorCleared(1, aspectID: AspectID.ironVein.rawValue))
        #expect(!progress.markFloorCleared(3, aspectID: AspectID.ironVein.rawValue))
        #expect(progress.highestClearedFloor(for: AspectID.ironVein.rawValue) == 1)
        #expect(progress.markFloorCleared(2, aspectID: AspectID.ironVein.rawValue))
        #expect(progress.highestClearedFloor(for: AspectID.ironVein.rawValue) == 2)
        #expect(!progress.markFloorCleared(2, aspectID: AspectID.ironVein.rawValue))
        #expect(progress.activeFloor(for: AspectID.ironVein.rawValue, floorCount: 10) == 3)
    }

    @Test func sanitizeDropsUnknownAspectsAndClampsFloors() {
        let dirty = PlayerAspectsState(
            highestClearedFloorByAspectID: [
                AspectID.ironVein.rawValue: 99,
                "missingAspect": 4,
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
        let pet = try #require(GameContent.pets.first { $0.id == "bear" })
        let goldBefore = save.roster.gold

        AspectCompletion.complete(
            floor: floor,
            hero: hero,
            pet: pet,
            battleEarnedGold: 3,
            save: &save
        )

        #expect(save.roster.gold == goldBefore + floor.rewards.gold + 3)
        #expect(save.aspects.highestClearedFloor(for: AspectID.ironVein.rawValue) == 1)
        #expect(save.aspects.isFloorStartable(2, aspectID: AspectID.ironVein.rawValue))
        #expect(!save.aspects.isFloorStartable(1, aspectID: AspectID.ironVein.rawValue))
    }

    @Test func floorCompletionGrantsBiasedItemAndIsIdempotent() throws {
        var save = PlayerSave.fresh
        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "bear" })

        var rng = SeededRandomNumberGenerator(seed: 7)
        let item = try #require(AspectCompletion.makeAspectFloorItem(for: floor, using: &rng))
        #expect(item.baseType.keywordAffinities.contains(.physical))

        AspectCompletion.complete(
            floor: floor,
            hero: hero,
            pet: pet,
            rewardItem: item,
            save: &save
        )
        let goldAfterFirst = save.roster.gold
        let itemCountAfterFirst = save.inventory.items.count

        AspectCompletion.complete(
            floor: floor,
            hero: hero,
            pet: pet,
            rewardItem: item,
            save: &save
        )

        #expect(save.roster.gold == goldAfterFirst)
        #expect(save.inventory.items.count == itemCountAfterFirst)
        #expect(save.aspects.highestClearedFloor(for: AspectID.ironVein.rawValue) == 1)
    }

    @Test func wardenCompletionGrantsBiasedItem() throws {
        var save = PlayerSave.fresh
        for floorIndex in 1 ... 9 {
            let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: floorIndex))
            let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
            let pet = try #require(GameContent.pets.first { $0.id == "bear" })
            AspectCompletion.complete(floor: floor, hero: hero, pet: pet, save: &save)
        }

        let warden = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 10))
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "bear" })
        let countBefore = save.inventory.items.count

        var rng = SeededRandomNumberGenerator(seed: 7)
        let item = try #require(AspectCompletion.makeAspectFloorItem(for: warden, using: &rng))
        AspectCompletion.complete(
            floor: warden,
            hero: hero,
            pet: pet,
            rewardItem: item,
            save: &save
        )

        #expect(save.inventory.items.count == countBefore + 1)
        #expect(item.baseType.keywordAffinities.contains(.physical))
        #expect(save.aspects.highestClearedFloor(for: AspectID.ironVein.rawValue) == 10)
    }

    @Test func unlockGatesFollowIronVeinProgress() throws {
        var progress = PlayerAspectsState()
        let cinder = try #require(GameContent.aspect(id: .cinderSpire))
        let rime = try #require(GameContent.aspect(id: .rimeVault))
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

    @Test func modesUnlockRequiresChapterOneComplete() throws {
        #expect(!ModesUnlock.isUnlocked(journey: .initial))
        let chapter1 = try #require(GameContent.chapters.first { $0.id == "chapter-1" })
        let stageIDs = Set(chapter1.stages.map(\.id))
        let unlockedJourney = JourneyProgressState(
            activeChapterID: "chapter-2",
            activeStageID: GameContent.chapters.first { $0.id == "chapter-2" }?.stages.first?.id,
            completedStageIDs: stageIDs,
            claimedRewardStageIDs: stageIDs,
            lastCompletedStageID: chapter1.stages.last?.id
        )
        #expect(ModesUnlock.isUnlocked(journey: unlockedJourney))
    }

    @Test func materialBiasMatchesAspectKeyword() throws {
        let burnFloor = try #require(GameContent.aspectFloor(aspectID: .cinderSpire, floor: 3))
        #expect(burnFloor.rewards.materialRewards.contains { $0.resource == .wood })
        let natureFloor = try #require(GameContent.aspectFloor(aspectID: .wildrootGrove, floor: 3))
        #expect(natureFloor.rewards.materialRewards.contains { $0.resource == .herbs })
    }
}
