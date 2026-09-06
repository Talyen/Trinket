import Foundation
import TrinketCore

private func recruit(
    id: String,
    combatantID: String,
) -> MysteryEvent {
    MysteryEvent(
        id: id,
        title: "",
        narrative: "",
        artID: nil,
        unlockCombatantID: combatantID,
        choices: [
            MysteryChoice(
                id: "recruit",
                label: "",
                effects: [.unlockCombatant(combatantID)],
            ),
        ],
    )
}

enum RecruitEventPool {
    static let all: [MysteryEvent] = [
        recruit(
            id: "recruit-knight",
            combatantID: "knight",
        ),
        recruit(
            id: "recruit-bear",
            combatantID: "bear",
        ),
        recruit(
            id: "recruit-ranger",
            combatantID: "ranger",
        ),
        recruit(
            id: "recruit-rogue",
            combatantID: "rogue",
        ),
        recruit(
            id: "recruit-wizard",
            combatantID: "wizard",
        ),
        recruit(
            id: "recruit-warlock",
            combatantID: "warlock",
        ),
        recruit(id: "recruit-alchemist", combatantID: "alchemist"),
        recruit(id: "recruit-druid", combatantID: "druid"),
        recruit(id: "recruit-wildcard", combatantID: "wildcard"),
        recruit(
            id: "recruit-frost-whelp",
            combatantID: "frost_whelp",
        ),
        recruit(
            id: "recruit-lizard-scout",
            combatantID: "lizard_scout",
        ),
        recruit(
            id: "recruit-panther",
            combatantID: "panther",
        ),
        recruit(
            id: "recruit-phoenix",
            combatantID: "phoenix",
        ),
        recruit(
            id: "recruit-wolf",
            combatantID: "wolf",
        ),
        recruit(
            id: "recruit-golden-retriever",
            combatantID: "golden_retriever",
        ),
        recruit(
            id: "recruit-library-owl",
            combatantID: "library_owl",
        ),
        recruit(
            id: "recruit-risen-skeleton",
            combatantID: "risen_skeleton",
        ),
        recruit(
            id: "recruit-mana-moth",
            combatantID: "mana_moth",
        ),
        recruit(
            id: "recruit-pixie",
            combatantID: "pixie",
        ),
        recruit(
            id: "recruit-shield-scarab",
            combatantID: "shield_scarab",
        ),
        recruit(
            id: "recruit-fox",
            combatantID: "fox",
        ),
    ]

    static func event(matching id: String) -> MysteryEvent? {
        all.first { $0.id == id }
    }

    static func event(unlocking combatantID: String) -> MysteryEvent? {
        all.first { $0.unlockCombatantID == combatantID }
    }

    static func eligible(
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>,
        role: Combatant.Role? = nil,
    ) -> [MysteryEvent] {
        all.filter { event in
            guard let combatantID = event.unlockCombatantID else { return false }
            guard !unlockedHeroIDs.contains(combatantID),
                  !unlockedCompanionIDs.contains(combatantID)
            else { return false }
            guard let role else { return true }
            let combatant = GameContent.heroes.first { $0.id == combatantID }
                ?? GameContent.companions.first { $0.id == combatantID }
            return combatant?.role == role
        }
    }
}
