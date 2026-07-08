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

/// One-choice mystery encounters that unlock heroes and pets.
public enum RecruitMysteryEventPool {
    public static let all: [MysteryEvent] = [
        recruit(
            id: "recruit-rogue",
            combatantID: "rogue",
            title: "A Blade in the Undergrowth",
            narrative: "A figure drops from the canopy without a sound, already counting the coins on your belt. They grin, sheath a knife, and nod toward the darker trail ahead.",
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
            id: "recruit-alchemist",
            combatantID: "alchemist",
            title: "The Travelling Still",
            narrative: "Glass vials clink in a mossy clearing. An alchemist offers you a sip of something that smells like courage and bad decisions, then laughs when you hesitate.",
            choiceID: "welcome",
            choiceLabel: "Brew with us."
        ),
        recruit(
            id: "recruit-druid",
            combatantID: "druid",
            title: "Roots That Remember",
            narrative: "The forest parts around a druid as if it knows their name. Birds settle on their shoulders; the path behind them closes like a held breath.",
            choiceID: "welcome",
            choiceLabel: "Walk with the wild."
        ),
        recruit(
            id: "recruit-ranger",
            combatantID: "ranger",
            title: "The Marked Trail",
            narrative: "An arrow pins a notice to a tree: safe passage for the worthy. The ranger who fired it steps from cover, already packing a second shaft.",
            choiceID: "welcome",
            choiceLabel: "Hunt beside me."
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
            id: "recruit-wolf",
            combatantID: "wolf",
            title: "Howl at the Bend",
            narrative: "A lone howl answers your footsteps. A wolf emerges, ears forward, and bumps your hand with a muzzle that smells like rain and pine.",
            choiceID: "welcome",
            choiceLabel: "Run with the pack."
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
            title: "The Night Librarian",
            narrative: "An owl blinks from a ruined lectern, a ribbon still marking a page in a water-stained tome. It hoots once, as if grading your posture.",
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

    public static func event(matching id: String) -> MysteryEvent? {
        all.first { $0.id == id }
    }

    public static func event(unlocking combatantID: String) -> MysteryEvent? {
        all.first { $0.unlockCombatantID == combatantID }
    }

    /// Recruit events whose combatant is not yet unlocked.
    public static func eligible(
        unlockedHeroIDs: Set<String>,
        unlockedPetIDs: Set<String>
    ) -> [MysteryEvent] {
        all.filter { event in
            guard let combatantID = event.unlockCombatantID else { return false }
            return !unlockedHeroIDs.contains(combatantID) && !unlockedPetIDs.contains(combatantID)
        }
    }
}
