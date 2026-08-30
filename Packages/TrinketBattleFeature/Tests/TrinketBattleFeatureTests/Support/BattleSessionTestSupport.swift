import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
enum BattleSessionTestSupport {
    static let deterministicBattleSeed: UInt64 = CombatantFixtures.deterministicBattleSeed

    static func makeConfiguredSession(
        rngSeed: UInt64 = deterministicBattleSeed,
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        enemy: Combatant? = nil,
        autoEndTurnDelay: TimeInterval = 0.01,
        presentationEnvironment: BattleRuntimeDependencies = .silent,
        stageRewardsAlreadyClaimed: Bool = false,
    ) throws -> BattleSession {
        let resolvedHero = hero ?? CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTurns: 1,
            abilities: [.slash],
        )
        let resolvedCompanion = companion ?? CombatantFixtures.combatant(
            id: "companion",
            role: .companion,
            actionIntervalTurns: 100,
            abilities: [],
        )
        let resolvedEnemy = enemy ?? CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTurns: 100,
            abilities: [],
        )
        let session = BattleSession(
            autoEndTurnDelay: autoEndTurnDelay,
            openingHandDrawStagger: 0,
            enemyAttackImpactDelayOverride: 0,
            outcomePresentationDelayOverride: 0,
            presentationEnvironment: presentationEnvironment,
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
        _ = session.activate(configuration)
        session.installPresentationContext(presentation)
        return session
    }

    static func presentationEnvironment(
        shouldAutoSkipUltimateCinematic: @escaping (String, Set<String>) -> Bool,
    ) -> BattleRuntimeDependencies {
        BattleRuntimeDependencies(
            playSFX: { _ in },
            warmSFX: { _, _ in },
            hapticsEnabled: { false },
            effectsVolume: { 0 },
            shouldAutoSkipUltimateCinematic: shouldAutoSkipUltimateCinematic,
        )
    }

    static func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool,
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
            if session.spectacle.activeCinematic != nil {
                session.completeCinematicCollapse(at: date)
                continue
            }
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
        return session.outcome == .victory ? session.earnedGold : nil
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
            if session.spectacle.activeCinematic != nil {
                session.completeCinematicCollapse(at: date)
                continue
            }
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
        return session.outcome == .victory ? session.earnedGold : nil
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
        isCardCastActive: @escaping @MainActor () -> Bool = { false },
        isManualInteractionActive: @escaping @MainActor () -> Bool = { false },
        playCard: @escaping @MainActor (BattleCard) async -> Bool,
    ) async {
        session.isAutoBattleEnabled = true
        await session.driveAutoBattle(
            isCardCastActive: isCardCastActive,
            isManualInteractionActive: isManualInteractionActive,
            playCard: playCard,
        )
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
