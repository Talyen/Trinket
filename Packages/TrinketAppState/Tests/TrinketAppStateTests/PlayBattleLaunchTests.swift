import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import TrinketAppState

@MainActor
struct PlayBattleLaunchTests {
    @Test func `prepare tracker caches by inputs and prepared run`() {
        var tracker = PlayBattlePreparationTracker<String>()
        #expect(tracker.shouldPrepare(for: "stage-1", hasPreparedRun: false))
        #expect(tracker.shouldPrepare(for: "stage-1", hasPreparedRun: true))

        tracker.notePrepared("stage-1")
        #expect(!tracker.shouldPrepare(for: "stage-1", hasPreparedRun: true))
        #expect(tracker.shouldPrepare(for: "stage-1", hasPreparedRun: false))
        #expect(tracker.shouldPrepare(for: "stage-2", hasPreparedRun: true))

        tracker.invalidate()
        #expect(tracker.shouldPrepare(for: "stage-1", hasPreparedRun: true))
    }

    private func makeLaunch(_ input: BattleLaunchInput) -> BattleLaunchAssembly {
        PlayBattleLaunch.assembleLaunch(
            input: input,
            rngSeed: 0,
            rosterState: .testSeed,
            inventoryState: .testSeed,
        )
    }

    private func knightAndWolf() throws -> (knight: Combatant, wolf: Combatant) {
        try (
            #require(GameContent.heroes.first { $0.id == "knight" }),
            #require(GameContent.companions.first { $0.id == "wolf" }),
        )
    }

    @Test func `random battle resolves deterministic non boss encounter`() throws {
        let stage = try #require(
            GameContent.chapters
                .flatMap(\.stages)
                .first { stage in
                    if case .randomBattle = stage.encounter {
                        return true
                    }
                    return false
                },
        )
        let encounter = try #require(
            JourneyPlayMode.resolvedEncounter(for: stage, worldSeed: 0, partyAverageLevel: 9999),
        )
        let expectedEnemyID = try #require(stage.resolvedBattleEnemyID(worldSeed: 0))

        #expect(encounter.combatant.id == expectedEnemyID)
        #expect(GameContent.enemy(matching: expectedEnemyID)?.isBoss == false)
        #expect(stage.encounter.isCombat)
        #expect(stage.encounter.battleEnemyID == nil)

        let again = try #require(
            JourneyPlayMode.resolvedEncounter(for: stage, worldSeed: 0, partyAverageLevel: 9999),
        )
        #expect(again.combatant.id == encounter.combatant.id)
    }

    @Test func `assemble applies universal damage modifier to enemy only`() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let modifier = AffixModifier.damageDealt(.burn, 1)

        let launch = PlayBattleLaunch.assembleLaunch(
            input: BattleLaunchInput(
                hero: hero,
                companion: companion,
                enemy: enemy,
                universalModifiers: [modifier],
            ),
            rngSeed: 0,
            rosterState: .testSeed,
            inventoryState: .testSeed,
        )

        let configuration = launch.configuration
        #expect(launch.universalModifiers == [modifier])
        #expect(configuration.hero.modifiers.damageDealtBonus(for: .burn) == 0)
        #expect(configuration.companion.modifiers.damageDealtBonus(for: .burn) == 0)
        #expect(configuration.enemyModifiers.damageDealtBonus(for: .burn) == 1)
    }

    @Test func `assemble carries labyrinth modifiers on presentation`() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let modifiers = try [
            #require(GameContent.labyrinthModifier(id: LabyrinthModifierID("ironPressure"))),
        ]

        let launch = PlayBattleLaunch.assembleLaunch(
            input: BattleLaunchInput(
                hero: hero,
                companion: companion,
                enemy: enemy,
                labyrinthModifiers: modifiers,
            ),
            rngSeed: 0,
            rosterState: .testSeed,
            inventoryState: .testSeed,
        )

        #expect(launch.presentation.labyrinthModifiers == modifiers)
    }

    @Test func `shared node combat effects reach the enemy profile`() {
        let ids = ["shieldedArrival", "bloodHunger", "sunderedGuard", "unbindingStrike", "cinderWard"]
            .map { LabyrinthModifierID($0) }
        let definitions = ids.compactMap(GameContent.labyrinthModifier(id:))
        #expect(definitions.count == ids.count)
        let effects = LabyrinthModifierEffects.combining(definitions)
        let profile = CombatModifierProfile(modifiers: LabyrinthPlayMode.combatModifiers(from: effects))
        #expect(profile.triggers.startBattleBlock == 6)
        #expect(profile.triggers.attackLeechPercent == Effect.abilityLeechPercent)
        #expect(profile.triggers.attackBlockRemoval == 2)
        #expect(profile.triggers.attackPurgeCount == 1)
        #expect(profile.damageTakenReduction(for: .burn) == 0.5)
    }

    @Test func `assemble bakes gold find and claimed stage policy`() throws {
        let (knight, wolf) = try knightAndWolf()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battleEnemyID = try #require(stage.encounter.battleEnemyID)
        let enemy = try #require(GameContent.enemy(matching: battleEnemyID)?.combatant)
        let homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.wishingWell: 2])

        let launch = PlayBattleLaunch.assembleLaunch(
            input: BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemy: enemy,
                stageRewardsAlreadyClaimed: true,
            ),
            runKey: BattleRunKey("journey|\(stage.id)"),
            rngSeed: 0,
            rosterState: .testSeed,
            inventoryState: .testSeed,
            homesteadState: homestead,
            hasProgressionRewards: true,
        )

        #expect(launch.presentation.goldFindPercent == homestead.effects.goldFindPercent)
        #expect(launch.presentation.goldFindFlat > 0)
        #expect(launch.presentation.stageRewardsAlreadyClaimed)
    }

    @Test func `assemble preserves pre scaled enemy stats`() throws {
        let chapter = try #require(GameContent.chapters.first)
        let battleStages = chapter.stages.filter(\.encounter.isCombat)
        let stage = try #require(battleStages.last)
        let encounterLevel = 5

        let enemyID = try #require(stage.resolvedBattleEnemyID(worldSeed: 0))
        let catalogEnemy = try #require(GameContent.enemy(matching: enemyID))
        let scaledEnemy = CombatantLevelScaler.scale(enemy: catalogEnemy, level: encounterLevel)

        let (knight, wolf) = try knightAndWolf()

        let configuration = PlayBattleLaunch.assembleLaunch(
            input: BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemy: scaledEnemy,
                enemyEncounterLevel: encounterLevel,
            ),
            runKey: BattleRunKey("journey|\(stage.id)"),
            rngSeed: 0,
            rosterState: .testSeed,
            inventoryState: .testSeed,
            hasProgressionRewards: true,
        ).configuration

        let enemy = try #require(configuration.enemy)
        #expect(enemy.maxHealth == scaledEnemy.maxHealth)
        #expect(enemy.maxHealth > catalogEnemy.combatant.maxHealth)
        #expect(configuration.enemyEncounterLevel == encounterLevel)
    }

    @Test func `assemble bakes experience and material awards`() throws {
        let (knight, wolf) = try knightAndWolf()
        let stageReward = StageReward(
            gold: 12,
            itemTemplateIDs: [],
            materialRewards: [ResourceAmount(.wood, 8), ResourceAmount(.stone, 3)],
        )

        let launch = PlayBattleLaunch.assembleLaunch(
            input: BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemyEncounterLevel: 2,
                stageReward: stageReward,
            ),
            rngSeed: 0,
            rosterState: .testSeed,
            inventoryState: .testSeed,
            hasProgressionRewards: true,
        )

        #expect(launch.presentation.heroExperienceAward > 0)
        #expect(launch.presentation.companionExperienceAward > 0)
        #expect(launch.presentation.materialRewards == stageReward.materialRewards)
    }

    @Test func `assemble resolves reward items from pending or stage policy`() throws {
        let (knight, wolf) = try knightAndWolf()
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let baseType = try #require(GameContent.itemBaseTypes.first)
        let pendingItem = InventoryItem(
            id: "pending-audit-reward",
            templateID: "shortsword-basic",
            baseType: baseType,
            rarity: .basic,
            displayName: "Pending Find",
            affixes: [],
        )

        let withPending = makeLaunch(
            BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemy: enemy,
                stageReward: StageReward(gold: 10, itemTemplateIDs: ["shortsword-basic"]),
                pendingRewardItem: pendingItem,
            ),
        )
        #expect(withPending.presentation.rewardItems == [pendingItem])

        let noPendingNilStage = makeLaunch(
            BattleLaunchInput(hero: knight, companion: wolf, enemy: enemy),
        )
        #expect(noPendingNilStage.presentation.rewardItems.isEmpty)

        let noPendingEmptyStage = makeLaunch(
            BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemy: enemy,
                stageReward: StageReward(gold: 0, itemTemplateIDs: []),
            ),
        )
        #expect(noPendingEmptyStage.presentation.rewardItems.isEmpty)

        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        let fromStage = makeLaunch(
            BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemy: enemy,
                stageReward: StageReward(gold: 10, itemTemplateIDs: ["shortsword-basic"]),
            ),
        )
        #expect(fromStage.presentation.rewardItems == [template])
    }
}
