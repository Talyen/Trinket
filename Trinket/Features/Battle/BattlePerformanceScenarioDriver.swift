#if DEBUG
import BattleEngine
import SwiftUI
import TrinketCore
import TrinketDesignSystem

/// Stimulus implementations for `BattlePerformanceScenarioHarness`. Kept separate so the
/// harness view stays under the type-body lint budget as the matrix grows.
@MainActor
struct BattlePerformanceScenarioDriver {
    let scenario: BattlePerformanceScenario
    let appState: AppState
    let battleSession: BattleSession
    let battleSize: CGSize
    let castPresentation: BattleCastPresentationState
    let forcedDrag: BattleForcedDragState
    let dynamicTypeSize: DynamicTypeSize
    let displayScale: CGFloat

    func perform(runGeneration: Int) async {
        switch scenario {
        case .idle:
            return
        case .handDragCancel:
            await runHandDragCancel()
        case .firstCardCastCold, .realCardPlay, .repeatedCardCasts, .maximumConcurrentCasts,
             .playEngineHand, .playFeedbackOnly, .playCastOnly, .playCastFaceOnly,
             .playCastMaskOnly, .playCastParticlesOnly, .playSwingOnly,
             .playStackDirect, .playRealNoCast, .playRealNoSwing, .playRealNoFeedback,
             .playStackNoSwing, .playStackNoFeedback, .playStackNoCast, .playCastHeldPose:
            await runCardCastFamily(runGeneration: runGeneration)
        case .feedbackChipsOnly, .feedbackRasterCold, .feedbackRasterWarm:
            await runFeedbackChipsOnly(runGeneration: runGeneration)
        case .feedbackReactionsOnly:
            await runFeedbackReactionsOnly(runGeneration: runGeneration)
        case .keywordBurstsOnly:
            await runKeywordBurstsOnly(runGeneration: runGeneration)
        case .denseFeedback:
            await runDenseFeedback(runGeneration: runGeneration)
        case .turnTransition:
            runTurnTransition()
        case .ultimateCinematic:
            runUltimate(runGeneration: runGeneration)
        case .audioPlayback:
            await runAudioPlayback()
        case .combinedWorstCase:
            await runCombinedWorstCase(runGeneration: runGeneration)
        }
    }

    private func runCardCastFamily(runGeneration: Int) async {
        switch scenario {
        case .firstCardCastCold, .playCastOnly:
            appendCast()
        case .realCardPlay, .playRealNoCast, .playRealNoSwing, .playRealNoFeedback:
            await runRealCardPlay()
        case .playEngineHand:
            runPlayEngineHand()
        case .playFeedbackOnly:
            injectFeedback(runGeneration: runGeneration, batch: 0)
        case .playCastFaceOnly:
            appendCast(workload: .faceOnly, particleCount: 0)
        case .playCastMaskOnly:
            appendCast(workload: .maskOnly, particleCount: 0)
        case .playCastParticlesOnly:
            appendCast(workload: .particlesOnly)
        case .playCastHeldPose:
            appendCast(heldPose: true)
        case .playSwingOnly:
            runPlaySwingOnly()
        case .playStackDirect, .playStackNoSwing, .playStackNoFeedback, .playStackNoCast:
            runPlayStack(for: scenario)
        case .repeatedCardCasts:
            for _ in 0 ..< 6 {
                appendCast()
                try? await Task.sleep(for: .milliseconds(700))
            }
        case .maximumConcurrentCasts:
            let count = max(1, TrinketMotion.Battle.maxConcurrentCardCasts)
            for _ in 0 ..< count {
                appendCast(enforceProductionCap: false)
            }
        default:
            return
        }
    }

    func prepareFeedbackRasters(runGeneration: Int) {
        let items = CombatFeedbackPresenter.makeItems(
            from: feedbackEvents(runGeneration: runGeneration, batch: 0),
            at: .now,
            stagger: 0.02
        )
        prepareFeedbackRasters(for: items)
    }

    private func runHandDragCancel() async {
        guard let cardID = battleSession.hand.first?.id else { return }
        for step in 0 ..< 180 {
            guard !Task.isCancelled else { return }
            let phase = Double(step % 60) / 60.0
            let lift = sin(phase * .pi)
            forcedDrag.set(
                cardID: cardID,
                translation: CGSize(width: sin(phase * 2 * .pi) * 28, height: -lift * 210)
            )
            try? await Task.sleep(for: .milliseconds(16))
        }
        forcedDrag.clear()
    }

    private func runDenseFeedback(runGeneration: Int) async {
        for batch in 0 ..< 5 {
            injectFeedback(runGeneration: runGeneration, batch: batch)
            try? await Task.sleep(for: .milliseconds(650))
        }
    }

    private func injectFeedback(runGeneration: Int, batch: Int) {
        let events = feedbackEvents(runGeneration: runGeneration, batch: batch)
        // ChipBridge.publish pre-composes; avoid a duplicate prepare that masks
        // publish-path work in dense/production-like scenarios.
        battleSession.recordFeedbackEvents(events, at: .now, stagger: 0.02)
    }

    private func runFeedbackChipsOnly(runGeneration: Int) async {
        for batch in 0 ..< 5 {
            let date = Date.now
            let events = feedbackEvents(runGeneration: runGeneration, batch: batch)
            // Production publish path: append + bridge note without reactions/SFX.
            // Pre-compose happens inside ChipBridge.publish (same as live Battle).
            let items = CombatFeedbackPresenter.makeItems(
                from: events,
                at: date,
                stagger: 0.02
            )
            battleSession.activeFeedbackItems.append(contentsOf: items)
            // Chips-only skips multimodal presentation; mark presented so the
            // prune loop does not catch-up multimodal work mid-measurement.
            for item in items {
                battleSession.presentedFeedbackIDs.insert(item.id)
            }
            battleSession.scheduleFeedbackPruneIfNeeded(at: date)
            battleSession.onFeedbackItemsChanged?(.insert(items))
            try? await Task.sleep(for: .milliseconds(650))
        }
    }

    private func prepareFeedbackRasters(for items: [CombatFeedbackItem]) {
        let itemsByTarget = Dictionary(grouping: items, by: \.targetID)
        for targetItems in itemsByTarget.values {
            let groups = CombatFeedbackOverlayPolicy.visibleActionGroups(from: targetItems)
            for canvasItem in CombatFeedbackOverlayPolicy.canvasItems(from: groups) {
                _ = CombatFeedbackRasterPool.shared.raster(
                    for: canvasItem,
                    dynamicTypeSize: dynamicTypeSize,
                    displayScale: displayScale
                )
            }
        }
    }

    private func runFeedbackReactionsOnly(runGeneration: Int) async {
        guard let state = battleSession.state else { return }
        let targets = [state.enemy, state.hero, state.companion]
        for batch in 0 ..< 5 {
            for (index, target) in targets.enumerated() {
                battleSession.publishHitReaction(
                    CombatantHitReaction(
                        id: runGeneration * 10000 + batch * 100 + index,
                        kind: .damage
                    ),
                    for: target.id
                )
            }
            try? await Task.sleep(for: .milliseconds(650))
        }
    }

    private func runKeywordBurstsOnly(runGeneration: Int) async {
        guard let state = battleSession.state else { return }
        let targets = [state.enemy, state.hero, state.companion]
        for batch in 0 ..< 5 {
            let now = Date.now
            for (index, target) in targets.enumerated() {
                let id = runGeneration * 10000 + batch * 100 + index
                battleSession.keywordBurstsByTargetID[target.id] = [KeywordBurstRequest(
                    id: id,
                    keyword: .burn,
                    particleCount: 8,
                    seed: id,
                    availableAt: now,
                    expiresAt: now.addingTimeInterval(0.45)
                )]
            }
            battleSession.noteBurstPresentationChanged()
            try? await Task.sleep(for: .milliseconds(650))
        }
    }

    private func feedbackEvents(runGeneration: Int, batch: Int) -> [ActionEvent] {
        Self.feedbackEvents(
            battleSession: battleSession,
            runGeneration: runGeneration,
            batch: batch
        )
    }

    static func feedbackEvents(
        battleSession: BattleSession,
        runGeneration: Int,
        batch: Int
    ) -> [ActionEvent] {
        guard let state = battleSession.state else { return [] }
        let targets = [state.enemy, state.hero, state.companion]
        let keywords: [Keyword] = [.physical, .burn, .freeze, .holy, .poison, .block]
        let baseID = runGeneration * 10000 + batch * 100
        return (0 ..< 9).map { index in
            let target = targets[index % targets.count]
            return ActionEvent(
                id: baseID + index,
                kind: index.isMultiple(of: 3) ? .effect : .abilityDamage,
                effectKind: index.isMultiple(of: 3) ? .shieldApplied : nil,
                actorID: state.hero.id,
                actorName: state.hero.name,
                abilityID: "performance-feedback",
                abilityName: "Performance Feedback",
                targetID: target.id,
                targetName: target.name,
                amount: 8 + index,
                keyword: keywords[index % keywords.count]
            )
        }
    }

    private func runTurnTransition() {
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.turnTransition,
            detail: "scenario=\(scenario.rawValue) phase=end-turn"
        )
        _ = battleSession.endTurn(
            journey: appState.journey,
            homestead: appState.homestead
        )
    }

    private func runUltimate(runGeneration: Int) {
        guard let hero = battleSession.state?.hero else { return }
        let event = ActionEvent(
            id: runGeneration * 10000 + 9000,
            kind: .ability,
            actorID: hero.id,
            actorName: hero.name,
            abilityID: hero.abilityLoadout.ultimate?.id ?? "performance-ultimate",
            abilityName: hero.abilityLoadout.ultimate?.name ?? "Performance Ultimate",
            abilityTier: .ultimate,
            targetID: battleSession.state?.enemy.id ?? "enemy",
            targetName: battleSession.state?.enemy.name ?? "Enemy",
            amount: 24,
            keyword: hero.abilityLoadout.ultimate?.keywords.first ?? .holy
        )
        battleSession.beginCinematic(from: event, at: .now)
    }

    private func runAudioPlayback() async {
        let clipIDs = [SFXID.hit, SFXID.hitBurn, SFXID.hitFreeze, SFXID.heal, SFXID.block]
        for index in 0 ..< 20 {
            let clipID = clipIDs[index % clipIDs.count]
            BattleFramePacingSignposts.event(
                BattleFramePacingSignposts.Name.audioPlayback,
                detail: "scenario=\(scenario.rawValue) clip=\(clipID)"
            )
            battleSession.playSFX(clipID)
            try? await Task.sleep(for: .milliseconds(180))
        }
    }

    private func runCombinedWorstCase(runGeneration: Int) async {
        guard let cardID = battleSession.hand.first?.id else { return }
        for step in 0 ..< 5 {
            // Production spectacle policy makes an Ultimate exclusive and defers its
            // combat feedback until collapse. Do not manufacture an impossible overlap
            // between the full-screen cinematic, a cast, and dense feedback here.
            if step == 3 {
                forcedDrag.clear()
                runUltimate(runGeneration: runGeneration)
                try? await Task.sleep(for: .milliseconds(700))
                continue
            }
            forcedDrag.set(
                cardID: cardID,
                translation: CGSize(width: step.isMultiple(of: 2) ? 24 : -24, height: -150)
            )
            appendCast()
            // injectFeedback publishes chips and fires multimodal on the same impact frame.
            injectFeedback(runGeneration: runGeneration, batch: step)
            if step == 2 {
                runTurnTransition()
            }
            try? await Task.sleep(for: .milliseconds(700))
        }
        forcedDrag.clear()
    }
}

@MainActor
func battlePerformancePrimeChipHostPipeline(
    scenario: BattlePerformanceScenario,
    battleSession: BattleSession,
    runGeneration: Int
) async {
    switch scenario {
    case .feedbackChipsOnly, .feedbackRasterCold, .feedbackRasterWarm, .denseFeedback,
         .combinedWorstCase, .turnTransition, .realCardPlay, .playFeedbackOnly,
         .playRealNoCast, .playRealNoSwing, .playRealNoFeedback,
         .playStackDirect, .playStackNoSwing, .playStackNoCast:
        break
    default:
        return
    }
    battleSession.scheduleFeedbackPruneIfNeeded(at: .now)
    CombatFeedbackRasterPool.shared.prewarmPacedPrepareLoop()
    CombatFeedbackRasterUIView.prewarmMotionClock()
    let date = Date.now
    let events = BattlePerformanceScenarioDriver.feedbackEvents(
        battleSession: battleSession,
        runGeneration: runGeneration,
        batch: 0
    )
    let items = CombatFeedbackPresenter.makeItems(from: events, at: date, stagger: 0)
    battleSession.activeFeedbackItems.append(contentsOf: items)
    battleSession.scheduleFeedbackPruneIfNeeded(at: date)
    battleSession.onFeedbackItemsChanged?(.insert(items))
    try? await Task.sleep(for: .milliseconds(200))
    battleSession.clearFeedback()
    CombatFeedbackChipBridge.publish(.reset)
    try? await Task.sleep(for: .milliseconds(50))
}
#endif
