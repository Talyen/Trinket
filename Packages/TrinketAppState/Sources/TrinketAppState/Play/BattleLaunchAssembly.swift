import BattleEngine
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

struct BattleLaunchAssembly {
    let configuration: BattleRunConfiguration
    let rewardPlan: BattleRewardPlan
    let presentation: BattlePresentationContext
    let inputs: BattlePreparationInputs
    var universalModifiers: [AffixModifier] {
        inputs.launch.universalModifiers
    }
}

extension PlayBattleCoordinator {
    static func assembleLaunch(_ inputs: BattlePreparationInputs) -> BattleLaunchAssembly {
        let input = inputs.launch
        let rosterState = inputs.party.roster
        let inventoryState = inputs.party.inventory
        let homesteadEffects = inputs.party.homestead.effects
        let heroMember = partyMember(
            combatant: input.hero,
            rosterState: rosterState,
            inventoryState: inventoryState,
            additionalModifiers: homesteadEffects.heroModifiers,
        )
        let companionMember = partyMember(
            combatant: input.companion,
            rosterState: rosterState,
            inventoryState: inventoryState,
            additionalModifiers: homesteadEffects.companionModifiers,
        )
        let enemyBuild = input.encounter?.build ?? CombatBuild(combatant: Enemy.fallbackCombatant, modifiers: .zero)
        var enemyModifiers = enemyBuild.modifiers
        enemyModifiers.merge(input.universalModifiers)
        let configuration = BattleRunConfiguration(
            runKey: input.origin?.runKey,
            rngSeed: inputs.rngSeed,
            hero: heroMember,
            companion: companionMember,
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: input.encounter?.level,
            enemyModifiers: enemyModifiers,
            enemyFaction: input.encounter?.faction ?? .mortal,
        )
        let rewardPlan = BattleRewardAssembly.makePlan(inputs: inputs, configuration: configuration)
        return BattleLaunchAssembly(
            configuration: configuration,
            rewardPlan: rewardPlan,
            presentation: BattleRewardAssembly.makePresentation(inputs: inputs, configuration: configuration, rewardPlan: rewardPlan),
            inputs: inputs,
        )
    }

    private static func partyMember(
        combatant: Combatant,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        additionalModifiers: [AffixModifier],
    ) -> BattleRunConfiguration.PartyMember {
        let progression = rosterState.progression(for: combatant)
        let equipmentLoadout = rosterState.equipmentLoadout(for: combatant)
        let unlockedTalents = rosterState.unlockedTalents(for: combatant)
        let build = CombatBuildResolver.build(
            combatant: CombatantLevelScaler.scale(
                combatant: combatant,
                level: progression.level,
            ),
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryState.items,
            unlockedTalents: unlockedTalents,
            additionalModifiers: additionalModifiers,
        )
        return BattleRunConfiguration.PartyMember(
            combatant: build.combatant,
            progression: progression,
            equipmentLoadout: equipmentLoadout,
            modifiers: build.modifiers,
            unlockedTalents: unlockedTalents,
        )
    }
}
