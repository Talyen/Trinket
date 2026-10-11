import TrinketContent

/// Save-backed event identity. Presentation never supplies executable effects.
public extension EncounterIdentity {
    func mysteryEvent(
        in save: PlayerSave, forcedEventID: String? = nil, access: ContentAccessPolicy = .fullGame,
    ) -> MysteryEvent? {
        guard isCurrent(in: save) else { return nil }
        let pinnedID = pinnedMysteryEventID(in: save)
        var pinned = pinnedID.flatMap { GameContent.mysteryEvent(matching: $0) ?? GameContent.recruitEvent(matching: $0) }
        guard pinnedID == nil || pinned != nil else { return nil }
        // A committed pin can outlive an interrupted recruitment while another
        // encounter or device unlocks that combatant. Reopen using normal substitution.
        if let id = pinned?.unlockCombatantID, isPlayable(in: save),
           save.roster.isHeroUnlocked(id) || save.roster.isCompanionUnlocked(id) {
            pinned = nil
        }
        switch location {
        case let .journey(stageID):
            guard let stage = GameContent.stage(id: stageID) else { return nil }
            switch stage.encounter {
            case .mysteryEvent, .recruit: break
            default: return nil
            }
            if let pinned {
                return pinned
            }
            let resolved = GameContent.resolveRecruitStage(
                stage, worldSeed: save.worldSeed,
                unlockedHeroIDs: save.roster.unlockedHeroIDs,
                unlockedCompanionIDs: save.roster.unlockedCompanionIDs, access: access,
            )
            return GameContent.resolveJourneyMysteryEvent(
                stage: resolved, worldSeed: save.worldSeed, forcedEventID: forcedEventID,
                context: .journey(
                    chapterNumber: stage.chapterNumber, inventory: save.inventory,
                    corruptionAltarCooldownRemaining: save.corruptionAltarCooldownRemaining,
                ),
            )
        case let .labyrinth(nodeID):
            guard let node = save.labyrinth.nodes[nodeID], node.type == .mystery || node.type == .recruit else { return nil }
            if let pinned {
                return pinned
            }
            return nodeMysteryEvent(
                nodeID: nodeID, isRecruit: node.type == .recruit, recruitEventID: node.recruitEventID,
                forcedEventID: forcedEventID, save: save, access: access,
            )
        case let .voyage(runID, nodeID):
            guard let node = save.voyage.node(runID: runID, nodeID: nodeID),
                  node.type == .mystery || node.type == .recruit else { return nil }
            if let pinned {
                return pinned
            }
            return nodeMysteryEvent(
                nodeID: nodeID, isRecruit: node.type == .recruit, recruitEventID: node.recruitEventID,
                forcedEventID: forcedEventID, save: save, access: access,
            )
        }
    }

    private func nodeMysteryEvent(
        nodeID: String, isRecruit: Bool, recruitEventID: String?, forcedEventID: String?,
        save: PlayerSave, access: ContentAccessPolicy,
    ) -> MysteryEvent {
        if isRecruit, forcedEventID == nil {
            return GameContent.resolveRecruitEncounter(
                configuredEventID: recruitEventID, encounterID: nodeID, worldSeed: save.worldSeed,
                unlockedHeroIDs: save.roster.unlockedHeroIDs,
                unlockedCompanionIDs: save.roster.unlockedCompanionIDs, access: access,
            ).event
        }
        return GameContent.resolveLabyrinthMysteryEvent(
            nodeID: nodeID, worldSeed: save.worldSeed, forcedEventID: forcedEventID,
            context: .labyrinth(inventory: save.inventory, corruptionAltarCooldownRemaining: save.corruptionAltarCooldownRemaining),
        )
    }

    internal func pinnedMysteryEventID(in save: PlayerSave) -> String? {
        switch location {
        case let .journey(stageID): save.journey.pinnedMysteryEventIDs[stageID]
        case let .labyrinth(nodeID): save.labyrinth.nodes[nodeID]?.mysteryEventID
        case let .voyage(runID, nodeID): save.voyage.node(runID: runID, nodeID: nodeID)?.mysteryEventID
        }
    }

    internal func pinMysteryEvent(_ eventID: String, save: inout PlayerSave) {
        switch location {
        case let .journey(stageID): save.journey.pinnedMysteryEventIDs[stageID] = eventID
        case let .labyrinth(nodeID): save.labyrinth.nodes[nodeID]?.mysteryEventID = eventID
        case let .voyage(runID, nodeID): save.voyage.updateNode(runID: runID, nodeID: nodeID) { $0.mysteryEventID = eventID }
        }
    }
}

public struct PreparedMysteryEncounter {
    public let event: MysteryEvent
    public let offers: [MysteryOffer]
}
