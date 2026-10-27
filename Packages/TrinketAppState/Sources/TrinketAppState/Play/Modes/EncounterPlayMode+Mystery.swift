import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

public extension EncounterPlayMode {
    func previewMysteryEvent(
        origin: PlayEncounterOrigin,
        forcedEventID: String? = nil,
    ) -> MysteryEvent? {
        origin.identity(in: playerSave.currentSave).mysteryEvent(
            in: playerSave.currentSave, forcedEventID: forcedEventID, access: playerSave.contentAccess,
        )
    }

    @discardableResult
    func beginMysteryEncounter(
        origin: PlayEncounterOrigin,
        forcedEventID: String? = nil,
    ) -> StageMapMessage? {
        playerSave.performSaveAction(key: SaveRetryKey.mysteryOpen) { [weak self] _ -> SaveActionAttempt<StageMapMessage?> in
            guard let self else { return SaveActionAttempt(nil) }
            if let restriction = playerSave.encounterAccessRestriction(for: origin) {
                return SaveActionAttempt(restriction)
            }
            guard canBeginTransientEncounter else { return SaveActionAttempt(nil) }
            isOpeningTransientEncounter = true
            defer { isOpeningTransientEncounter = false }

            guard let event = previewMysteryEvent(origin: origin, forcedEventID: forcedEventID) else {
                return SaveActionAttempt(Self.mysteryPinFailureMessage)
            }
            if let paywall = mysteryPaywallMessage(for: event) {
                return SaveActionAttempt(paywall)
            }
            let encounter = origin.identity(in: playerSave.currentSave)
            let prepared: PreparedMysteryEncounter
            switch playerSave.prepareMysteryEncounter(
                encounter: encounter, forcedEventID: forcedEventID, using: &mysteryRandom, at: currentDate(),
            ) {
            case let .committed(value): prepared = value
            case .rejected: return SaveActionAttempt(Self.mysteryPinFailureMessage)
            case let .persistFailed(error):
                return SaveActionAttempt(nil, failure: error)
            }
            guard canPublishTransientEncounter(encounter) else { return SaveActionAttempt(nil) }
            let session = MysteryEncounterSession(
                origin: origin, encounter: encounter, event: prepared.event,
                combatant: GameContent.combatant(forMysteryEvent: prepared.event),
            )
            session.installOffers(prepared.offers)
            activeMysteryEncounter = session
            guard owns(session) else {
                if activeMysteryEncounter === session {
                    activeMysteryEncounter = nil
                }
                return SaveActionAttempt(nil)
            }
            sfxPlayer.play(SFXID.mysteryEvent, volume: options.effectsVolume)
            if session.event.isRecruit {
                guard resolveMysteryChoice(session: session, choiceID: nil) else {
                    if session.isResolvingChoice {
                        return SaveActionAttempt(nil)
                    }
                    let detail = session.persistFailureMessage ?? Self.mysteryPinFailureMessage.message
                    activeMysteryEncounter = nil
                    return SaveActionAttempt(StageMapMessage(title: Self.mysteryPinFailureMessage.title, message: detail))
                }
            }
            return SaveActionAttempt(nil)
        }
    }

    /// Character paywall for mystery events that unlock combatants. Also
    /// enforced in `PlayBattleCoordinator.activateBattle` and
    /// `resolveMysteryChoice`; checked here so the paywall surfaces
    /// before any pin writes.
    private func mysteryPaywallMessage(for event: MysteryEvent) -> StageMapMessage? {
        guard let id = event.unlockCombatantID, !playerSave.contentAccess.allowsCombatant(id) else { return nil }
        return .fullGameRequired(.combatant(id))
    }

    @discardableResult
    func resolveMysteryChoice(session mysterySession: MysteryEncounterSession, choiceID: String? = nil) -> Bool {
        guard owns(mysterySession) else { return false }
        guard !mysterySession.isResolvingChoice else { return false }
        if mysteryPaywallMessage(for: mysterySession.event) != nil {
            mysterySession.markPersistFailed("This character requires Full Game. Progress is preserved.")
            return false
        }
        guard mysterySession.canResolveChoice else {
            mysterySession.markChoiceUnavailable()
            return false
        }

        return persistMysteryResolution(mysterySession, action: .choice(choiceID), at: currentDate())
    }

    @discardableResult
    func corruptMysteryItem(session mysterySession: MysteryEncounterSession, itemID: String) -> Bool {
        guard owns(mysterySession) else { return false }
        guard !mysterySession.isResolvingChoice else { return false }
        guard mysterySession.showsCorruptItemChoice,
              mysterySession.corruptibleItems.contains(where: { $0.id == itemID }) else {
            mysterySession.markChoiceUnavailable()
            return false
        }

        return persistMysteryResolution(mysterySession, action: .corruptItem(itemID), at: currentDate())
    }

    private func persistMysteryResolution(
        _ mysterySession: MysteryEncounterSession,
        action: MysteryEncounterAction,
        at date: Date,
    ) -> Bool {
        playerSave.performSaveAction(key: SaveRetryKey.mysteryResolution) { [weak self] isRetry in
            guard let self else { return SaveActionAttempt(false) }
            guard owns(mysterySession) else { return SaveActionAttempt(false) }

            mysterySession.markChoiceStarted()
            guard owns(mysterySession) else { return SaveActionAttempt(false) }
            switch playerSave.resolveMysteryEncounter(
                mysterySession.resolutionRequest, action: action, using: &mysteryRandom, at: isRetry ? currentDate() : date,
            ) {
            case let .committed(outcome):
                return SaveActionAttempt(applyMysteryOutcome(outcome, session: mysterySession))
            case .rejected:
                mysterySession.markChoiceUnavailable()
                return SaveActionAttempt(false)
            case let .persistFailed(error):
                if !error.isRetryable {
                    mysterySession.markChoiceUnavailable()
                }
                return SaveActionAttempt(false, failure: error)
            }
        }
    }

    func cancelMysteryCorruptSelection(session mysterySession: MysteryEncounterSession) {
        guard owns(mysterySession), mysterySession.showsCorruptItemChoice, !mysterySession.isResolvingChoice else {
            return
        }
        mysterySession.returnToReading()
    }

    @discardableResult
    func finishMysteryCorruptionReveal(session mysterySession: MysteryEncounterSession) -> Bool {
        guard owns(mysterySession), mysterySession.showsCorruptionReveal else {
            return false
        }
        activeMysteryEncounter = nil
        return true
    }

    @discardableResult
    func finishMysteryEncounter(session mysterySession: MysteryEncounterSession, dismiss: Bool = true) -> Bool {
        guard owns(mysterySession) else {
            return false
        }
        mysterySession.clearPersistFailure()
        guard owns(mysterySession) else { return false }
        if mysterySession.showsReward {
            if dismiss {
                activeMysteryEncounter = nil
            }
            return true
        }
        guard mysterySession.showsReveal else {
            return false
        }
        sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
        if dismiss {
            activeMysteryEncounter = nil
        }
        return true
    }

    func collectMysteryReward(session: MysteryEncounterSession) -> Bool {
        guard owns(session), session.showsReward,
              finishMysteryEncounter(session: session, dismiss: false) else { return false }
        if session.claimRewardCollectionSound() {
            sfxPlayer.play(SFXID.lootCollect, volume: options.effectsVolume)
        }
        return true
    }

    func dismissMysteryReward(session: MysteryEncounterSession) {
        guard owns(session), session.showsReward else { return }
        activeMysteryEncounter = nil
    }

    func dismissMysteryEncounter(session: MysteryEncounterSession) {
        guard owns(session) else { return }
        activeMysteryEncounter = nil
    }

    @discardableResult
    internal func applyMysteryOutcome(
        _ outcome: MysteryChoiceOutcome,
        session mysterySession: MysteryEncounterSession,
    ) -> Bool {
        guard owns(mysterySession) else { return false }
        switch outcome {
        case .dismiss:
            activeMysteryEncounter = nil
            return true
        case .reward:
            mysterySession.applyOutcome(outcome)
            sfxPlayer.play(SFXID.victory, volume: options.effectsVolume)
            return true
        case .corruptionReveal:
            let isNewReveal = !mysterySession.showsCorruptionReveal
            mysterySession.applyOutcome(outcome)
            if isNewReveal {
                sfxPlayer.play(SFXID.itemCorrupt, volume: options.effectsVolume)
            }
            return true
        case .reveal:
            mysterySession.applyOutcome(outcome)
            return true
        case .refreshedOffers:
            mysterySession.applyOutcome(outcome)
            return false
        case .selectCorruptItem:
            mysterySession.applyOutcome(outcome, inventory: playerSave.inventory)
            return true
        }
    }

    private static let mysteryPinFailureMessage = StageMapMessage(
        title: "Event Unavailable",
        message: "This event is no longer available.",
    )
}
