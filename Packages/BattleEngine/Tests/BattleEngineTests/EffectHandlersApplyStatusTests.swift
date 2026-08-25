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
        .randomOneOfTwo,
    ])
    private func cleanseModesRemoveExpectedDebuffs(caseKind: CleanseCase) throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let effect = seedCleanseCase(caseKind, battle: &battle)

        let outcome = EffectHandlersTestSupport.dispatch(
            effect,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(outcome.didApply)
        try assertCleanseOutcome(caseKind, battle: battle, outcome: outcome)
    }

    private func seedCleanseCase(_ caseKind: CleanseCase, battle: inout BattleState) -> Effect {
        switch caseKind {
        case .specificPoison:
            BattleStateTestFactory.seedActiveEffects(
                [ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0)],
                for: battle.hero,
                on: &battle
            )
            return .cleanse(.poison)
        case .allDebuffs:
            BattleStateTestFactory.seedActiveEffects(
                [
                    ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0),
                    ActiveEffect(id: 2, effect: .burn(4), remainingTurns: 0),
                    ActiveEffect(id: 3, effect: .shield(.block, 5), remainingTurns: 6),
                ],
                for: battle.hero,
                on: &battle
            )
            return .cleanse(nil)
        case .stunPrevention:
            BattleStateTestFactory.seedActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(.stun, 5, 10), remainingTurns: 0)],
                for: battle.hero,
                on: &battle
            )
            return .cleanse(.stun)
        case .randomOneOfTwo:
            BattleStateTestFactory.seedActiveEffects(
                [
                    ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0),
                    ActiveEffect(id: 2, effect: .burn(4), remainingTurns: 0),
                ],
                for: battle.hero,
                on: &battle
            )
            return .cleanseRandom
        }
    }

    private func assertCleanseOutcome(
        _ caseKind: CleanseCase,
        battle: BattleState,
        outcome: EffectApplyOutcome
    ) throws {
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
        .randomOneOfTwo,
    ])
    private func purgeModesRemoveExpectedBuffs(caseKind: PurgeCase) throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let effect = seedPurgeCase(caseKind, battle: &battle)

        let outcome = EffectHandlersTestSupport.dispatch(
            effect,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
        )
        try #expect(outcome.didApply)
        try assertPurgeOutcome(caseKind, battle: battle, outcome: outcome)
    }

    private func seedPurgeCase(_ caseKind: PurgeCase, battle: inout BattleState) -> Effect {
        switch caseKind {
        case .specificBlock:
            BattleStateTestFactory.seedActiveEffects(
                [
                    ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 6),
                    ActiveEffect(id: 2, effect: .thorns(3), remainingTurns: 0),
                ],
                for: battle.enemy,
                on: &battle
            )
            return .purge(.block)
        case .allBuffsLeaveDebuffs:
            BattleStateTestFactory.seedActiveEffects(
                [
                    ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 6),
                    ActiveEffect(id: 2, effect: .poison(4), remainingTurns: 0),
                ],
                for: battle.enemy,
                on: &battle
            )
            return .purge(nil)
        case .randomOneOfTwo:
            BattleStateTestFactory.seedActiveEffects(
                [
                    ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 6),
                    ActiveEffect(id: 2, effect: .thorns(3), remainingTurns: 0),
                ],
                for: battle.enemy,
                on: &battle
            )
            return .purgeRandom
        }
    }

    private func assertPurgeOutcome(
        _ caseKind: PurgeCase,
        battle: BattleState,
        outcome: EffectApplyOutcome
    ) throws {
        switch caseKind {
        case .specificBlock:
            try #expect(!(battle.activeEffects(of: battle.enemy)).contains {
                if case .shield = $0.effect {
                    return true
                }
                return false
            })
            try #expect(battle.activeEffects(of: battle.enemy).contains {
                if case .thorns = $0.effect {
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
