import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
import TrinketFeatureContracts
import TrinketFeatureSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
enum BattleSessionTestSupport {
    static func automaticDrawCard(owner: BattleParticipant = .hero) -> Ability {
        Ability(
            id: "automatic-draw-\(owner)", name: "Automatic Draw", tier: .ultimate,
            directDamage: 3,
            targetedEffects: [TargetedEffect(.drawAndPlayCards(1), target: owner == .hero ? .companion : .hero)],
        )
    }

    /// Session-level default enemy is `passiveEnemy()`'s 100 HP parked enemy —
    /// not `quickWinParty`'s 1 HP default, which is substituted explicitly below
    /// so the divergence stays visible. Pass `enemy:` to override.
    static func makeConfiguredSession(
        rngSeed: UInt64 = CombatantFixtures.deterministicBattleSeed,
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        enemy: Combatant? = nil,
        autoEndTurnDelay: TimeInterval = 0.01,
        presentationEnvironment: BattlePresentationDependencies? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        progression: BattleProgressionProbe? = nil,
    ) -> BattleSession {
        // Session default: a durable parked enemy. This intentionally replaces
        // quickWinParty's 1 HP enemy with passiveEnemy()'s 100 HP default;
        // one-shot sessions should call BattlePartyFixtures.quickWinParty()
        // directly.
        let party = BattlePartyFixtures.quickWinParty(
            hero: hero,
            companion: companion,
            enemy: enemy ?? CombatantFixtures.passiveEnemy(),
        )
        let resolvedHero = party.hero
        let resolvedCompanion = party.companion
        let resolvedEnemy = party.enemy
        let session = BattleSession(
            autoEndTurnDelay: autoEndTurnDelay,

            outcomePresentationDelayOverride: 0,
            presentationEnvironment: presentationEnvironment ?? .silent,
        )
        session.partyCelebrateDelayOverride = .zero
        session.autoBattleRetryDelay = .zero
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            rngSeed: rngSeed,
            hero: resolvedHero,
            companion: resolvedCompanion,
            enemy: resolvedEnemy,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
        )
        if let progression {
            progression.session = session
            session.connectProgression(to: progression)
        }
        _ = session.activate(configuration, presentation: presentation)
        return session
    }

    static func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @MainActor () -> Bool,
    ) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else { return false }
            try await Task.sleep(for: .milliseconds(5))
        }
        return true
    }

    @discardableResult
    static func driveUntilOutcome(
        _ session: BattleSession,
        at date: Date = .now,
        maxActions: Int = 200,
    ) -> Int? {
        var actions = 0
        while session.outcome == nil, actions < maxActions {
            actions += 1
            if let card = session.hand.first(where: { session.isCardPlayable($0) }) {
                _ = session.playCard(
                    cardID: card.id,
                    at: date,
                )
                continue
            }
            if session.canEndTurn {
                session.endTurn(at: date)
                continue
            }
            break
        }
        return session.outcome == .victory ? session.goldFlow?.net : nil
    }

    @discardableResult
    static func drawUntilPlayable(
        _ abilityID: String,
        on session: BattleSession,
        at date: Date = .now,
        maxActions: Int = 40,
    ) -> BattleCard? {
        var actions = 0
        while session.outcome == nil, actions < maxActions {
            actions += 1
            if let card = session.hand.first(where: {
                $0.ability.id == abilityID && session.isCardPlayable($0)
            }) {
                return card
            }
            if let other = session.hand.first(where: { session.isCardPlayable($0) }) {
                _ = session.playCard(
                    cardID: other.id,
                    at: date,
                )
                continue
            }
            if session.canEndTurn {
                session.endTurn(at: date)
                continue
            }
            break
        }
        return nil
    }

    @discardableResult
    static func playAbility(
        _ abilityID: String,
        on session: BattleSession,
        at date: Date = .now,
        maxActions: Int = 40,
    ) -> Int? {
        guard let card = drawUntilPlayable(
            abilityID,
            on: session,
            at: date,
            maxActions: maxActions,
        ) else { return nil }
        _ = session.playCard(
            cardID: card.id,
            at: date,
        )
        return session.outcome == .victory ? session.goldFlow?.net : nil
    }

    /// Durability-probe scale for presentation tests that must survive many
    /// turns without ending the battle. Deliberately larger than the shared
    /// `20/100` fixture scale; the companion inherits the hero scale unless
    /// overridden. See `BattleSessionPreparationTests` session-default pins.
    private static let passiveSessionHeroHealth = 100
    private static let passiveSessionHeroMana = 12
    private static let passiveSessionEnemyHealth = 1000

    static func makePassiveSession(
        heroHealth: Int = passiveSessionHeroHealth,
        heroMana: Int = passiveSessionHeroMana,
        enemyHealth: Int = passiveSessionEnemyHealth,
        companionHealth: Int? = nil,
        companionMana: Int? = nil,
    ) -> BattleSession {
        makeConfiguredSession(
            hero: CombatantFixtures.passiveHero(maxHealth: heroHealth, maxMana: heroMana),
            companion: CombatantFixtures.passiveCompanion(
                maxHealth: companionHealth ?? heroHealth,
                maxMana: companionMana ?? heroMana,
            ),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: enemyHealth),
            autoEndTurnDelay: 60,
        )
    }

    static func makeDrivenVictorySummary(
        configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext,
    ) -> BattleVictorySummary? {
        let session = BattleSession()
        _ = session.activate(configuration, presentation: presentation)
        driveUntilOutcome(session)
        return session.makeVictorySummary(for: configuration, presentation: presentation)
    }

    static func greedyPlaySequence(from session: BattleSession) throws -> [Int] {
        var preview = try #require(session.engineState)
        let policy = PlayPolicy.greedy
        var ids: [Int] = []
        while let card = policy.preferredPlayableCard(in: preview) {
            ids.append(card.id)
            _ = try preview.playCard(cardID: card.id, rebuildLog: false)
        }
        return ids
    }

    static func driveAutoBattleUntilStopped(
        session: BattleSession,
        isCardCastPacingBlocked: @escaping @MainActor () -> Bool = { false },
        isManualInteractionActive: @escaping @MainActor () -> Bool = { false },
        playCard: @escaping @MainActor (BattleCard) async -> Bool,
    ) async {
        session.isAutoBattleEnabled = true
        await session.driveAutoBattle(
            isCardCastPacingBlocked: isCardCastPacingBlocked,
            isManualInteractionActive: isManualInteractionActive,
            playCard: playCard,
        )
    }

    static func makeUltimateSession(
        heroID: String = "knight",
        abilities: [Ability] = [.slash, .fireball, .avatarOfJustice],
        enemyHealth: Int = 500,
        presentationEnvironment: BattlePresentationDependencies? = nil,
    ) -> BattleSession {
        makeConfiguredSession(
            hero: CombatantFixtures.combatant(id: heroID, role: .hero, abilities: abilities),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: enemyHealth,
                abilities: [],
            ),
            presentationEnvironment: presentationEnvironment,
        )
    }

    /// Plays every playable card. Returns false (recording an issue) when
    /// setup ends the battle before the caller’s assertion runs.
    @discardableResult
    static func exhaustHand(on session: BattleSession) -> Bool {
        while let card = session.hand.first(where: { session.isCardPlayable($0) }) {
            if session.playCard(cardID: card.id) == .rejected || session.outcome != nil {
                Issue.record("Setup exhausted the battle before the pending assertion")
                return false
            }
        }
        return true
    }

    static func assertMilestonesExcluded(
        from session: BattleSession,
        sourceLocation: SourceLocation = #_sourceLocation,
    ) {
        let recordedIDs = Set(session.feedback.activeItems.flatMap(\.sourceEventIDs))
        let milestoneIDs = Set((session.engineState?.events ?? []).filter { $0.kind == .milestone }.map(\.id))
        #expect(recordedIDs.isDisjoint(with: milestoneIDs), sourceLocation: sourceLocation)
    }

    nonisolated static func makeActionEvent(
        id: Int,
        kind: ActionEvent.Kind,
        effectKind: ActionEvent.EffectOutcome? = nil,
        amount: Int,
        keyword: Keyword,
        targetID: String = "enemy",
        isCritical: Bool = false,
        actionID: Int? = nil,
        abilityID: String = "slash",
        abilityName: String = "Slash",
    ) -> ActionEvent {
        ActionEvent(
            id: id,
            actionID: actionID ?? id,
            kind: kind,
            effectKind: effectKind,
            actorID: "hero",
            actorName: "Hero",
            abilityID: abilityID,
            abilityName: abilityName,
            targetID: targetID,
            targetName: targetID.capitalized,
            amount: amount,
            keyword: keyword,
            isCritical: isCritical,
        )
    }
}

@MainActor
final class BattleProgressionProbe: BattleProgressionDelegate {
    weak var session: BattleSession?
    let presentation: BattlePresentationContext?
    let plan: BattleRewardPlan?
    let completeVictory: (BattleRunConfiguration, BattleGoldFlow, BattleRewardSettlement?) -> BattleCompletionResult

    init(
        session: BattleSession? = nil,
        presentation: BattlePresentationContext? = nil,
        plan: BattleRewardPlan? = nil,
        completeVictory: @escaping (BattleRunConfiguration, BattleGoldFlow, BattleRewardSettlement?)
            -> BattleCompletionResult = { _, _, _ in
                .unavailable
            },
    ) {
        self.session = session
        self.presentation = presentation
        self.plan = plan
        self.completeVictory = completeVictory
    }

    func settleBattleRewards(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards _: [ResourceAmount]?,
        at _: Date?,
    ) -> BattleRewardSettlement? {
        guard let plan else { return nil }
        return plan.settle(
            battleGold: battleGold,
            inputs: presentation?.rewardInputs ?? BattleSession.fallbackRewardInputs(for: configuration),
        )
    }

    func settleDefeatRewards(_ configuration: BattleRunConfiguration, at _: Date?) -> BattleRewardSettlement? {
        guard let plan, let progress = session?.resolvedDefeatProgress else { return nil }
        return plan.settleDefeat(
            progress: progress,
            inputs: presentation?.rewardInputs ?? BattleSession.fallbackRewardInputs(for: configuration),
        )
    }

    func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards _: [ResourceAmount]?,
        settlement: BattleRewardSettlement?,
        defersPresentationExit _: Bool,
    ) -> BattleCompletionResult {
        completeVictory(configuration, battleGold, settlement)
    }

    func completeDefeat(
        _: BattleRunConfiguration,
        settlement _: BattleRewardSettlement,
        action _: BattleDefeatAction,
    ) -> BattleCompletionResult {
        .unavailable
    }

    func finishBattleRewardPresentation(configurationID _: UUID) {}
}
