import Foundation
import TrinketCore

private func recruit(
    id: String,
    combatantID: String,
    title: String,
    narrative: String,
    choiceID: String,
    choiceLabel: String
) -> MysteryEvent {
    MysteryEvent(
        id: id,
        title: title,
        narrative: narrative,
        artID: nil,
        unlockCombatantID: combatantID,
        choices: [
            MysteryChoice(
                id: choiceID,
                label: choiceLabel,
                effects: [.unlockCombatant(combatantID)]
            )
        ]
    )
}

/// One-choice Recruit encounters that unlock heroes and companions.
enum RecruitEventPool {
    static let all: [MysteryEvent] = [
        recruit(
            id: "recruit-bear",
            combatantID: "bear",
            title: "Footsteps in the Brush",
            narrative: "Something broad moves between the trees, never quite stepping into the light. Calm eyes follow your party from the leaves, and a low rustle answers when you call out.",
            choiceID: "welcome",
            choiceLabel: "Offer a place by the fire."
        ),
        recruit(
            id: "recruit-ranger",
            combatantID: "ranger",
            title: "Arrows in the Canopy",
            narrative: "A bowstring hums once in the high branches. A hooded archer drops to the trail with a nod, already scanning the treeline for what you haven't noticed yet.",
            choiceID: "welcome",
            choiceLabel: "Cover our flank."
        ),
        recruit(
            id: "recruit-rogue",
            combatantID: "rogue",
            title: "A Shadow Overhead",
            narrative: "Branches stir without wind. A cloaked silhouette drops soundlessly onto the trail, returns a purse you never noticed missing, and gestures toward the dangers ahead.",
            choiceID: "welcome",
            choiceLabel: "Watch my back."
        ),
        recruit(
            id: "recruit-wizard",
            combatantID: "wizard",
            title: "Sparks Between the Trees",
            narrative: "Runes hang in the air like fireflies. A wizard finishes a gesture, snuffs the last spark between two fingers, and looks faintly impressed that you didn't run.",
            choiceID: "welcome",
            choiceLabel: "Join our circle."
        ),
        recruit(
            id: "recruit-warlock",
            combatantID: "warlock",
            title: "A Pact at Dusk",
            narrative: "Candle-smoke curls into a smiling face. A warlock closes a small ledger of names and asks, almost politely, whether yours has room for one more.",
            choiceID: "welcome",
            choiceLabel: "Seal the pact."
        ),
        recruit(
            id: "recruit-frost-whelp",
            combatantID: "frost_whelp",
            title: "A Chill in the Hollow",
            narrative: "Frost feathers the leaves. A small dragonet sneezes a puff of rime, then butts your boot as if claiming a new den.",
            choiceID: "welcome",
            choiceLabel: "Come warm up with us."
        ),
        recruit(
            id: "recruit-lizard-scout",
            combatantID: "lizard_scout",
            title: "Eyes on the Canopy",
            narrative: "A scaled scout drops a sketched map at your feet-paths you hadn't noticed, dangers neatly circled. They wait for orders.",
            choiceID: "welcome",
            choiceLabel: "Scout with the party."
        ),
        recruit(
            id: "recruit-panther",
            combatantID: "panther",
            title: "Shadow on the Game Trail",
            narrative: "Gold eyes open in the brush. The panther does not growl; it simply falls into step, matching your pace like a second silence.",
            choiceID: "welcome",
            choiceLabel: "Walk with me."
        ),
        recruit(
            id: "recruit-phoenix",
            combatantID: "phoenix",
            title: "Embers in the Clearing",
            narrative: "Ash swirls upward and becomes wings. A phoenix lands on a charred stump, leaves a warm feather in the dirt, and watches to see if you'll pick it up.",
            choiceID: "welcome",
            choiceLabel: "Rise with us."
        ),
        recruit(
            id: "recruit-golden-retriever",
            combatantID: "golden_retriever",
            title: "A Friend on the Path",
            narrative: "Something crashes through the undergrowth-wagging, muddy, triumphant-and drops a perfectly ordinary stick at your feet like treasure.",
            choiceID: "welcome",
            choiceLabel: "You're coming home."
        ),
        recruit(
            id: "recruit-library-owl",
            combatantID: "library_owl",
            title: "The Watcher at the Lectern",
            narrative: "Pages turn on their own atop a ruined lectern. From the rafters, two bright eyes study your party before a small shadow glides down beside the open book.",
            choiceID: "welcome",
            choiceLabel: "Share your wisdom."
        ),
        recruit(
            id: "recruit-risen-skeleton",
            combatantID: "risen_skeleton",
            title: "Bones That Won't Rest",
            narrative: "A skeleton sits up from the leaf litter, dusts off a cracked pauldron, and salutes with surprising manners for the recently unearthed.",
            choiceID: "welcome",
            choiceLabel: "Stand with us."
        ),
        recruit(
            id: "recruit-mana-moth",
            combatantID: "mana_moth",
            title: "Dust of Starlight",
            narrative: "A moth the size of your palm drinks light from a mana bloom. Each wingbeat leaves a shimmer that tastes like static and sugar.",
            choiceID: "welcome",
            choiceLabel: "Alight with me."
        ),
        recruit(
            id: "recruit-pixie",
            combatantID: "pixie",
            title: "Laughter in the Ring",
            narrative: "Giggles ripple around a mushroom circle. A pixie tugs your sleeve, ties a knot of glowing thread around your finger, and waits to see if you'll follow.",
            choiceID: "welcome",
            choiceLabel: "Join the mischief."
        ),
        recruit(
            id: "recruit-shield-scarab",
            combatantID: "shield_scarab",
            title: "Carapace at the Gate",
            narrative: "A scarab the size of a buckler blocks a narrow pass-not as a threat, but as a door. When you nod, it turns and takes point.",
            choiceID: "welcome",
            choiceLabel: "Guard our flank."
        )
    ]

    static func event(matching id: String) -> MysteryEvent? {
        all.first { $0.id == id }
    }

    static func event(unlocking combatantID: String) -> MysteryEvent? {
        all.first { $0.unlockCombatantID == combatantID }
    }

    /// Recruit events whose combatant is not yet unlocked.
    static func eligible(
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>
    ) -> [MysteryEvent] {
        all.filter { event in
            guard let combatantID = event.unlockCombatantID else { return false }
            return !unlockedHeroIDs.contains(combatantID) && !unlockedCompanionIDs.contains(combatantID)
        }
    }
}
