import Foundation
import TrinketCore

extension MysteryEventPool {
    static let manaBerries = makeEvent(
        id: "mana-berries",
        title: "Mana Berries",
        narrative: "Glowing berries crowd around {A}. Nearby, {B} rests above rune-carved roots that channel the field’s blue light.",
        artID: "mystery-mana-berries",
        choices: [
            ("harvest-berries", "Harvest Berries", [
                item("sapphire_ring", guaranteedAffixIDs: ["manabound"]),
                .gainMaterial(.herbs),
            ]),
            ("gather-crystals", "Study Roots", [
                item("wand"),
                .gainExperience,
            ]),
        ],
    )

    static let enchantedSpring = makeEvent(
        id: "enchanted-spring",
        title: "Enchanted Spring",
        narrative: "A crust of crystal traps {A} beneath the spring’s surface. On the bank, {B} rests beside ripples that repeat an ancient healing pattern.",
        artID: "mystery-enchanted-spring",
        choices: [
            ("gather-the-moss", "Break the Crust", [
                item("sapphire_amulet", trinkets: ["icy_heart"], uniques: ["rimeheart_locket"]),
                .gainMaterial(.crystal),
            ]),
            ("take-the-charm", "Read the Ripples", [
                item("emerald_ring"),
                .gainExperience,
            ]),
        ],
    )

    static let fungalGrotto = makeEvent(
        id: "fungal-grotto",
        title: "Fungal Grotto",
        narrative: "Medicinal mushrooms grow around {A}. Deeper in the grotto, drifting spores form shifting patterns above {B}.",
        artID: "mystery-fungal-grotto",
        choices: [
            ("harvest-mushrooms", "Harvest the Caps", [
                item("emerald_amulet", trinkets: ["parasitic_bloom"]),
                .gainMaterial(.herbs),
            ]),
            ("collect-crystals", "Study the Spores", [
                item("wand"),
                .gainExperience,
            ]),
        ],
    )

    static let wisdomTree = makeEvent(
        id: "wisdom-tree",
        title: "Wisdom Tree",
        narrative: "The ancient oak cradles {A} among its fallen boughs. Inside a hollow, {B} accompanies lessons carved into the tree’s rings.",
        artID: "mystery-wisdom-tree",
        choices: [
            ("collect-branches", "Gather Boughs", [
                item("leather_buckler", trinkets: ["ironwood_buckler"]),
                .gainMaterial(.wood),
            ]),
            ("forage-herbs", "Read the Rings", [
                item("spellbook"),
                .gainExperience,
            ]),
        ],
    )

    static let fairyRing = makeEvent(
        id: "fairy-ring",
        title: "Fairy Ring",
        narrative: "Coins glitter beside {A} inside the mushroom circle. Across the ring, flickering lights trace a forgotten dance around {B}.",
        artID: "mystery-fairy-ring",
        choices: [
            ("take-the-gold", "Take the Gift", [
                item("topaz_ring", trinkets: ["lucky_clover"]),
                .gainGold(25),
            ]),
            ("pick-mushrooms", "Learn the Dance", [
                item("leather_armor", uniques: ["dance_of_blades"]),
                .gainExperience,
            ]),
        ],
    )

    static let sacredGrove = makeEvent(
        id: "sacred-grove",
        title: "Sacred Grove",
        narrative: "The grove shelters {A} among medicinal blooms. Beside {B}, exposed roots trace an ancient healing rite.",
        artID: "mystery-sacred-grove",
        choices: [
            ("pick-the-blooms", "Gather the Blooms", [
                item("emerald_amulet", trinkets: ["groves_favor"]),
                .gainMaterial(.herbs),
            ]),
            ("take-the-ring", "Learn the Rite", [
                item("wand"),
                .gainExperience,
            ]),
        ],
    )

    static let mountainPass = makeEvent(
        id: "mountain-pass",
        title: "Mountain Pass",
        narrative: "An iron seam has split open around {A}. Farther along the pass, {B} is caught beneath fallen timber blocking the trail.",
        artID: "mystery-mountain-pass",
        choices: [
            ("mine-the-cliffside", "Search the Seam", [
                item("mace", trinkets: ["thunderstone"]),
                .gainMaterial(.iron),
            ]),
            ("gather-herbs", "Clear the Trail", [
                item("hatchet"),
                .gainMaterial(.wood),
            ]),
        ],
    )

    static let murkyPond = makeEvent(
        id: "murky-pond",
        title: "Murky Pond",
        narrative: "A fisher’s net hangs heavy with fish beside {A}. Along the bank, {B} lies among coins left on worn wishing stones.",
        artID: "mystery-murky-pond",
        choices: [
            ("catch-fish", "Haul the Net", [
                item("dagger"),
                .gainMaterial(.food),
            ]),
            ("pull-the-reeds", "Search the Stones", [
                item("topaz_ring", trinkets: ["wishing_well_coin"]),
                .gainGold(20),
            ]),
        ],
    )

    static let medicinalHerbGarden = makeEvent(
        id: "medicinal-herb-garden",
        title: "Medicinal Herb Garden",
        narrative: "An abandoned healer’s garden grows around {A}. Beside the beds, treatment notes lie beneath {B}.",
        artID: "mystery-medicinal-herb-garden",
        choices: [
            ("harvest-remedies", "Harvest Remedies", [
                item("emerald_amulet", trinkets: ["mortar_and_pestle"]),
                .gainMaterial(.herbs),
            ]),
            ("take-the-notes", "Read the Notes", [
                item("leather_armor", trinkets: ["plague_doctors_mask"]),
                .gainExperience,
            ]),
        ],
    )

    static let crystalGarden = makeEvent(
        id: "crystal-garden",
        title: "Crystal Garden",
        narrative: "Crystalline blooms surround {A}. Nearby, a melody rises from {B}, matching notes recorded on the garden’s weathered stones.",
        artID: "mystery-crystal-garden",
        choices: [
            ("harvest-shards", "Harvest Shards", [
                item("sapphire_amulet", guaranteedAffixIDs: ["manabound"]),
                .gainMaterial(.crystal),
            ]),
            ("take-the-chimes", "Learn the Melody", [
                item("wand", trinkets: ["resonant_chimes"]),
                .gainExperience,
            ]),
        ],
    )

    static let thePhoenix = makeEvent(
        id: "the-phoenix",
        title: "The Phoenix",
        narrative: "The phoenix’s abandoned nest cradles {A} among red crystals. Below, {B} lies across branches still warm from the bird’s passing.",
        artID: "mystery-the-phoenix",
        choices: [
            ("claim-the-feather", "Search the Nest", [
                item("ruby_ring", uniques: ["bloodfire_signet"]),
                .gainMaterial(.crystal),
            ]),
            ("take-the-brand", "Gather the Embers", [
                item("staff"),
                .gainMaterial(.wood),
            ]),
        ],
    )

    static let theWolf = makeEvent(
        id: "the-wolf",
        title: "The Wolf",
        narrative: "A wolf leads you to its former keeper’s camp. {A} lies with worn leather gear; {B} rests beside a cache of dried meat.",
        artID: "mystery-the-wolf",
        choices: [
            ("search-the-den", "Search the Kit", [
                item("leather_buckler", trinkets: ["companions_collar"]),
                .gainMaterial(.hide),
            ]),
            ("open-the-cache", "Open the Cache", [
                item("recurve_bow"),
                .gainMaterial(.food),
            ]),
        ],
    )
}
