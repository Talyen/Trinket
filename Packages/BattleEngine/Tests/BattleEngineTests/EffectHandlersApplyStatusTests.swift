import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct EffectHandlersApplyStatusTests {
    // MARK: - Cleanse

    private enum CleanseCase {
        case specificPoison
        case allDebuffs
        case stunPrevention
        case randomOneOfTwo
    }

    @Test(arguments: [
        CleanseCase.specificPoison,
        .allDebuffs,
        .stunPrevention,
        .randomOneOfTwo
    ])
    func cleanseModesRemoveExpectedDebuffs(caseKind: CleanseCase) throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let effect: Effect
        switch caseKind {
        case .specificPoison:
            BattleStateTestFactory.seedActiveEffects(
                [ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)],
                for: battle.hero,
                on: &battle
            )
            effect = .cleanse(.poison)
        case .allDebuffs:
            BattleStateTestFactory.seedActiveEffects(
                [
                    ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                    ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0),
                    ActiveEffect(id: 3, effect: .shield(.block, 5), remainingTicks: 6)
                ],
                for: battle.hero,
                on: &battle
            )
            effect = .cleanse(nil)
        case .stunPrevention:
            BattleStateTestFactory.seedActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(.stun, 5, 10), remainingTicks: 0)],
                for: battle.hero,
                on: &battle
            )
            effect = .cleanse(.stun)
        case .randomOneOfTwo:
            BattleStateTestFactory.seedActiveEffects(
                [
                    ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                    ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0)
                ],
                for: battle.hero,
                on: &battle
            )
            effect = .cleanseRandom
        }

        let outcome = EffectHandlersTestSupport.dispatch(
            effect,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(outcome.didApply)

        switch caseKind {
        case .specificPoison:
            try #expect(!(battle.activeEffects(of: battle.hero)).contains {
                $0.effect.isDecayingDoT && $0.keyword == .poison
            })
            try #expect(outcome.events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .poison })
        case .allDebuffs:
            try #expect(!(battle.activeEffects(of: battle.hero)).contains(where: \.effect.isRemovableDebuff))
            try #expect(battle.activeEffects(of: battle.hero).contains { ae in
                if case .shield(.block, 5) = ae.effect {
                    return true
                }
                return false
            })
        case .stunPrevention:
            try #expect(!(battle.activeEffects(of: battle.hero)).contains(where: \.effect.isControlMeter))
        case .randomOneOfTwo:
            let remainingDebuffs = battle.activeEffects(of: battle.hero).filter(\.effect.isRemovableDebuff)
            try #expect(remainingDebuffs.count == 1)
        }
    }

    // MARK: - Purge

    private enum PurgeCase {
        case specificBlock
        case allBuffsLeaveDebuffs
        case randomOneOfTwo
    }

    @Test(arguments: [
        PurgeCase.specificBlock,
        .allBuffsLeaveDebuffs,
        .randomOneOfTwo
    ])
    func purgeModesRemoveExpectedBuffs(caseKind: PurgeCase) throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let effect: Effect
        switch caseKind {
        case .specificBlock:
            BattleStateTestFactory.seedActiveEffects(
                [
                    ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 6),
                    ActiveEffect(id: 2, effect: .mitigation(.armor, 2), remainingTicks: 6)
                ],
                for: battle.enemy,
                on: &battle
            )
            effect = .purge(.block)
        case .allBuffsLeaveDebuffs:
            BattleStateTestFactory.seedActiveEffects(
                [
                    ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 6),
                    ActiveEffect(id: 2, effect: .poison(4), remainingTicks: 0)
                ],
                for: battle.enemy,
                on: &battle
            )
            effect = .purge(nil)
        case .randomOneOfTwo:
            BattleStateTestFactory.seedActiveEffects(
                [
                    ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 6),
                    ActiveEffect(id: 2, effect: .mitigation(.armor, 2), remainingTicks: 6)
                ],
                for: battle.enemy,
                on: &battle
            )
            effect = .purgeRandom
        }

        let outcome = EffectHandlersTestSupport.dispatch(
            effect,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
        )
        try #expect(outcome.didApply)

        switch caseKind {
        case .specificBlock:
            try #expect(!(battle.activeEffects(of: battle.enemy)).contains {
                if case .shield = $0.effect {
                    return true
                }
                return false
            })
            try #expect(battle.activeEffects(of: battle.enemy).contains {
                if case .mitigation = $0.effect {
                    return true
                }
                return false
            })
            try #expect(outcome.events.contains { $0.effectKind == .purgeApplied && $0.keyword == .block })
        case .allBuffsLeaveDebuffs:
            try #expect(!(battle.activeEffects(of: battle.enemy)).contains(where: \.effect.isRemovableBuff))
            try #expect(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isRemovableDebuff))
            try #expect(outcome.events.contains { $0.effectKind == .purgeApplied && $0.keyword == .purge })
        case .randomOneOfTwo:
            try #expect(battle.activeEffects(of: battle.enemy).filter(\.effect.isRemovableBuff).count == 1)
            try #expect(outcome.events.contains { $0.effectKind == .purgeApplied })
        }
    }
}
