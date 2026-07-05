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

public enum MysteryEventPool {
    public static let all: [MysteryEvent] = [
        ev(
            id: "mana-berries",
            title: "Mana Berries",
            narrative: "You stumble upon a lush field of glowing Mana Berries. Their faint blue radiance pulses gently, promising restored mana.",
            artID: "mystery-field-of-glowing-mana-berries",
            choices: [
                ("harvest", "Harvest", [.gainMaterial(.herbs, 3), .gainItem(itemTemplateID: "ruby_ring-basic")]),
                ("study-glow", "Study the Glow", [.gainExperience(8)])
            ]
        ),
        ev(
            id: "enchanted-spring",
            title: "Enchanted Spring",
            narrative: "A pool of iridescent water steams gently in the cool air. Its surface shimmers with an inviting warmth, promising restoration.",
            artID: "mystery-pool-of-water-steams",
            choices: [
                ("bathe", "Bathe in the Spring", [.gainExperience(12), .gainMaterial(.herbs, 2)]),
                ("bottle", "Bottle the Essence", [.gainItem(itemTemplateID: "leather_armor-basic")])
            ]
        ),
        ev(
            id: "fungal-grotto",
            title: "Fungal Grotto",
            narrative: "Bioluminescent mushrooms pulse in the dark, their spores hanging thick in the air. The cave walls glitter with an otherworldly light.",
            artID: "mystery-bioluminescent-mushrooms",
            choices: [
                ("harvest", "Harvest Carefully", [.gainMaterial(.herbs, 5), .gainItem(itemTemplateID: "wand-basic")]),
                ("inhale", "Inhale the Spores", [.gainExperience(10)])
            ]
        ),
        ev(
            id: "wisdom-tree",
            title: "Wisdom Tree",
            narrative: "An immense oak with a weathered face carved into its bark speaks in rustling leaves. Ancient wisdom emanates from its gnarled branches.",
            artID: "mystery-oak-tree-with-face",
            choices: [
                ("ask-knowledge", "Ask for Knowledge", [.gainExperience(10)]),
                ("rest-shade", "Rest in its Shade", [.gainMaterial(.herbs, 4), .gainItem(itemTemplateID: "emerald_ring-basic")])
            ]
        ),
        ev(
            id: "fairy-ring",
            title: "Fairy Ring",
            narrative: "A circle of glowing mushrooms hums with fey energy in a moonlit clearing. The air feels thick with mischief and ancient magic.",
            artID: "mystery-circle-of-glowing-mushrooms",
            choices: [
                ("leave-offering", "Leave an Offering", [.gainMaterial(.crystal, 3)]),
                ("make-wish", "Make a Wish", [.gainGold(25)])
            ]
        ),
        ev(
            id: "ancient-altar",
            title: "Ancient Altar",
            narrative: "A weathered stone altar stands beneath a shaft of light piercing the canopy. A rusted offering bowl rests before it, etched with forgotten symbols.",
            artID: "mystery-weathered-stone-altar",
            choices: [
                ("pray", "Pray", [.gainExperience(8)]),
                ("make-offering", "Make an Offering", [.gainMaterial(.crystal, 3), .gainMaterial(.herbs, 3)])
            ]
        ),
        ev(
            id: "hidden-cache",
            title: "Hidden Cache",
            narrative: "A leather-wrapped bundle tucked between exposed roots catches your eye. Whatever is inside has been hidden here for a long time.",
            artID: "mystery-leather-bundle-between-roots",
            choices: [
                ("take-all", "Take Everything", [.gainGold(20), .gainItem(itemTemplateID: "dagger-basic")]),
                ("study-map", "Study the Map", [.gainGold(5), .gainItem(itemTemplateID: "sapphire_amulet-basic")])
            ]
        ),
        ev(
            id: "overgrown-temple",
            title: "Overgrown Temple",
            narrative: "Vines carpet ancient mosaic floors. A faint glow pulses from a cracked sarcophagus in the chamber beyond, hinting at preserved treasures.",
            artID: "mystery-vines-carpet-mosaic-floors",
            choices: [
                ("explore-crypt", "Explore the Crypt", [.gainRandomItem]),
                ("decipher", "Decipher the Inscriptions", [.gainExperience(8)])
            ]
        ),
        ev(
            id: "abandoned-study",
            title: "Abandoned Study",
            narrative: "Dusty shelves line a circular tower room. A half-written thesis lies open on the desk, quill dried beside it centuries ago.",
            artID: "mystery-dusty-shelves-in-tower",
            choices: [
                ("search-scrolls", "Search the Scrolls", [.chooseItem]),
                ("organize", "Organize the Library", [.gainExperience(8)])
            ]
        ),
        ev(
            id: "mysterious-tome",
            title: "Mysterious Tome",
            narrative: "A leather-bound book floats above a pedestal, pages turning on their own. Arcane energy crackles around it as if it has been waiting for a reader.",
            artID: "mystery-leather-book-floats",
            choices: [
                ("read", "Read Carefully", [.gainExperience(8)]),
                ("tear-pages", "Tear Out the Pages", [.gainItem(itemTemplateID: "spellbook-basic")])
            ]
        ),
        ev(
            id: "crystal-geode",
            title: "Crystal Geode",
            narrative: "A massive amethyst geode splits the cave floor, its resonant hum filling the chamber with a deep, soothing vibration.",
            artID: "mystery-amethyst-geode",
            choices: [
                ("mine-crystals", "Mine the Crystals", [.gainMaterial(.crystal, 4), .gainItem(itemTemplateID: "sapphire_ring-basic")]),
                ("meditate", "Meditate Under the Crystal", [.gainExperience(8)])
            ]
        ),
        ev(
            id: "meteorite-crash",
            title: "Meteorite Crash",
            narrative: "A smoldering crater scars the forest floor. A strange metallic rock from beyond the sky sits at its center, radiating unfamiliar energy.",
            artID: "mystery-smoldering-crater",
            choices: [
                ("collect-fragment", "Collect a Fragment", [.gainMaterial(.iron, 3), .gainItem(itemTemplateID: "ruby_amulet-astral")]),
                ("study-site", "Study the Impact Site", [.gainExperience(8)])
            ]
        ),
        ev(
            id: "forgotten-hoard",
            title: "Forgotten Hoard",
            narrative: "Gold coins glitter among scattered bones beside a massive, ancient skeleton. The remains of a once-great beast guard its treasure even in death.",
            artID: "mystery-gold-coins-among-bones",
            choices: [
                ("take-coins", "Take the Coins", [.gainGold(30), .gainMaterial(.iron, 3)]),
                ("take-bones", "Take the Bones", [.gainItem(itemTemplateID: "kite_shield-basic")])
            ]
        ),
        ev(
            id: "sacred-grove",
            title: "Sacred Grove",
            narrative: "Sunlight breaks through the canopy in golden rays. The air is thick with peace, and the ground hums with quiet vitality.",
            artID: "mystery-sunlight-breaks-canopy",
            choices: [
                ("bask", "Bask in the Light", [.gainExperience(15), .gainMaterial(.herbs, 3)]),
                ("search", "Search the Area", [.gainRandomItem])
            ]
        ),
        ev(
            id: "mountain-pass",
            title: "Mountain Pass",
            narrative: "A narrow pass winds through jagged peaks. The wind howls and loose rocks scatter the path, but valuable minerals glint in the sunlight.",
            artID: "mystery-narrow-pass-through-peaks",
            choices: [
                ("mine-cliffside", "Mine the Cliffside", [.gainMaterial(.iron, 4), .gainMaterial(.crystal, 2)]),
                ("study-flora", "Study the Alpine Flora", [.gainExperience(8), .gainMaterial(.herbs, 2)])
            ]
        ),
        ev(
            id: "murky-pond",
            title: "Murky Pond",
            narrative: "A still pond reflects the gnarled trees surrounding it. Bubbles rise from its murky depths, hinting at secrets beneath the surface.",
            artID: "mystery-pond-reflects-gnarled-trees",
            choices: [
                ("go-fishing", "Go Fishing", [.gainMaterial(.food, 6)]),
                ("gather-reeds", "Gather Medicinal Reeds", [.gainMaterial(.herbs, 4), .gainMaterial(.wood, 2)])
            ]
        ),
        ev(
            id: "necromancers-offer",
            title: "The Necromancer's Offer",
            narrative: "A robed figure tends a circle of salt and bone. Without looking up, they extend a skeletal hand, offering forbidden power.",
            artID: nil,
            choices: [
                ("accept-rite", "Accept the Rite", [.gainExperience(8), .gainItem(itemTemplateID: "staff-basic")]),
                ("take-salts", "Take the Salts", [.gainItem(itemTemplateID: "plate_armor-basic")])
            ]
        ),
        ev(
            id: "medicinal-herb-garden",
            title: "Medicinal Herb Garden",
            narrative: "Cultivated beds have run wild as medicinal herbs grow through cracked paving, rich with scent and curative promise.",
            artID: nil,
            choices: [
                ("harvest-supplies", "Harvest Supplies", [.gainMaterial(.herbs, 6), .gainItem(itemTemplateID: "leather_armor-basic")]),
                ("read-research", "Read the Research", [.gainExperience(8)])
            ]
        ),
        ev(
            id: "crystal-garden",
            title: "Crystal Garden",
            narrative: "Faceted crystalline blooms catch stray light, chiming softly when the wind passes by. Each shard thrums with latent power.",
            artID: nil,
            choices: [
                ("harvest-crystals", "Harvest the Crystals", [.gainMaterial(.crystal, 4), .gainItem(itemTemplateID: "topaz_ring-basic")]),
                ("study-crystals", "Study the Crystals", [.gainExperience(8)])
            ]
        ),
        ev(
            id: "hunters-lodge",
            title: "Hunter's Lodge",
            narrative: "A deserted lodge still smells of smoke, wood, and leather. A hunter's bow and quiver hang near the door, preserved and waiting.",
            artID: nil,
            choices: [
                ("take-arrows", "Take the Arrows", [.gainItem(itemTemplateID: "shortbow-astral")]),
                ("take-blade", "Take the Hunting Blade", [.gainItem(itemTemplateID: "hatchet-astral")])
            ]
        ),
        ev(
            id: "roadside-censer",
            title: "Roadside Censer",
            narrative: "Incense smoke coils from a hanging brass censer at a fork in the path. The air tastes of sanctified ash and old vows.",
            artID: nil,
            choices: [
                ("breathe-smoke", "Breathe the Smoke", [.gainExperience(8)]),
                ("claim-censer", "Claim the Censer", [.gainItem(itemTemplateID: "topaz_amulet-basic")])
            ]
        ),
        ev(
            id: "the-phoenix",
            title: "The Phoenix",
            narrative: "A single feather glows with warm radiance, asking to be reborn. Embers swirl around it as if the flame that created it still burns nearby.",
            artID: nil,
            choices: [
                ("claim-feather", "Claim the Feather", [.gainItem(itemTemplateID: "spellbook-astral")]),
                ("fan-embers", "Fan the Embers", [.gainItem(itemTemplateID: "staff-astral")])
            ]
        ),
        ev(
            id: "the-wolf",
            title: "The Wolf",
            narrative: "A grey wolf steps from the treeline, watching you with amber eyes. It does not flee — only waits, as if deciding whether you are worth knowing.",
            artID: nil,
            choices: [
                ("study-pack", "Study the Pack's Tactics", [.gainExperience(8)]),
                ("share-meal", "Share Your Rations", [.gainItem(itemTemplateID: "recurve_bow-basic")])
            ]
        )
    ]

    public static func mysteryEvent(matching id: String) -> MysteryEvent? {
        all.first { $0.id == id }
    }

    public static func pickMysteryEvent() -> MysteryEvent {
        all.randomElement()!
    }
}
