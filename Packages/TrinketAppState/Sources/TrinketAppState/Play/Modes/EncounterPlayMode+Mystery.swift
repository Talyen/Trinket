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
        playerSave.performSaveAction(key: SaveRetryKey.mysteryOpen) { [weak self] _ -> StageMapMessage? in
            guard let self else { return nil }
            if let restriction = playerSave.encounterAccessRestriction(for: origin) {
                return restriction
            }
            guard canBeginTransientEncounter else { return nil }

            guard let event = previewMysteryEvent(origin: origin, forcedEventID: forcedEventID) else {
                return Self.mysteryPinFailureMessage
            }
            if let paywall = mysteryPaywallMessage(for: event) {
                return paywall
            }
            let encounter = origin.identity(in: playerSave.currentSave)
            let prepared: PreparedMysteryEncounter
            switch playerSave.prepareMysteryEncounter(
                encounter: encounter, forcedEventID: forcedEventID, using: &mysteryRandom, at: currentDate(),
            ) {
            case let .committed(value): prepared = value
            case .rejected: return Self.mysteryPinFailureMessage
            case .persistFailed:
                return nil
            }
            let session = MysteryEncounterSession(
                origin: origin, encounter: encounter, event: prepared.event,
                combatant: GameContent.combatant(forMysteryEvent: prepared.event),
            )
            session.installOffers(prepared.offers)
            activeMysteryEncounter = session
            sfxPlayer.play(SFXID.mysteryEvent, volume: options.effectsVolume)
            if session.event.isRecruit {
                guard resolveActiveMysteryChoice(choiceID: nil) else {
                    if session.isResolvingChoice {
                        return nil
                    }
                    let detail = session.persistFailureMessage ?? Self.mysteryPinFailureMessage.message
                    activeMysteryEncounter = nil
                    return StageMapMessage(title: Self.mysteryPinFailureMessage.title, message: detail)
                }
            }
            return nil
        }
    }

    /// Character paywall for mystery events that unlock combatants. Also
    /// enforced in `PlayBattleCoordinator.activateBattle` and
    /// `resolveActiveMysteryChoice`; checked here so the paywall surfaces
    /// before any pin writes.
    private func mysteryPaywallMessage(for event: MysteryEvent) -> StageMapMessage? {
        guard let id = event.unlockCombatantID, !playerSave.contentAccess.allowsCombatant(id) else { return nil }
        return .fullGameRequired(.combatant(id))
    }

    @discardableResult
    func resolveActiveMysteryChoice(choiceID: String? = nil) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
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
    func corruptActiveMysteryItem(itemID: String) -> Bool {
        guard let mysterySession = activeMysteryEncounter else { return false }
        guard mysterySession.showsCorruptItemChoice, !mysterySession.isResolvingChoice,
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
        playerSave.performSaveAction(key: SaveRetryKey.mysteryResolution) { [weak self] _ in
            guard let self else { return false }
            guard activeMysteryEncounter === mysterySession else { return false }

            mysterySession.markChoiceStarted()
            switch playerSave.resolveMysteryEncounter(
                mysterySession.resolutionRequest, action: action, using: &mysteryRandom, at: date,
            ) {
            case let .committed(outcome):
                return applyMysteryOutcome(outcome, session: mysterySession)
            case .rejected:
                mysterySession.markChoiceUnavailable()
                return false
            case let .persistFailed(error):
                if !error.isRetryable {
                    mysterySession.markChoiceUnavailable()
                }
                return false
            }
        }
    }

    func cancelActiveMysteryCorruptSelection() {
        guard let mysterySession = activeMysteryEncounter, mysterySession.showsCorruptItemChoice else {
            return
        }
        mysterySession.returnToReading()
    }

    @discardableResult
    func finishActiveMysteryCorruptionReveal() -> Bool {
        guard let mysterySession = activeMysteryEncounter, mysterySession.showsCorruptionReveal else {
            return false
        }
        activeMysteryEncounter = nil
        return true
    }

    @discardableResult
    func finishActiveMysteryEncounter(dismiss: Bool = true) -> Bool {
        guard let mysterySession = activeMysteryEncounter else {
            return false
        }
        mysterySession.clearPersistFailure()
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
        guard activeMysteryEncounter === session, session.showsReward,
              finishActiveMysteryEncounter(dismiss: false) else { return false }
        if session.claimRewardCollectionSound() {
            sfxPlayer.play(SFXID.lootCollect, volume: options.effectsVolume)
        }
        return true
    }

    func dismissMysteryReward(session: MysteryEncounterSession) {
        guard activeMysteryEncounter === session, session.showsReward else { return }
        activeMysteryEncounter = nil
    }

    func dismissActiveMysteryEncounter() {
        activeMysteryEncounter = nil
    }

    @discardableResult
    internal func applyMysteryOutcome(
        _ outcome: MysteryChoiceOutcome,
        session mysterySession: MysteryEncounterSession,
    ) -> Bool {
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
