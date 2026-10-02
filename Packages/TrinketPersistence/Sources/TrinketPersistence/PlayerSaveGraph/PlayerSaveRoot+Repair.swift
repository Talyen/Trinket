import TrinketContent
import TrinketCore

extension PlayerSaveRoot {
    func repairSlices(for sanitizedSave: PlayerSave, currentSave: PlayerSave? = nil) -> PlayerSaveSlice {
        var slices = PlayerSaveSlice.changed(between: currentSave ?? toPlayerSave(), and: sanitizedSave)
        for section in PlayerSaveSection.allCases where needsGraphRepair(section, for: sanitizedSave) {
            slices.insert(section.slice)
        }
        return slices
    }

    /// Value mapping drops invalid child rows and normalizes payloads; these
    /// checks find graph repairs that value comparison alone cannot see.
    private func needsGraphRepair(_ section: PlayerSaveSection, for sanitizedSave: PlayerSave) -> Bool {
        switch section {
        case .root:
            StarterSelectionPhase(rawValue: starterSelectionPhaseRawValue) == nil
        case .journey:
            journey == nil || hasDuplicateKeys(journey?.stages ?? [], key: \.stageID)
        case .roster:
            roster == nil || rosterHasDuplicateChildren || roster?.hasDanglingRosterChildren == true
        case .inventory:
            inventory == nil || inventoryHasDuplicateChildren || hasDanglingInventoryChildren
        case .homestead:
            homestead == nil || homesteadHasDuplicateChildren || hasDanglingHomesteadChildren
        case .spires:
            spires == nil || hasDuplicateKeys(spires?.floors ?? [], key: \.spireID)
                || (spires?.floors ?? []).contains(where: \.spireID.isEmpty)
        case .labyrinth:
            labyrinth == nil
        case .contracts:
            if let payload = contractsPayload {
                payload != sanitizedSave.contracts.encodedPayload
                    && PlayerContractsState.decodePayload(payload) == sanitizedSave.contracts
            } else {
                false
            }
        case .voyage:
            if let payload = voyagePayload {
                !sanitizedSave.voyage.isUnreadable
                    && payload != sanitizedSave.voyage.encodedPayload
                    && PlayerVoyageState.decodePayload(payload) == sanitizedSave.voyage
            } else {
                false
            }
        }
    }

    private var rosterHasDuplicateChildren: Bool {
        guard let roster else { return false }
        return hasDuplicateKeys(roster.unlockedCombatants ?? [], key: \.compositeKey)
            || hasDuplicateKeys(roster.progressions ?? [], key: \.combatantID)
            || hasDuplicateKeys(roster.abilityLoadouts ?? [], key: \.combatantID)
            || hasDuplicateKeys(roster.equipmentLoadouts ?? [], key: \.combatantID)
            || (roster.equipmentLoadouts ?? []).contains {
                hasDuplicateKeys($0.slots ?? [], key: \.slotID)
            }
            || hasDuplicateKeys(roster.talentLoadouts ?? [], key: \.combatantID)
            || (roster.talentLoadouts ?? []).contains {
                hasDuplicateKeys($0.unlockedNodes ?? [], key: \.nodeID)
            }
    }

    private var inventoryHasDuplicateChildren: Bool {
        guard let inventory else { return false }
        return hasDuplicateKeys(inventory.items ?? [], key: \.id)
            || (inventory.items ?? []).contains {
                hasDuplicateKeys($0.affixes ?? [], key: \.id)
            }
    }

    private var homesteadHasDuplicateChildren: Bool {
        guard let homestead else { return false }
        return hasDuplicateKeys(homestead.resources ?? [], key: \.resourceID)
            || hasDuplicateKeys(homestead.pendingProduction ?? [], key: \.resourceID)
            || hasDuplicateKeys(homestead.nodeTiers ?? [], key: \.nodeID)
    }

    /// Rows the value read drops silently: unknown inventory base types
    /// (`restoredItem` returns nil) and unknown/`.gold` homestead rows.
    /// Value-level `changed()` never sees them, so repair must force the
    /// slice rewrite; the next `update(from:)` reconcile deletes orphans.
    private var hasDanglingInventoryChildren: Bool {
        guard let items = inventory?.items else { return false }
        return items.contains { GameContent.itemBaseType(matching: $0.baseTypeID) == nil }
    }

    private var hasDanglingHomesteadChildren: Bool {
        guard let homestead else { return false }
        if (homestead.resources ?? []).contains(where: {
            $0.resourceID == HomesteadResource.gold.rawValue
                || HomesteadResource.resolving(resourceID: $0.resourceID) == nil
        }) {
            return true
        }
        if (homestead.pendingProduction ?? []).contains(where: {
            HomesteadResource.resolving(resourceID: $0.resourceID) == nil
        }) {
            return true
        }
        if (homestead.nodeTiers ?? []).contains(where: {
            HomesteadNodeID.resolving(nodeID: $0.nodeID) == nil
        }) {
            return true
        }
        return false
    }
}

private func hasDuplicateKeys<Element, Key: Hashable>(
    _ values: [Element],
    key: (Element) -> Key,
) -> Bool {
    var seen: Set<Key> = []
    return values.contains { !seen.insert(key($0)).inserted }
}
