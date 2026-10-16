import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct BlockPoolMutationRegressionTests {
    @Test(arguments: [0, -1])
    func `nonpositive Block requests do not create bonus Block or spend the next gain`(amount: Int) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            companionModifiers: CombatModifierProfile(blockGainedBonus: 7), appliesFightPacing: false,
        )
        battle.roster.companion.talents.pending.nextBlockGainMultiplier = PreparedTalentBonus(value: 2)

        let events = battle.recordingEvents { state in
            let applied = state.applyBlockGain(amount, to: state.companion, source: state.companion, abilityName: "Empty gain")
            #expect(applied == 0)
        }

        #expect(events.isEmpty)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == 0)
        #expect(battle.roster.companion.talents.pending.nextBlockGainMultiplier?.value == 2)
        let later = battle.applyBlockGain(1, to: battle.companion, source: battle.companion, abilityName: "Positive gain")
        #expect(later == 16)
        #expect(battle.roster.companion.talents.pending.nextBlockGainMultiplier == nil)
    }

    @Test(arguments: [false, true], [0, 7])
    func `Block theft reports only actual loss while preserving protected pools`(protected: Bool, block: Int) {
        var battle = BattleStateTestFactory.makeBattle(
            companionModifiers: .withTriggers { $0.goldTheftStealEnemyBlockChancePercent = 1 },
            enemyModifiers: .withTriggers { $0.sealedSarcophagus = protected },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let events = battle.recordingEvents { state in
            _ = await state.grantGold(2, to: state.companion, abilityName: "Steal", isTheft: true)
        }
        let stolen = protected ? 0 : block
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == block - stolen)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == stolen)
        let losses = events.filter { $0.effectKind == .blockStripped }
        #expect(losses.map(\.amount) == (stolen > 0 ? [stolen] : []))
        #expect(losses
            .allSatisfy { $0.actorID == battle.companion.id && $0.targetID == battle.enemy.id && $0.abilityName == "Light-Fingered" })
        #expect(BattleLogProjection.entries(from: events).map(\.text).filter { $0.contains("removes") } == (stolen > 0
                ? ["\(battle.companion.name) removes \(stolen) Block from \(battle.enemy.name) (Light-Fingered)."] : []))
        #expect(!events.contains { $0.effectKind == .shieldAbsorbed })
    }

    @Test(arguments: [0, 7])
    func `Sunder Shield reports stripped Block without absorption`(block: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["shield_scarab_stun_t1_1"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let events = battle.chargeTestControl(
            ControlMeterEngine.threshold(for: battle.enemy, in: battle), keyword: .stun,
            to: battle.enemy, sourceActorID: battle.companion.id, applyFightPacing: false,
        )
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 0)
        let losses = events.filter { $0.effectKind == .blockStripped }
        #expect(losses.map(\.amount) == (block > 0 ? [block] : []))
        #expect(losses
            .allSatisfy { $0.actorID == battle.companion.id && $0.targetID == battle.enemy.id && $0.abilityName == "Sunder Shield" })
        #expect(BattleLogProjection.entries(from: events).map(\.text).filter { $0.contains("removes") } == (block > 0
                ? ["\(battle.companion.name) removes \(block) Block from \(battle.enemy.name) (Sunder Shield)."] : []))
        #expect(!events.contains { $0.effectKind == .shieldAbsorbed })
    }

    @Test func `preventing new Block does not erase retained or spent Block`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        DefensePoolEngine.set(12, on: battle.enemy, in: &battle)
        battle.roster.enemy.talents.turn.blockGainPrevented = true

        #expect(DefensePoolEngine.halveBlock(on: battle.enemy, in: &battle))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 6)
        CombatExecutor.run { await DefensePoolEngine.decayBlock(on: battle.enemy, in: &battle) }
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 3)
        #expect(battle.applyBlockGain(4, to: battle.enemy, source: battle.enemy, abilityName: "Blocked gain") == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 3)
    }

    @Test func `resolved enemy Block does not repeat Burning gain reduction`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.burningEnemyBlockGainMultiplier = 0.5
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.insertEffect(.burn(2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)

        let resolved = battle.applyBlockGain(
            8, to: battle.enemy, source: battle.enemy, abilityName: "Resolved gain", amountBasis: .resolved,
        )
        let base = battle.applyBlockGain(8, to: battle.enemy, source: battle.enemy, abilityName: "Base gain")
        #expect(resolved == 8)
        #expect(base == 4)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 12)
    }
}
