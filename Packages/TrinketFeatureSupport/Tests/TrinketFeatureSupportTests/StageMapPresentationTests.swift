import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureAdapters
import TrinketPersistence
@testable import TrinketFeatureSupport

struct StageMapPresentationTests {
    @Test(arguments: [RewardModifier.trinket, .unique])
    func `exhausted contract bonuses display the same gold fallback that pays`(modifier: RewardModifier) throws {
        var save = PlayerSave.testSeed
        save.inventory = PlayerInventoryState(items: GameContent.trinketItems + GameContent.uniqueItems)
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        let offer = ContractOffer(id: "exhausted", difficulty: .standard, enemyID: enemy.id, rewardModifier: modifier)
        let rows = StageSelectRowPresentation<ContractOffer>.contractRows(offers: [offer], inventory: save.inventory)
        let caption = try #require(rows.first?.modifiers.first)
        #expect(caption.id == RewardModifier.gold.rawValue)
        let goldOffer = ContractOffer(id: offer.id, difficulty: offer.difficulty, enemyID: offer.enemyID, rewardModifier: .gold)
        #expect(ContractsCompletion.resolveLoot(for: offer, encounterLevel: 10, save: save)
            == ContractsCompletion.resolveLoot(for: goldOffer, encounterLevel: 10, save: save))
        #expect(!ContractsCompletion.eligibleModifiers(in: save.inventory).contains(modifier))
    }

    @Test func `stage select rows omit completed stages`() {
        let chapter = GameContent.chapters[0]
        var progress = JourneyProgressState.initial
        progress.complete(chapter.stages[0], in: GameContent.chapters)

        let rows = StageSelectRowPresentation<Stage>.stageRows(
            for: chapter,
            progress: progress,
            worldSeed: 1,
        )

        #expect(!(rows.map(\.item.id).contains(chapter.stages[0].id)))
        #expect(rows.contains { $0.item.id == progress.activeStageID && $0.isActive })
    }
}

struct VoyageMapPresentationTests {
    @Test func `voyage rows omit cleared nodes and keep the next node active`() {
        let offer = VoyageOffer(id: "voyage", chapterID: "chapter-1", difficulty: .easy, seed: 1)
        var cleared = VoyageNode(id: "cleared", type: .battle, enemyID: "slime", modifierIDs: [], recruitEventID: nil)
        cleared.isCleared = true
        let next = VoyageNode(id: "next", type: .battle, enemyID: "goblin", modifierIDs: [], recruitEventID: nil)
        let boss = VoyageNode(id: "boss", type: .boss, enemyID: "the_blight_treant", modifierIDs: [], recruitEventID: nil)
        let run = VoyageRun(offer: offer, nodes: [cleared, next, boss])

        let rows = StageSelectRowPresentation<VoyageNode>.voyageNodes(run, inventory: .init(items: []))

        #expect(rows.map(\.item.id) == [next.id, boss.id])
        #expect(rows.first?.isActive == true)
        #expect(rows.last?.isActive == false)
    }

    @Test func `voyage rows only make combat nodes interactive`() {
        let offer = VoyageOffer(id: "voyage", chapterID: "chapter-1", difficulty: .easy, seed: 1)
        let battle = VoyageNode(id: "battle", type: .battle, enemyID: "goblin", modifierIDs: [], recruitEventID: nil)
        let shop = VoyageNode(id: "shop", type: .shop, enemyID: nil, modifierIDs: [], recruitEventID: nil)
        let mystery = VoyageNode(id: "mystery", type: .mystery, enemyID: nil, modifierIDs: [], recruitEventID: nil)
        let boss = VoyageNode(id: "boss", type: .boss, enemyID: "the_blight_treant", modifierIDs: [], recruitEventID: nil)
        let run = VoyageRun(offer: offer, nodes: [battle, shop, mystery, boss])

        let rows = StageSelectRowPresentation<VoyageNode>.voyageNodes(run, inventory: .init(items: []))
        #expect(rows.count == 4)
        #expect(rows[0].isArtworkInteractive == true)
        #expect(rows[0].allowsCompactInspection == true)
        #expect(rows[1].isArtworkInteractive == false)
        #expect(rows[1].allowsCompactInspection == false)
        #expect(rows[2].isArtworkInteractive == false)
        #expect(rows[2].allowsCompactInspection == false)
        #expect(rows[3].isArtworkInteractive == true)
        #expect(rows[3].allowsCompactInspection == true)
    }

    @Test func `shop discount modifier presentation uses reduced gold prices and gold keyword style`() throws {
        let modifier = try #require(GameContent.nodeModifier(id: NodeModifierID("shopDiscount")))
        #expect(modifier.effect.description == "Reduced Gold Prices")
        let style = NodeModifierPresentation.style(for: modifier)
        #expect(style.icon == Keyword.gold.visualStyle.icon)
        #expect(style.color == Keyword.gold.visualStyle.color)
    }
}

extension StageMapPresentationTests {
    @Test func `campaign recruit stages always use mystery recruit scene art`() throws {
        let recruits = GameContent.chapters.flatMap(\.stages).filter {
            $0.encounter.recruitEventID != nil
        }
        #expect(!recruits.isEmpty)

        for stage in recruits {
            let art = try #require(
                stage.encounterArtReference,
                "Recruit stage \(stage.id) should use mystery recruit scene art",
            )
            #expect(stage.encounterCombatantArtReference(worldSeed: 0) == nil)
            #expect(
                art.imageName == "encounter_mystery_recruit_heroes"
                    || art.imageName == "encounter_mystery_recruit_companions",
                "Recruit stage \(stage.id) used \(art.imageName)",
            )
        }

        let companion = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        let hero = try #require(GameContent.stage(id: "chapter-1-stage-5"))
        let randomCompanion = try #require(GameContent.stage(id: "chapter-2-stage-6"))
        let empty = try #require(GameContent.stage(id: "chapter-3-stage-7"))
        #expect(companion.encounterArtReference?.imageName == "encounter_mystery_recruit_companions")
        #expect(hero.encounterArtReference?.imageName == "encounter_mystery_recruit_heroes")
        #expect(randomCompanion.encounterArtReference?.imageName == "encounter_mystery_recruit_companions")
        #expect(empty.encounterArtReference?.imageName == "encounter_mystery_recruit_heroes")
    }

    @Test func `exhausted recruit stage presents as ordinary mystery`() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        let resolved = GameContent.resolveRecruitStage(
            stage,
            worldSeed: 3,
            unlockedHeroIDs: Set(ContentAccessPolicy.freeHeroIDs),
            unlockedCompanionIDs: Set(ContentAccessPolicy.freeCompanionIDs),
            access: .free,
        )

        #expect(resolved.encounter.title == "Mystery")
        #expect(resolved.encounter.iconID == "sf:sparkles")
        #expect(resolved.encounter.primaryActionTitle == "Approach")
        #expect(resolved.encounterArtReference?.imageName != "encounter_mystery_recruit_companions")
    }

    @Test func `battle stages prefer enemy art over encounter art`() throws {
        let stage = try #require(GameContent.chapters[0].stages.first { $0.id == "chapter-1-stage-1" })

        #expect(GameContent.encounterArtID(for: stage) == nil)
        #expect(stage.encounterArtReference == nil)
        _ = try #require(stage.encounterCombatantArtReference(worldSeed: 0))
        #expect(stage.encounterSubjectName(worldSeed: 0) == "Slime")
    }

    @Test func `random battle subject name depends on world seed`() throws {
        let stage = try #require(
            GameContent.chapters.flatMap(\.stages).first { $0.encounter == .randomBattle },
        )
        let names = (1 ... 16).map { stage.encounterSubjectName(worldSeed: UInt64($0)) }
        #expect(Set(names).count > 1)
        #expect(!names.contains("Battle"))
    }

    @Test func `shop stages resolve merchant art and title without a catalog stage entry`() {
        let stage = Stage(
            id: "test-shop",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            encounter: .shop,
            rewards: .empty,
        )

        #expect(GameContent.encounterArtID(for: stage) == nil)
        #expect(stage.encounterArtReference?.imageName == "encounter_destination_merchant_shop")
        #expect(stage.encounterSubjectName(worldSeed: 0) == "Merchant")
    }

    @Test func `mapped event stages resolve encounter art without pinning catalog I ds`() throws {
        let stage = try #require(GameContent.chapters[1].stages.first { $0.id == "chapter-2-stage-8" })

        #expect(GameContent.encounterArtID(for: stage) != nil)
        _ = try #require(stage.encounterArtReference)
        #expect(!(stage.encounterSubjectName(worldSeed: 0).isEmpty))
    }

    @Test func `seeded journey mystery provides encounter art for unpinned stages`() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        #expect(stage.encounter.mysteryEventID == nil)
        #expect(stage.encounterArtReference == nil)

        let event = GameContent.resolveJourneyMysteryEvent(
            stage: stage,
            worldSeed: 1,
            context: .excludingCorruptionAltar,
        )
        #expect(!event.isRecruit)
        let artID = try #require(event.artID, "Seeded mystery \(event.id) must provide scene art")
        let art = try #require(ArtCatalog.encounterArtByID[artID])
        let resolvedStage = Stage(
            id: stage.id,
            chapterID: stage.chapterID,
            chapterNumber: stage.chapterNumber,
            stageNumber: stage.stageNumber,
            encounter: .mysteryEvent(eventID: event.id),
            rewards: stage.rewards,
        )
        #expect(resolvedStage.encounterArtReference == art)
    }

    @Test func `spire rows hide cleared floors and end with boss before completion`() throws {
        let spire = try #require(GameContent.spire(id: .ironVein))
        let floors = GameContent.spireFloors(for: spire.id)
        var progress = PlayerSpiresState.freshStart
        _ = progress.markFloorCleared(1, spireID: spire.id.rawValue)
        _ = progress.markFloorCleared(2, spireID: spire.id.rawValue)

        let rows = StageSelectRowPresentation<SpireFloor>.spireRows(
            for: spire,
            floors: floors,
            progress: progress,
            worldSeed: 7,
        )

        #expect(rows.map(\.item.floor) == Array(3 ... spire.floorCount))
        #expect(rows.first?.isActive == true)
        #expect(rows.dropFirst().allSatisfy { !$0.isActive })
        #expect(rows.first?.activeEyebrow == "Floor 3 · Battle")
        #expect(rows.last?.encounterTypeTitle == "Boss")
        let selected = try #require(GameContent.spireModifier(for: rows[0].item, worldSeed: 7))
        #expect(rows.first?.modifiers.map(\.id) == [selected.id.rawValue])
        let futureRowsHaveNoModifiers = rows.dropFirst().allSatisfy(\.modifiers.isEmpty)
        #expect(futureRowsHaveNoModifiers)

        for floor in 3 ... spire.floorCount {
            _ = progress.markFloorCleared(floor, spireID: spire.id.rawValue)
        }
        let completedRows = StageSelectRowPresentation<SpireFloor>.spireRows(
            for: spire,
            floors: floors,
            progress: progress,
            worldSeed: 7,
        )
        #expect(completedRows.isEmpty)
    }

    @Test func `spires hub orders by cleared floors then unlock then catalog`() {
        let progress = PlayerSpiresState(highestClearedFloorBySpireID: [
            SpireID.ironVein.rawValue: 3,
            SpireID.cinderSpire.rawValue: 3,
            SpireID.serpentHollow.rawValue: 10,
            SpireID.aureateChoir.rawValue: 10,
        ])
        let unlocked: Set<SpireID> = [.cinderSpire, .sanguineCourt, .aureateChoir]
        let ordered = GameContent.spires.orderedForSpiresHub(progress: progress) {
            unlocked.contains($0.id)
        }

        #expect(ordered.map(\.id) == [
            .aureateChoir,
            .serpentHollow,
            .cinderSpire,
            .ironVein,
            .sanguineCourt,
            .rimeVault,
            .resonanceHall,
        ])
    }

    @Test func `labyrinth node states follow reachability and completion`() {
        let source = LabyrinthNode(
            id: "source",
            type: .battle,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 0, column: 1),
            outgoingIDs: ["target"],
            isCleared: true,
            isRevealed: true,
        )
        let target = LabyrinthNode(
            id: "target",
            type: .shop,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 1, column: 1),
            isRevealed: true,
        )
        let locked = LabyrinthNode(
            id: "locked",
            type: .mystery,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 1, column: 2),
            isRevealed: true,
        )
        var state = PlayerLabyrinthState(
            hasEntered: true,
            nodes: [source.id: source, target.id: target, locked.id: locked],
        )

        #expect(LabyrinthMapPresentation.state(for: target, in: state) == .reachable)
        #expect(LabyrinthMapPresentation.state(for: locked, in: state) == .locked)

        var clearedTarget = target
        clearedTarget.isCleared = true
        state.nodes[target.id] = clearedTarget
        #expect(LabyrinthMapPresentation.state(for: clearedTarget, in: state) == .cleared)
    }

    @Test func `labyrinth effective type keeps non recruit nodes`() {
        let node = LabyrinthNode(id: "battle", type: .battle, depth: 1, clusterID: "floor")
        #expect(
            LabyrinthMapPresentation.effectiveType(
                for: node,
                worldSeed: 1,
                unlockedHeroIDs: [],
                unlockedCompanionIDs: [],
            ) == .battle,
        )
    }

    @Test func `labyrinth exhausted recruit becomes mystery without recruit art`() {
        let node = LabyrinthNode(id: "recruit", type: .recruit, depth: 1, clusterID: "floor")
        #expect(
            LabyrinthMapPresentation.effectiveType(
                for: node,
                worldSeed: 1,
                unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
                unlockedCompanionIDs: Set(GameContent.companions.map(\.id)),
            ) == .mystery,
        )
        #expect(
            LabyrinthMapPresentation.recruitEncounterArtReference(
                for: node,
                worldSeed: 1,
                unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
                unlockedCompanionIDs: Set(GameContent.companions.map(\.id)),
            ) == nil,
        )
    }

    @Test(arguments: [Combatant.Role.hero, .companion])
    func `labyrinth eligible recruit keeps its type and role scene`(role: Combatant.Role) throws {
        let event = try #require(GameContent.recruitEvents.first {
            GameContent.combatant(forMysteryEvent: $0)?.role == role
        })
        let lockedID = try #require(event.unlockCombatantID)
        let node = LabyrinthNode(
            id: "recruit-configured",
            type: .recruit,
            depth: 1,
            clusterID: "floor",
            recruitEventID: event.id,
        )
        let unlockedHeroIDs = Set(GameContent.heroes.map(\.id)).subtracting([lockedID])
        let unlockedCompanionIDs = Set(GameContent.companions.map(\.id)).subtracting([lockedID])
        #expect(
            LabyrinthMapPresentation.effectiveType(
                for: node,
                worldSeed: 1,
                unlockedHeroIDs: unlockedHeroIDs,
                unlockedCompanionIDs: unlockedCompanionIDs,
            ) == .recruit,
        )
        let art = try #require(
            LabyrinthMapPresentation.recruitEncounterArtReference(
                for: node,
                worldSeed: 1,
                unlockedHeroIDs: unlockedHeroIDs,
                unlockedCompanionIDs: unlockedCompanionIDs,
            ),
        )
        let expectedImageName = role == .hero
            ? "encounter_mystery_recruit_heroes"
            : "encounter_mystery_recruit_companions"
        #expect(art.imageName == expectedImageName)
    }
}
