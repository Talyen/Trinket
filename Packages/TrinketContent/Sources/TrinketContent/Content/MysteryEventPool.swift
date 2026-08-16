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
            narrative: "You stumble upon a lush field of glowing Mana Berries. Crystal has formed along the stems, and a sapphire ring lies half-buried in the tangle, pulsing with the same blue light.",
            artID: "mystery-mana-berries",
            choices: [
                ("harvest-berries", "Harvest Berries", [
                    .gainMaterial(.herbs),
                    generatedItem("sapphire_ring", guaranteedAffixIDs: ["manabound"]),
                ]),
                ("gather-crystals", "Gather Crystals", [.gainExperience, .gainMaterial(.crystal)]),
            ]
        ),
        ev(
            id: "enchanted-spring",
            title: "Enchanted Spring",
            narrative: "A pool of iridescent water steams gently in the cool air. Moss carpets the bank, and a charm of icy crystal rests just below the surface.",
            artID: "mystery-enchanted-spring",
            choices: [
                ("gather-the-moss", "Gather the Moss", [.gainExperience, .gainMaterial(.herbs)]),
                ("take-the-charm", "Take the Charm", [
                    generatedItem("icy_heart"),
                    .gainMaterial(.crystal),
                ]),
            ]
        ),
        ev(
            id: "fungal-grotto",
            title: "Fungal Grotto",
            narrative: "Bioluminescent mushrooms pulse in the dark, their spores hanging thick in the air. Crystals glitter on the cave walls, and an emerald ring sits among the caps.",
            artID: "mystery-fungal-grotto",
            choices: [
                ("harvest-mushrooms", "Harvest Mushrooms", [
                    .gainMaterial(.herbs),
                    generatedItem("emerald_ring"),
                ]),
                ("collect-crystals", "Collect Crystals", [.gainExperience, .gainMaterial(.crystal)]),
            ]
        ),
        ev(
            id: "wisdom-tree",
            title: "Wisdom Tree",
            narrative: "An immense oak with a weathered face carved into its bark speaks in rustling leaves. Fallen branches litter the ground, and herbs crowd the roots.",
            artID: "mystery-wisdom-tree",
            choices: [
                ("collect-branches", "Collect Branches", [.gainExperience, .gainMaterial(.wood)]),
                ("forage-herbs", "Forage Herbs", [.gainExperience, .gainMaterial(.herbs)]),
            ]
        ),
        ev(
            id: "fairy-ring",
            title: "Fairy Ring",
            narrative: "A circle of glowing mushrooms hums with fey energy in a moonlit clearing. Gold coins and a lucky clover rest in the grass as if left for you.",
            artID: "mystery-fairy-ring",
            choices: [
                ("take-the-gold", "Take the Gold", [.gainGold(25), generatedItem("lucky_clover")]),
                ("pick-mushrooms", "Pick Mushrooms", [
                    generatedItem("parasitic_bloom"),
                    .gainMaterial(.herbs),
                ]),
            ]
        ),
        ev(
            id: "ancient-altar",
            title: "Ancient Altar",
            narrative: "A weathered stone altar stands beneath a shaft of light piercing the canopy. Gold fills a rusted offering bowl, and a topaz relic set with crystal rests beside it.",
            artID: "mystery-ancient-altar",
            choices: [
                ("take-the-offering", "Take the Offering", [.gainExperience, .gainGold(20)]),
                ("claim-the-relic", "Claim the Relic", [
                    generatedItem("topaz_amulet"),
                    .gainMaterial(.crystal),
                ]),
            ]
        ),
        ev(
            id: "hidden-cache",
            title: "Hidden Cache",
            narrative: "A leather-wrapped bundle tucked between exposed roots catches your eye. Inside wait a coinpurse and a blade, hidden here for a long time.",
            artID: "mystery-hidden-cache",
            choices: [
                ("take-coinpurse", "Take the Coinpurse", [.gainGold(20), .gainMaterial(.hide)]),
                ("claim-blade", "Claim the Blade", [generatedItem("dagger"), .gainMaterial(.hide)]),
            ]
        ),
        ev(
            id: "overgrown-temple",
            title: "Overgrown Temple",
            narrative: "Vines carpet ancient mosaic tiles. A faint glow pulses from a cracked sarcophagus in the crypt beyond, hinting at gold and preserved treasures.",
            artID: "mystery-overgrown-temple",
            choices: [
                ("search-the-crypt", "Search the Crypt", [.gainRandomItem, .gainGold(20)]),
                ("take-a-tile", "Take a Tile", [.gainExperience, .gainMaterial(.stone)]),
            ]
        ),
        ev(
            id: "abandoned-study",
            title: "Abandoned Study",
            narrative: "Dusty wooden shelves of scrolls line a circular tower room. A spellbook lies open on the desk, a quill dried beside it centuries ago.",
            artID: "mystery-abandoned-study",
            choices: [
                ("search-scrolls", "Search the Scrolls", [
                    generatedItem("spellbook"),
                    .gainMaterial(.wood),
                ]),
                ("take-the-quill", "Take the Quill", [.gainExperience, generatedItem("runic_quill")]),
            ]
        ),
        ev(
            id: "mysterious-tome",
            title: "Mysterious Tome",
            narrative: "A leather-bound book floats above a pedestal, loose pages turning on their own. Its binding is splitting, as if it has been waiting to be read — or repaired.",
            artID: "mystery-mysterious-tome",
            choices: [
                ("take-the-pages", "Take the Pages", [
                    .gainExperience,
                    generatedItem("tattered_pages"),
                ]),
                ("repair-the-binding", "Repair the Binding", [
                    .gainExperience,
                    generatedItem("spellbook"),
                ]),
            ]
        ),
        ev(
            id: "crystal-geode",
            title: "Crystal Geode",
            narrative: "A massive amethyst geode splits the cave floor, gems crowding its hollow. A sapphire ring has formed among the crystal, and the stone shell has broken open beside it.",
            artID: "mystery-crystal-geode",
            choices: [
                ("collect-gems", "Collect Gems", [
                    .gainMaterial(.crystal),
                    generatedItem("sapphire_ring", guaranteedAffixIDs: ["manabound"]),
                ]),
                ("take-the-shell", "Take the Shell", [.gainExperience, .gainMaterial(.stone)]),
            ]
        ),
        ev(
            id: "meteorite-crash",
            title: "Meteorite Crash",
            narrative: "A smoldering crater scars the forest floor. A metallic meteorite from beyond the sky sits at its center, iron fragments in the stone where the pit was torn open.",
            artID: "mystery-meteorite-crash",
            choices: [
                ("take-a-fragment", "Take a Fragment", [
                    generatedItem("meteorite"),
                    .gainMaterial(.iron),
                ]),
                ("search-the-crater", "Search the Crater", [.gainExperience, .gainMaterial(.stone)]),
            ]
        ),
        ev(
            id: "forgotten-hoard",
            title: "Forgotten Hoard",
            narrative: "Scattered bones and a bone charm lie beside a massive, ancient skeleton. Iron scraps rest among the remains, and gold coins spill around a shield the beast still guards.",
            artID: "mystery-forgotten-hoard",
            choices: [
                ("collect-the-bones", "Collect the Bones", [
                    generatedItem("bone_charm"),
                    .gainMaterial(.iron),
                ]),
                ("claim-the-shield", "Claim the Shield", [generatedItem("kite_shield"), .gainGold(30)]),
            ]
        ),
        ev(
            id: "sacred-grove",
            title: "Sacred Grove",
            narrative: "Sunlight breaks through the canopy in golden rays, falling on wild blooms and herbs. An emerald ring hangs in the roots of a fallen wooden bough.",
            artID: "mystery-sacred-grove",
            choices: [
                ("pick-the-blooms", "Pick the Blooms", [.gainExperience, .gainMaterial(.herbs)]),
                ("take-the-ring", "Take the Ring", [
                    generatedItem("emerald_ring"),
                    .gainMaterial(.wood),
                ]),
            ]
        ),
        ev(
            id: "mountain-pass",
            title: "Mountain Pass",
            narrative: "A narrow pass winds through jagged peaks. Iron and a thunderstone glint in the cliffside, and alpine herbs cling to the rocks where the wind howls.",
            artID: "mystery-mountain-pass",
            choices: [
                ("mine-the-cliffside", "Mine the Cliffside", [
                    generatedItem("thunderstone"),
                    .gainMaterial(.iron),
                ]),
                ("gather-herbs", "Gather Herbs", [.gainExperience, .gainMaterial(.herbs)]),
            ]
        ),
        ev(
            id: "murky-pond",
            title: "Murky Pond",
            narrative: "A still pond reflects the gnarled trees surrounding it. Fish drift in the murky depths, and medicinal reeds crowd the bank as bubbles rise from below.",
            artID: "mystery-murky-pond",
            choices: [
                ("catch-fish", "Catch Fish", [.gainExperience, .gainMaterial(.food)]),
                ("pull-the-reeds", "Pull the Reeds", [.gainExperience, .gainMaterial(.herbs)]),
            ]
        ),
        ev(
            id: "necromancers-offer",
            title: "The Necromancer's Offer",
            narrative: "A robed figure tends a circle of crystal salts and bone. Without looking up, they extend a staff in a skeletal hand, offering a forbidden rite.",
            artID: "mystery-the-necromancers-offer",
            choices: [
                ("accept-rite", "Accept the Rite", [.gainExperience, generatedItem("staff")]),
                ("take-the-salts", "Take the Salts", [
                    generatedItem("bone_charm"),
                    .gainMaterial(.crystal),
                ]),
            ]
        ),
        ev(
            id: "medicinal-herb-garden",
            title: "Medicinal Herb Garden",
            narrative: "Cultivated beds have run wild as medicinal herbs grow through cracked paving. A mortar and pestle sit beside a sheaf of notes, rich with scent and curative promise.",
            artID: "mystery-medicinal-herb-garden",
            choices: [
                ("harvest-remedies", "Harvest Remedies", [
                    .gainMaterial(.herbs),
                    generatedItem("mortar_and_pestle"),
                ]),
                ("take-the-notes", "Take the Notes", [
                    .gainExperience,
                    generatedItem("tattered_pages"),
                ]),
            ]
        ),
        ev(
            id: "crystal-garden",
            title: "Crystal Garden",
            narrative: "Faceted crystalline blooms catch stray light, and chimes hang among the shards. A sapphire amulet rests in the bed, each shard thrumming with latent power.",
            artID: "mystery-crystal-garden",
            choices: [
                ("harvest-shards", "Harvest Shards", [
                    .gainMaterial(.crystal),
                    generatedItem("sapphire_amulet", guaranteedAffixIDs: ["manabound"]),
                ]),
                ("take-the-chimes", "Take the Chimes", [
                    .gainExperience,
                    generatedItem("resonant_chimes"),
                ]),
            ]
        ),
        ev(
            id: "hunters-lodge",
            title: "Hunter's Lodge",
            narrative: "A deserted lodge still smells of smoke, wood, and leather. A hunter's bow and hatchet hang near the door, preserved and waiting.",
            artID: "mystery-hunters-lodge",
            choices: [
                ("claim-the-bow", "Claim the Bow", [generatedItem("shortbow"), .gainMaterial(.hide)]),
                ("take-the-hatchet", "Take the Hatchet", [
                    generatedItem("hatchet"),
                    .gainMaterial(.hide),
                ]),
            ]
        ),
        ev(
            id: "roadside-censer",
            title: "Roadside Censer",
            narrative: "Incense smoke coils from a hanging brass censer at a fork in the path. Gold coins lie at its base, and the air tastes of sanctified ash and old vows.",
            artID: "mystery-roadside-censer",
            choices: [
                ("gather-incense", "Gather Incense", [.gainExperience, .gainMaterial(.herbs)]),
                ("claim-censer", "Claim the Censer", [generatedItem("brass_censer"), .gainGold(20)]),
            ]
        ),
        ev(
            id: "the-phoenix",
            title: "The Phoenix",
            narrative: "A single feather glows with warm radiance on a nest of charred wood, a ruby gleam caught in the down. A burning brand leans in the embers as if the flame that created it still burns nearby.",
            artID: "mystery-the-phoenix",
            choices: [
                ("claim-the-feather", "Claim the Feather", [
                    generatedItem("ruby_amulet"),
                    .gainMaterial(.hide),
                ]),
                ("take-the-brand", "Take the Brand", [generatedItem("staff"), .gainMaterial(.wood)]),
            ]
        ),
        ev(
            id: "the-wolf",
            title: "The Wolf",
            narrative: "A grey wolf steps from the treeline, watching you with amber eyes. It does not flee — only waits, then leads you toward a den of hides and a hunter's cache of food and a bow.",
            artID: "mystery-the-wolf",
            choices: [
                ("search-the-den", "Search the Den", [.gainExperience, .gainMaterial(.hide)]),
                ("open-the-cache", "Open the Cache", [
                    generatedItem("recurve_bow"),
                    .gainMaterial(.food),
                ]),
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
