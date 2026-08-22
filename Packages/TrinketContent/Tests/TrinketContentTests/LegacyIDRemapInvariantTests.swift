import Testing
import TrinketContent

/// Every legacy-ID remap target must exist in the current catalog. A rename
/// that orphans a target fails here instead of silently degrading saves.
struct LegacyIDRemapInvariantTests {
    @Test func talentRemapTargetsAreValidNodeIDs() {
        let allValidNodeIDs = CombatantTalentCatalog.validNodeIDsByCombatantID.values.reduce(into: Set()) { result, ids in
            result.formUnion(ids)
        }
        for (legacyID, targetID) in LegacyIDRemap.talentNodeIDAliases {
            #expect(allValidNodeIDs.contains(targetID), "remap target \(targetID) (from \(legacyID)) is not a valid talent node")
        }
    }

    @Test func abilityRemapTargetsResolveInCatalog() {
        for (legacyID, targetID) in LegacyIDRemap.abilityIDAliases {
            #expect(GameContent.ability(id: targetID) != nil, "remap target \(targetID) (from \(legacyID)) does not resolve to an ability")
        }
    }

    @Test func remappedTalentNodeIDPassesThroughUnknownIDs() {
        #expect(LegacyIDRemap.remappedTalentNodeID("knight_block_t1_1") == "knight_block_t1_1")
        #expect(LegacyIDRemap.remappedAbilityID("not-a-legacy-id") == nil)
    }
}
