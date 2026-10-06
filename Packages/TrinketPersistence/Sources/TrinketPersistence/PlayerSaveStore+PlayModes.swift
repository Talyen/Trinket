import TrinketContent
import TrinketCore

@MainActor
public extension PlayerSaveStore {
    @discardableResult
    func enterLabyrinth() -> Bool {
        persistBatch(logging: "Failed to enter Labyrinth") { save in
            LabyrinthCompletion.enter(save: &save, access: contentAccess)
        }
    }

    @discardableResult
    func prepareContracts(
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> Bool {
        persistBatch(logging: "Failed to open Contracts") { save in
            save.contracts.ensureBoard(eligibleModifiers: ContractsCompletion.eligibleModifiers(in: save.inventory), makeOffer: makeOffer)
        }
    }

    @discardableResult
    func refreshContracts(
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> Bool {
        persistBatch(logging: "Failed to refresh Contracts") { save in
            _ = save.contracts.refresh(eligibleModifiers: ContractsCompletion.eligibleModifiers(in: save.inventory), makeOffer: makeOffer)
        }
    }

    @discardableResult
    func prepareVoyage() -> Bool {
        persistBatch(logging: "Failed to save Voyage") { save in
            save.voyage.ensureBoard(access: contentAccess, eligibleModifiers: RewardOwnership(save).eligibleModifiers)
            Self.refreshVoyageRecruits(save: &save, access: contentAccess)
        }
    }

    @discardableResult
    func refreshVoyage() -> Bool {
        persistBatch(logging: "Failed to save Voyage") { save in
            save.voyage.refresh(access: contentAccess, eligibleModifiers: RewardOwnership(save).eligibleModifiers)
        }
    }

    @discardableResult
    func embarkVoyage(offerID: String) -> Bool {
        persistBatch(logging: "Failed to save Voyage") { save in
            _ = save.voyage.embark(
                offerID: offerID, eligibleRecruitEventIDs: save.roster.eligibleRecruitEventIDs(access: contentAccess),
                access: contentAccess, eligibleRewards: RewardOwnership(save).eligibleModifiers,
            )
        }
    }

    @discardableResult
    func abandonVoyage(runID: String) -> Bool {
        persistBatch(logging: "Failed to save Voyage") { save in
            _ = save.voyage.abandon(runID: runID, access: contentAccess, eligibleModifiers: RewardOwnership(save).eligibleModifiers)
        }
    }

    @discardableResult
    func dismissCompletedVoyage() -> Bool {
        persistBatch(logging: "Failed to save Voyage") { $0.voyage.dismissCompleted() }
    }
}

extension PlayerSaveStore {
    static func refreshVoyageRecruits(save: inout PlayerSave, access: ContentAccessPolicy) {
        guard let run = save.voyage.activeRun else { return }
        let eligible = save.roster.eligibleRecruitEventIDs(access: access)
        for node in run.nodes where node.type == .recruit && !node.isCleared {
            if let id = node.recruitEventID, eligible.contains(id) {
                continue
            }
            save.voyage.updateNode(runID: run.id, nodeID: node.id) { updated in
                if let eventID = eligible.min() {
                    updated.recruitEventID = eventID
                } else {
                    updated.type = .mystery
                    updated.recruitEventID = nil
                    updated.modifierIDs = NodeModifierCatalog.modifierIDs(
                        for: .mystery,
                        enemyID: nil,
                        worldSeed: run.offer.seed,
                        nodeID: node.id,
                        affinityKeywords: VoyageCatalog.affinityKeywords(chapterID: run.offer.chapterID),
                    )
                }
            }
        }
    }
}
