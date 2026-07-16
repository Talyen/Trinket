#if DEBUG
import BattleEngine
import SwiftUI
import TrinketCore
import TrinketDesignSystem

/// Explicit, test-only workload driver. It invokes production Battle presentation paths
/// and never swaps effects for cheaper test implementations.
struct BattlePerformanceScenarioHarness: View {
    let scenario: BattlePerformanceScenario
    let appState: AppState
    let battleSession: BattleSession
    let battleSize: CGSize
    let castPresentation: BattleCastPresentationState
    @Binding var forcedDrag: (cardID: Int, translation: CGSize)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    @State private var status = "ready"
    @State private var generation = 0
    @State private var task: Task<Void, Never>?

    private static let measurementDuration: Duration = .seconds(6)
    private static let measurementWarmup: Duration = .milliseconds(800)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button {
                start()
            } label: {
                Image(systemName: "play.fill")
                    .foregroundStyle(.clear)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(status == "running")
            .accessibilityIdentifier(AccessibilityID.Debug.battlePerformanceStart)

            Text(status)
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                // UIStyleCheck: allow - Hidden status probe exists only for performance UI-test automation.
                .frame(width: 1, height: 1)
                .accessibilityIdentifier(AccessibilityID.Debug.battlePerformanceStatus)
                .accessibilityValue(status)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .battleFramePacingSignpost(
            BattleFramePacingSignposts.Name.performanceScenario,
            isActive: status == "running"
        )
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private func start() {
        task?.cancel()
        generation &+= 1
        let runGeneration = generation
        status = "running"
        forcedDrag = nil
        castPresentation.reset()
        battleSession.clearFeedback()
        battleSession.clearSpectacle()
        CombatFeedbackRasterPool.shared.removeAll()
        CombatFeedbackRasterPool.shared.resetDiagnostics()
        // Keep the glyph atlas warm across scenario iterations; only composed chip
        // rasters are dropped so the first publish stays a sub-ms compose.
        prepareFeedbackRasters(runGeneration: runGeneration)
        CombatFeedbackRasterPool.shared.resetDiagnostics()
        if scenario == .feedbackRasterWarm {
            // Already prepared above; diagnostics reset again for the warm scenario.
            CombatFeedbackRasterPool.shared.resetDiagnostics()
        }
        NotificationCenter.default.post(name: FramePacingMeasurementControl.reset, object: nil)
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.performanceScenario,
            detail: "phase=start scenario=\(scenario.rawValue) run=\(runGeneration)"
        )

        task = Task { @MainActor in
            // The display-link sampler intentionally discards its first 0.75 seconds.
            // Warm it before stimulus so cold casts and other immediate work are measured.
            try? await Task.sleep(for: Self.measurementWarmup)
            guard !Task.isCancelled, runGeneration == generation else { return }
            let clock = ContinuousClock()
            let startedAt = clock.now
            await performScenario(runGeneration: runGeneration)
            let elapsed = startedAt.duration(to: clock.now)
            if elapsed < Self.measurementDuration {
                try? await Task.sleep(for: Self.measurementDuration - elapsed)
            }
            guard !Task.isCancelled, runGeneration == generation else { return }
            forcedDrag = nil
            let rasterSnapshot = CombatFeedbackRasterPool.shared.snapshot()
            status = "complete:\(scenario.rawValue):\(runGeneration)"
                + ":rasterEntries=\(rasterSnapshot.entryCount)"
                + ":rasterBytes=\(rasterSnapshot.estimatedByteCount)"
                + ":rasterHits=\(rasterSnapshot.hitCount)"
                + ":rasterBuilds=\(rasterSnapshot.buildCount)"
                + ":rasterEvictions=\(rasterSnapshot.evictionCount)"
            BattleFramePacingSignposts.event(
                BattleFramePacingSignposts.Name.performanceScenario,
                detail: "phase=complete scenario=\(scenario.rawValue) run=\(runGeneration) "
                    + "rasterEntries=\(rasterSnapshot.entryCount) rasterHits=\(rasterSnapshot.hitCount) "
                    + "rasterBytes=\(rasterSnapshot.estimatedByteCount) "
                    + "rasterBuilds=\(rasterSnapshot.buildCount) rasterEvictions=\(rasterSnapshot.evictionCount)"
            )
        }
    }

    private func performScenario(runGeneration: Int) async {
        switch scenario {
        case .idle:
            return
        case .handDragCancel:
            await runHandDragCancel()
        case .firstCardCastCold:
            appendCast()
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

    private func runHandDragCancel() async {
        guard let cardID = battleSession.hand.first?.id else { return }
        for step in 0 ..< 180 {
            guard !Task.isCancelled else { return }
            let phase = Double(step % 60) / 60.0
            let lift = sin(phase * .pi)
            forcedDrag = (
                cardID: cardID,
                translation: CGSize(width: sin(phase * 2 * .pi) * 28, height: -lift * 210)
            )
            try? await Task.sleep(for: .milliseconds(16))
        }
        forcedDrag = nil
    }

    private func appendCast(enforceProductionCap: Bool = true) {
        guard let card = battleSession.hand.first else { return }
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.cardCommit,
            detail: "scenario=\(scenario.rawValue) card=\(card.id) ability=\(card.ability.id)"
        )
        castPresentation.append(CardActivationRequest(
            artworkName: card.ability.artReference?.imageName,
            center: CGPoint(x: battleSize.width / 2, y: battleSize.height * 0.78),
            size: CGSize(width: min(132, battleSize.width * 0.34), height: min(184, battleSize.width * 0.47)),
            rotation: 0,
            verticalTilt: 0,
            scale: 1,
            keywords: card.ability.keywords
        ), enforceProductionCap: enforceProductionCap)
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
            battleSession.scheduleFeedbackPruneIfNeeded(at: date)
            battleSession.onFeedbackItemsChanged?(.insert(items))
            try? await Task.sleep(for: .milliseconds(650))
        }
    }

    private func prepareFeedbackRasters(runGeneration: Int) {
        let items = CombatFeedbackPresenter.makeItems(
            from: feedbackEvents(runGeneration: runGeneration, batch: 0),
            at: .now,
            stagger: 0.02
        )
        prepareFeedbackRasters(for: items)
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
                battleSession.hitReactionsByTargetID[target.id] = CombatantHitReaction(
                    id: runGeneration * 10000 + batch * 100 + index,
                    kind: .damage,
                    keyword: .physical
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
                forcedDrag = nil
                runUltimate(runGeneration: runGeneration)
                try? await Task.sleep(for: .milliseconds(700))
                continue
            }
            forcedDrag = (cardID: cardID, translation: CGSize(width: step.isMultiple(of: 2) ? 24 : -24, height: -150))
            appendCast()
            injectFeedback(runGeneration: runGeneration, batch: step)
            battleSession.playSFX(step.isMultiple(of: 2) ? SFXID.hitBurn : SFXID.hitFreeze)
            if step == 2 {
                runTurnTransition()
            }
            try? await Task.sleep(for: .milliseconds(700))
        }
        forcedDrag = nil
    }
}
#endif
