import Foundation
import TrinketCore

private func ev(
    id: String,
    title: String,
    narrative: String,
    artID: String?,
    choices: [(id: String, label: String, effects: [MysteryEffect])]
) -> MysteryEvent {
    MysteryEvent(
        id: id,
        title: title,
        narrative: narrative,
        artID: artID,
        choices: choices.map { MysteryChoice(id: $0.id, label: $0.label, effects: $0.effects) }
    )
}

private func generatedItem(
    _ baseTypeID: String,
    guaranteedAffixIDs: [String] = []
) -> MysteryEffect {
    .gainGeneratedItem(baseTypeID: baseTypeID, guaranteedAffixIDs: guaranteedAffixIDs)
}

enum MysteryEventPool {
    static let all: [MysteryEvent] = [
        ev(
            id: "mana-berries",
            title: "Mana Berries",
            narrative: "You stumble upon a lush field of glowing Mana Berries. Their faint blue radiance pulses gently, promising restored mana.",
            artID: "mystery-mana-berries",
            choices: [
                ("harvest", "Harvest", [
                    .gainMaterial(.herbs),
                    generatedItem("sapphire_ring", guaranteedAffixIDs: ["manabound"]),
                ]),
                ("study-glow", "Study the Glow", [.gainExperience]),
            ]
        ),
        ev(
            id: "enchanted-spring",
            title: "Enchanted Spring",
            narrative: "A pool of iridescent water steams gently in the cool air. Its surface shimmers with an inviting warmth, promising restoration.",
            artID: "mystery-enchanted-spring",
            choices: [
                ("bathe", "Bathe", [.gainExperience, .gainMaterial(.herbs)]),
                ("bottle", "Bottle the Essence", [.gainMaterial(.crystal), .gainMaterial(.herbs)]),
            ]
        ),
        ev(
            id: "fungal-grotto",
            title: "Fungal Grotto",
            narrative: "Bioluminescent mushrooms pulse in the dark, their spores hanging thick in the air. The cave walls glitter with an otherworldly light.",
            artID: "mystery-fungal-grotto",
            choices: [
                ("harvest-caps", "Harvest Caps", [
                    .gainMaterial(.herbs),
                    generatedItem("emerald_ring"),
                ]),
                ("breathe-spores", "Breathe the Spores", [.gainExperience]),
            ]
        ),
        ev(
            id: "wisdom-tree",
            title: "Wisdom Tree",
            narrative: "An immense oak with a weathered face carved into its bark speaks in rustling leaves. Ancient wisdom emanates from its gnarled branches.",
            artID: "mystery-wisdom-tree",
            choices: [
                ("ask-knowledge", "Ask for Knowledge", [.gainExperience]),
                ("rest-shade", "Rest in its Shade", [.gainExperience, .gainMaterial(.herbs)]),
            ]
        ),
        ev(
            id: "fairy-ring",
            title: "Fairy Ring",
            narrative: "A circle of glowing mushrooms hums with fey energy in a moonlit clearing. The air feels thick with mischief and ancient magic.",
            artID: "mystery-fairy-ring",
            choices: [
                ("step-inside", "Step Inside", [.gainGold(25)]),
                ("pluck-cap", "Pluck a Cap", [.gainMaterial(.crystal)]),
            ]
        ),
        ev(
            id: "ancient-altar",
            title: "Ancient Altar",
            narrative: "A weathered stone altar stands beneath a shaft of light piercing the canopy. A rusted offering bowl rests before it, etched with forgotten symbols.",
            artID: "mystery-ancient-altar",
            choices: [
                ("pray", "Pray", [.gainExperience]),
                ("take-relic", "Take the Relic", [generatedItem("topaz_amulet")]),
            ]
        ),
        ev(
            id: "hidden-cache",
            title: "Hidden Cache",
            narrative: "A leather-wrapped bundle tucked between exposed roots catches your eye. Whatever is inside has been hidden here for a long time.",
            artID: "mystery-hidden-cache",
            choices: [
                ("take-coinpurse", "Take the Coinpurse", [.gainGold(20), .gainMaterial(.hide)]),
                ("claim-blade", "Claim the Blade", [generatedItem("dagger"), .gainMaterial(.hide)]),
            ]
        ),
        ev(
            id: "overgrown-temple",
            title: "Overgrown Temple",
            narrative: "Vines carpet ancient mosaic floors. A faint glow pulses from a cracked sarcophagus in the chamber beyond, hinting at preserved treasures.",
            artID: "mystery-overgrown-temple",
            choices: [
                ("loot-crypt", "Loot the Crypt", [.gainRandomItem]),
                ("read-inscriptions", "Read the Inscriptions", [.gainExperience, .gainMaterial(.crystal)]),
            ]
        ),
        ev(
            id: "abandoned-study",
            title: "Abandoned Study",
            narrative: "Dusty shelves line a circular tower room. A half-written thesis lies open on the desk, quill dried beside it centuries ago.",
            artID: "mystery-abandoned-study",
            choices: [
                ("search-scrolls", "Search the Scrolls", [generatedItem("spellbook")]),
                ("catalog-library", "Catalog the Library", [.gainExperience, .gainMaterial(.crystal)]),
            ]
        ),
        ev(
            id: "mysterious-tome",
            title: "Mysterious Tome",
            narrative: "A leather-bound book floats above a pedestal, pages turning on their own. Arcane energy crackles around it as if it has been waiting for a reader.",
            artID: "mystery-mysterious-tome",
            choices: [
                ("read", "Read Carefully", [.gainExperience]),
                ("bind-pages", "Bind the Torn Pages", [generatedItem("spellbook")]),
            ]
        ),
        ev(
            id: "crystal-geode",
            title: "Crystal Geode",
            narrative: "A massive amethyst geode splits the cave floor, its resonant hum filling the chamber with a deep, soothing vibration.",
            artID: "mystery-crystal-geode",
            choices: [
                ("chip-gems", "Chip Out Gems", [
                    .gainMaterial(.crystal),
                    generatedItem("sapphire_ring", guaranteedAffixIDs: ["manabound"]),
                ]),
                ("meditate", "Meditate in the Resonance", [.gainExperience]),
            ]
        ),
        ev(
            id: "meteorite-crash",
            title: "Meteorite Crash",
            narrative: "A smoldering crater scars the forest floor. A strange metallic rock from beyond the sky sits at its center, radiating unfamiliar energy.",
            artID: "mystery-meteorite-crash",
            choices: [
                ("pocket-fragment", "Pocket a Fragment", [
                    .gainMaterial(.iron),
                    generatedItem("ruby_amulet"),
                ]),
                ("study-impact", "Study the Impact", [.gainExperience]),
            ]
        ),
        ev(
            id: "forgotten-hoard",
            title: "Forgotten Hoard",
            narrative: "Gold coins glitter among scattered bones beside a massive, ancient skeleton. The remains of a once-great beast guard its treasure even in death.",
            artID: "mystery-forgotten-hoard",
            choices: [
                ("scoop-coins", "Scoop the Coins", [.gainGold(30), .gainMaterial(.iron)]),
                ("fashion-bone-guard", "Fashion a Bone Guard", [generatedItem("kite_shield")]),
            ]
        ),
        ev(
            id: "sacred-grove",
            title: "Sacred Grove",
            narrative: "Sunlight breaks through the canopy in golden rays. The air is thick with peace, and the ground hums with quiet vitality.",
            artID: "mystery-sacred-grove",
            choices: [
                ("bask", "Bask", [.gainExperience, .gainMaterial(.herbs)]),
                ("forage", "Forage the Undergrowth", [
                    .gainMaterial(.herbs),
                    .gainMaterial(.wood),
                    generatedItem("emerald_ring"),
                ]),
            ]
        ),
        ev(
            id: "mountain-pass",
            title: "Mountain Pass",
            narrative: "A narrow pass winds through jagged peaks. The wind howls and loose rocks scatter the path, but valuable minerals glint in the sunlight.",
            artID: "mystery-mountain-pass",
            choices: [
                ("mine-cliffside", "Mine the Cliffside", [
                    .gainMaterial(.iron),
                    .gainMaterial(.crystal),
                ]),
                ("gather-herbs", "Gather Alpine Herbs", [.gainExperience, .gainMaterial(.herbs)]),
            ]
        ),
        ev(
            id: "murky-pond",
            title: "Murky Pond",
            narrative: "A still pond reflects the gnarled trees surrounding it. Bubbles rise from its murky depths, hinting at secrets beneath the surface.",
            artID: "mystery-murky-pond",
            choices: [
                ("fish", "Fish the Depths", [.gainMaterial(.food)]),
                ("pull-reeds", "Pull Medicinal Reeds", [
                    .gainMaterial(.herbs),
                    .gainMaterial(.wood),
                    .gainExperience,
                ]),
            ]
        ),
        ev(
            id: "necromancers-offer",
            title: "The Necromancer's Offer",
            narrative: "A robed figure tends a circle of salt and bone. Without looking up, they extend a skeletal hand, offering forbidden power.",
            artID: "mystery-the-necromancers-offer",
            choices: [
                ("accept-rite", "Accept the Rite", [.gainExperience, generatedItem("staff")]),
                ("steal-salts", "Steal the Salts", [
                    .gainMaterial(.crystal),
                    generatedItem("ruby_ring"),
                ]),
            ]
        ),
        ev(
            id: "medicinal-herb-garden",
            title: "Medicinal Herb Garden",
            narrative: "Cultivated beds have run wild as medicinal herbs grow through cracked paving, rich with scent and curative promise.",
            artID: "mystery-medicinal-herb-garden",
            choices: [
                ("harvest-remedies", "Harvest Remedies", [.gainMaterial(.herbs), .gainExperience]),
                ("copy-notes", "Copy the Herbalist's Notes", [
                    .gainExperience,
                    generatedItem("emerald_amulet"),
                ]),
            ]
        ),
        ev(
            id: "crystal-garden",
            title: "Crystal Garden",
            narrative: "Faceted crystalline blooms catch stray light, chiming softly when the wind passes by. Each shard thrums with latent power.",
            artID: "mystery-crystal-garden",
            choices: [
                ("harvest-shards", "Harvest Shards", [
                    .gainMaterial(.crystal),
                    generatedItem("sapphire_amulet", guaranteedAffixIDs: ["manabound"]),
                ]),
                ("attune", "Attune to the Chime", [.gainExperience]),
            ]
        ),
        ev(
            id: "hunters-lodge",
            title: "Hunter's Lodge",
            narrative: "A deserted lodge still smells of smoke, wood, and leather. A hunter's bow and hatchet hang near the door, preserved and waiting.",
            artID: "mystery-hunters-lodge",
            choices: [
                ("take-bow", "Take the Bow", [generatedItem("shortbow"), .gainMaterial(.hide)]),
                ("take-hatchet", "Take the Hatchet", [generatedItem("hatchet"), .gainMaterial(.hide)]),
            ]
        ),
        ev(
            id: "roadside-censer",
            title: "Roadside Censer",
            narrative: "Incense smoke coils from a hanging brass censer at a fork in the path. The air tastes of sanctified ash and old vows.",
            artID: "mystery-roadside-censer",
            choices: [
                ("breathe-smoke", "Breathe the Smoke", [.gainExperience]),
                ("claim-censer", "Claim the Censer", [generatedItem("topaz_amulet")]),
            ]
        ),
        ev(
            id: "the-phoenix",
            title: "The Phoenix",
            narrative: "A single feather glows with warm radiance, asking to be reborn. Embers swirl around it as if the flame that created it still burns nearby.",
            artID: "mystery-the-phoenix",
            choices: [
                ("claim-feather", "Claim the Feather", [generatedItem("ruby_amulet")]),
                ("fan-embers", "Fan the Embers", [generatedItem("staff")]),
            ]
        ),
        ev(
            id: "the-wolf",
            title: "The Wolf",
            narrative: "A grey wolf steps from the treeline, watching you with amber eyes. It does not flee — only waits, as if deciding whether you are worth knowing.",
            artID: "mystery-the-wolf",
            choices: [
                ("study-pack", "Study the Pack", [.gainExperience]),
                ("follow-cache", "Follow to its Cache", [generatedItem("recurve_bow")]),
            ]
        ),
        ev(
            id: Self.corruptionAltarID,
            title: "Corruption Altar",
            narrative: "A cracked stone altar bleeds violet light from its seams. Offer an item and the altar remakes it without mercy — for better or worse — then seals it as Corrupted forever. You may also walk away untouched.",
            artID: "destination-corruption-altar",
            choices: [
                ("corrupt-item", "Corrupt an Item", [.corruptItem]),
                ("leave", "Leave", [.leave]),
            ]
        ),
    ]

    static let corruptionAltarID = "corruption-altar"

    static func event(matching id: String) -> MysteryEvent? {
        all.first { $0.id == id }
    }

    /// Weighted pick: Corruption Altar at 25% when chapter-eligible, inventory-eligible, and off cooldown.
    static func pickMysteryEvent(
        context: MysteryEventPickContext,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> MysteryEvent {
        let nonAltar = all.filter { $0.id != corruptionAltarID }
        let canOfferAltar = context.allowsCorruptionAltar
            && context.hasEligibleCorruptTarget
            && context.corruptionAltarCooldownRemaining == 0
        // Always consume the altar chance draw so seeded non-altar picks stay
        // stable when eligibility flips between map preview and open.
        let altarRoll = Int.random(
            in: 1 ... 100,
            using: &randomNumberGenerator
        )
        if canOfferAltar,
           altarRoll <= MysteryEventPickContext.corruptionAltarReadyChancePercent,
           let altar = event(matching: corruptionAltarID) {
            return altar
        }
        guard let event = nonAltar.randomElement(using: &randomNumberGenerator) else {
            preconditionFailure("MysteryEventPool must contain non-altar events")
        }
        return event
    }
}
