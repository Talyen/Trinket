import BattleEngine
import Darwin
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistenceTestSupport
@testable import TrinketAppState
@testable import TrinketBattleFeature
@testable import TrinketPersistence

@MainActor
final class PlaythroughCareer {
    let scenario: PlaythroughScenario
    let context: AppTestContext
    let journal: PlaythroughJournal
    var app: AppState?
    var summary = PlaythroughSummary()
    var combatRandom: SeededRandomNumberGenerator
    var policyRandom: SeededRandomNumberGenerator
    var lastDrawID = 0
    var launchSeed: UInt64 = 0
    var date: Date
    var sequence = 0
    var crashAfter: Int?
    var crashOnSettlement = false
    var seenCards: Set<Int> = []
    var observedBattleID: UUID?
    var currentBattleEncounterID: String?

    var state: AppState {
        guard let app else { preconditionFailure("Career is closed") }
        return app
    }

    var play: PlaySession {
        state.play
    }

    var store: PlayerSaveStore {
        state.playerSave
    }

    var battle: BattleSession {
        guard let battle = context.lastBattle else { preconditionFailure("Career has no battle runtime") }
        return battle
    }

    var snapshot: CloudSaveSnapshot {
        PlaythroughJournal.semantic(store.currentSave)
    }

    init(scenario: PlaythroughScenario, output: URL) throws {
        guard scenario.version == 1, scenario.worldSeed > 0,
              (1 ... 1000).contains(scenario.attempts), (1 ... 100000).contains(scenario.maxActions),
              (1 ... 1000).contains(scenario.maxTurns), (1 ... 10000).contains(scenario.maxSteps),
              (1024 ... 256 * 1024 * 1024).contains(scenario.maxArtifactBytes),
              scenario.startDate.timeIntervalSince1970.isFinite,
              scenario.sessionSeconds.isFinite, scenario.sessionSeconds >= 0,
              ["greedy-v1", "setupAware-v1", "random-v1", "rotation-v1"].contains(scenario.policy) else {
            throw PlaythroughFailure.unsupported("scenario schema or bounds")
        }
        self.scenario = scenario
        date = scenario.startDate
        combatRandom = SeededRandomNumberGenerator(seed: scenario.combatSeed)
        policyRandom = SeededRandomNumberGenerator(seed: scenario.policySeed)
        context = try AppTestContext(directoryURL: output.appendingPathComponent("store"))
        journal = try PlaythroughJournal(directory: output, scenario: scenario)
        var initial = PlayerSave.fresh
        initial.worldSeed = scenario.worldSeed
        initial.modifiedAt = scenario.startDate
        try SaveTestSupport.writeRoot(initial, to: SaveTestSupport.makeStoreURL(directoryURL: context.directoryURL))
        try FileManager.default.copyItem(at: context.directoryURL, to: output.appendingPathComponent("checkpoint"))
        try open()
        guard store.starterSelection.phase == .chooseHero,
              !store.isCloudSyncEnabled,
              store.journey.completedStageIDs.isEmpty else {
            throw PlaythroughFailure.invariant("fresh onboarding inputs")
        }
    }

    func open() throws {
        let save = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let runtime = BattleSession(
            autoEndTurnDelay: 3600,
            outcomePresentationDelayOverride: 0,
            partyCelebrateDelayOverride: 0,
            ultimateInFrameDurationOverride: 0,
            presentationEnvironment: .silent,
        )
        context.progressionDate = { [weak self] in self?.date ?? .distantPast }
        app = try context.makeAppState(
            environment: context.makeOnboardingEnvironment(),
            playerSave: save, battleRuntime: runtime,
            contentAccess: scenario.fullAccess ? .fullGame : .free,
        )
        play.battleLaunch.nextCombatSeed = { [weak self] in self?.launchSeed ?? 0 }
        play.encounters.currentDate = { [weak self] in self?.date ?? .distantPast }
        try checkInvariants()
    }

    func close() {
        app?.play.clearTransientState()
        app = nil
    }

    func checkInvariants() throws {
        guard !store.isCloudSyncEnabled, !store.usesMemoryFallback,
              !store.isPersistenceDegraded, !store.isRetryingSaveAction,
              store.roster.gold >= 0,
              !store.labyrinth.isMapPayloadUnreadable,
              !store.currentSave.hasDomainDifference(from: store.root.toPlayerSave()),
              !store.currentSave.hasDomainDifference(from: PlayerSaveSanitizer.sanitize(store.currentSave)) else {
            throw PlaythroughFailure.invariant("save graph, bounds, repair or persistence state")
        }
        if let engine = battle.engineState {
            guard [engine.roster.hero, engine.roster.companion, engine.roster.enemy].allSatisfy({
                $0.currentHealth >= 0 && $0.currentHealth <= $0.maxHealth
            }) else { throw PlaythroughFailure.invariant("combat Health bounds") }
        }
        let ids = store.inventory.items.map(\.id)
        guard Set(ids).count == ids.count else { throw PlaythroughFailure.invariant("duplicate item identities") }
    }

    var battleObservation: PlaythroughBattleObservation? {
        guard let engine = battle.engineState else { return nil }
        return PlaythroughBattleObservation(
            turn: engine.turnCount,
            health: [engine.roster.hero.currentHealth, engine.roster.companion.currentHealth, engine.roster.enemy.currentHealth],
            hand: engine.hand.cards.map(\.id),
            playable: engine.hand.cards.filter { battle.isCardPlayable($0) }.map(\.id),
            outcome: String(describing: battle.outcome),
        )
    }

    func observeCards() {
        guard let config = battle.activeBattle, let engine = battle.engineState else { return }
        if observedBattleID != config.id {
            observedBattleID = config.id
            if VictoryRewardApplier.isBoss(enemyID: config.enemy?.id) {
                summary.bossAttempts += 1
            }
            seenCards = []
            lastDrawID = 0
        }
        summary.cardsDrawn += engine.nextCardID - lastDrawID
        lastDrawID = engine.nextCardID
        let cards = Set((engine.hand.cards + engine.hand.buffer).map(\.id))
        summary.cardsObserved += cards.subtracting(seenCards).count
        seenCards.formUnion(cards)
        summary.playableObservations += engine.hand.cards.count(where: { battle.isCardPlayable($0) })
    }

    func perform(_ action: PlaythroughAction) async throws {
        guard sequence < scenario.maxActions else { throw PlaythroughFailure.budget("actions") }
        sequence += 1
        try journal.append(.init(sequence: sequence, action: action, state: snapshot, result: nil, battle: battleObservation))
        play.encounters.mysteryRandom = SeededRandomNumberGenerator(seed: scenario.worldSeed ^ UInt64(sequence) ^ 0x4954_454D)
        var offerRandom = SeededRandomNumberGenerator(seed: scenario.worldSeed ^ UInt64(sequence) ^ 0x434F_4E54)
        var offerIndex = 0
        let prefix = "playthrough-\(scenario.worldSeed)-\(sequence)"
        play.contracts.makeOffer = { difficulty, excluded, eligibleModifiers in
            offerIndex += 1
            return ContractGenerator.makeOffer(
                difficulty: difficulty, excludingEnemyIDs: excluded, eligibleModifiers: eligibleModifiers, using: &offerRandom,
                id: "\(prefix)-\(offerIndex)",
            )
        }
        do {
            let goldBefore = store.roster.gold
            try await execute(action)
            summary.goldEarned += max(0, store.roster.gold - goldBefore)
            summary.goldSpent += max(0, goldBefore - store.roster.gold)
            if case .card = action {
                summary.cardsChosen += 1
            }
            battle.cancelPendingAutoEnd()
            observeCards()
            try checkInvariants()
            let isSettlement = if case .victory = action {
                true
            } else {
                false
            }
            if crashAfter == sequence || (crashOnSettlement && isSettlement) {
                // Explicit opt-in worker fault: no defer, save flush, or teardown.
                try Data("{\"sequence\":\(sequence)}".utf8).write(
                    to: journal.directory.appendingPathComponent("interrupted.json"),
                    options: .atomic,
                )
                _exit(86)
            }
            try journal.append(.init(sequence: sequence, action: action, state: snapshot, result: "committed", battle: battleObservation))
            summary.actions = sequence
        } catch {
            try journal.append(.init(
                sequence: sequence,
                action: action,
                state: snapshot,
                result: String(describing: error),
                battle: battleObservation,
            ))
            throw error
        }
    }

    func run(reload: Bool) async throws -> CloudSaveSnapshot {
        let started = ContinuousClock.now
        defer { close() }
        do {
            try await perform(.starterHero(scenario.heroID))
            try await perform(.starterCompanion(scenario.companionID))
            for _ in 0 ..< scenario.maxSteps {
                if summary.outcomes.count == scenario.attempts {
                    summary.termination = "completedObjective"
                    summary.wallSeconds = Double(started.duration(to: .now).components.attoseconds) / 1e18
                        + Double(started.duration(to: .now).components.seconds)
                    recordPeakMemory()
                    try journal.finish(summary)
                    return snapshot
                }
                if try await resolvePendingChoice() {
                    continue
                }
                try await enterNextEncounter()
                guard let launched = battle.activeBattle else { continue }
                try require(launched.hero.unlockedTalents == store.roster.unlockedTalents(for: launched.hero.combatant), "launch talents")
                try require(
                    launched.hero.equipmentLoadout == store.roster.equipmentLoadout(for: launched.hero.combatant),
                    "launch equipment",
                )
                try await fight()
                if scenario.invest {
                    try await invest()
                }
                try await perform(.collect(date.addingTimeInterval(scenario.sessionSeconds)))
                summary.simulatedSeconds += scenario.sessionSeconds
                if reload {
                    try await perform(.reopen)
                }
            }
            throw PlaythroughFailure.budget("career steps")
        } catch {
            summary.termination = (error as? PlaythroughFailure)?.termination ?? "persistenceFailure"
            summary.diagnostic = String(describing: error)
            recordPeakMemory()
            try journal.finish(summary)
            throw error
        }
    }

    func fight(settle: Bool = true) async throws {
        while battle.outcome == nil {
            guard let engine = battle.engineState else { throw PlaythroughFailure.invariant("missing battle") }
            guard engine.turnCount < scenario.maxTurns else { throw PlaythroughFailure.budget("battle turns") }
            guard battle.canAcceptBattleCommands else { throw PlaythroughFailure.rejected("session not ready") }
            let policy: PlayPolicy = scenario.policy == "setupAware-v1" ? .setupAware : .greedy
            let choice = scenario.policy == "random-v1"
                ? engine.hand.cards.filter { battle.isCardPlayable($0) }.randomElement(using: &policyRandom)
                : policy.preferredPlayableCard(in: engine)
            if let card = choice {
                try await perform(.card(card.id))
            } else {
                try await perform(.endTurn)
            }
        }
        guard settle else { return }
        summary.turns += battle.engineState?.turnCount ?? 0
        switch battle.outcome {
        case .victory: try await perform(.victory)
        case .defeat: try await perform(.defeat(retry: false))
        case nil: throw PlaythroughFailure.invariant("unsettled battle")
        }
        while let id = play.currentPostBattleTalentCombatantID {
            try await chooseTalent(for: id)
        }
    }

    func recordPeakMemory() {
        var usage = rusage()
        if getrusage(RUSAGE_SELF, &usage) == 0 {
            summary.peakResidentBytes = Int64(usage.ru_maxrss)
        }
    }

    func chooseTalent(for id: String) async throws {
        if play.postBattleTalentConfirmationID != nil {
            try await perform(.finishTalent)
            return
        }
        let roster = store.roster
        for tree in CombatantTalentCatalog.allConfigs[id]?.trees ?? [] {
            for node in tree.nodes where tree.canUnlock(
                node: node, unlockedNodeIDs: roster.unlockedTalents(for: id),
                availablePoints: roster.availableTalentPoints(for: id),
            ) {
                try await perform(.talent(combatant: id, tree: tree.id, node: node.id))
                return
            }
        }
        throw PlaythroughFailure.unsupported("talent choice for \(id)")
    }
}
