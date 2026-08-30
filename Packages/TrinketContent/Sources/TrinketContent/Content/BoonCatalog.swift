import TrinketCore

public enum BoonCatalog {
    public static let thunderwall = BoonCategory(id: "stun-block", name: "Thunderwall", keywords: [.stun, .block])
    public static let hallowedBastion = BoonCategory(id: "holy-block", name: "Hallowed Bastion", keywords: [.holy, .block])
    public static let kineticArsenal = BoonCategory(id: "physical-block", name: "Kinetic Arsenal", keywords: [.physical, .block])
    public static let judgment = BoonCategory(id: "holy-purge", name: "Judgment", keywords: [.holy, .purge])
    public static let venomsteel = BoonCategory(id: "poison-physical", name: "Venomsteel", keywords: [.poison, .physical])
    public static let mercenaryEdge = BoonCategory(id: "physical-gold", name: "Mercenary's Edge", keywords: [.physical, .gold])
    public static let stormcraft = BoonCategory(id: "stun-mana", name: "Stormcraft", keywords: [.stun, .mana])
    public static let neuroshock = BoonCategory(id: "stun-poison", name: "Neuroshock", keywords: [.stun, .poison])
    public static let crimsonRime = BoonCategory(id: "bleed-freeze", name: "Crimson Rime", keywords: [.bleed, .freeze])
    public static let septicWounds = BoonCategory(id: "poison-bleed", name: "Septic Wounds", keywords: [.poison, .bleed])
    public static let shadowsteel = BoonCategory(id: "physical-dodge", name: "Shadowsteel", keywords: [.physical, .dodge])
    public static let renewal = BoonCategory(id: "cleanse-health", name: "Renewal", keywords: [.cleanse, .health])
    public static let cinderstrike = BoonCategory(id: "burn-physical", name: "Cinderstrike", keywords: [.burn, .physical])
    public static let bloodcraft = BoonCategory(id: "physical-bleed", name: "Bloodcraft", keywords: [.physical, .bleed])
    public static let rimeguard = BoonCategory(id: "freeze-block", name: "Rimeguard", keywords: [.freeze, .block])
    public static let thermalFracture = BoonCategory(id: "burn-freeze", name: "Thermal Fracture", keywords: [.burn, .freeze])

    public static let all: [BoonDefinition] = [
        boon(
            "lightning-rod",
            "Lightning Rod",
            thunderwall,
            "Stunning an enemy doubles the party's Block.",
            .controlDoublesPartyBlock(.stun),
        ),
        boon(
            "seismic-reversal",
            "Seismic Reversal",
            thunderwall,
            "Blocked damage is returned as Stun damage.",
            .blockedDamageReturned(.stun),
        ),
        boon("sunwall", "Sunwall", hallowedBastion, "Holy damage grants equal Block to the party.", .damageGrantsPartyBlock(.holy)),
        boon(
            "unbroken-vow",
            "Unbroken Vow",
            hallowedBastion,
            "Block lets Holy damage ignore Block and Dodge.",
            .damageIgnoresBlockAndDodgeWhileBlocked(.holy),
        ),
        boon(
            "stored-impact",
            "Stored Impact",
            kineticArsenal,
            "Blocked damage empowers your next Physical attack.",
            .storedBlockedDamage(.physical),
        ),
        boon(
            "battering-ram",
            "Battering Ram",
            kineticArsenal,
            "Physical attacks consume Block for equal bonus damage.",
            .consumeBlockForBonusDamage(.physical),
        ),
        boon("interdict", "Interdict", judgment, "Holy damage Purges all positive enemy effects.", .damagePurgesAll(.holy)),
        boon("crownfall", "Crownfall", judgment, "Purging deals 3 Holy damage per effect.", .purgeDealsDamage(keyword: .holy, amount: 3)),
        boon(
            "toxic-transfusion",
            "Toxic Transfusion",
            venomsteel,
            "Physical damage deals half as much Poison damage.",
            .mirroredDamage(source: .physical, result: .poison, multiplier: 0.5),
        ),
        boon(
            "pressure-point",
            "Pressure Point",
            venomsteel,
            "Critical Hits against Poisoned enemies deal double Physical damage.",
            .criticalDamageMultiplier(keyword: .physical, targetStatus: .poison, multiplier: 2),
        ),
        boon(
            "bounty-blade",
            "Bounty Blade",
            mercenaryEdge,
            "Critical Hits grant 3 Gold and draw a card.",
            .criticalGoldAndDraw(gold: 3, cards: 1),
        ),
        boon(
            "war-chest",
            "War Chest",
            mercenaryEdge,
            "50 Gold guarantees Physical Critical Hits.",
            .goldGuaranteesCritical(keyword: .physical, threshold: 50),
        ),
        boon("closed-circuit", "Closed Circuit", stormcraft, "Spending Mana deals equal Stun damage.", .manaSpentDealsDamage(.stun)),
        boon("eye-of-the-storm", "Eye of the Storm", stormcraft, "Stun damage restores equal Mana.", .damageRestoresMana(.stun)),
        boon(
            "nerve-agent",
            "Nerve Agent",
            neuroshock,
            "Poison damage deals half as much Stun damage.",
            .mirroredDamage(source: .poison, result: .stun, multiplier: 0.5),
        ),
        boon(
            "toxic-coma",
            "Toxic Coma",
            neuroshock,
            "Stunned enemies take double Poison damage.",
            .statusDamageMultiplier(status: .stun, damage: .poison, multiplier: 2),
        ),
        boon(
            "shatterpoint",
            "Shatterpoint",
            crimsonRime,
            "Freeze damage detonates and consumes all Bleed.",
            .damageDetonates(damage: .freeze, effect: .bleed, requiresCritical: false),
        ),
        boon("cryostasis", "Cryostasis", crimsonRime, "Bleed never expires on Frozen enemies.", .preserveBleedWhileFrozen),
        boon(
            "cross-contamination",
            "Cross-Contamination",
            septicWounds,
            "Bleed damage deals half as much Poison damage.",
            .mirroredDamage(source: .bleed, result: .poison, multiplier: 0.5),
        ),
        boon(
            "septicemia",
            "Septicemia",
            septicWounds,
            "Poisoned enemies take double Bleed damage.",
            .statusDamageMultiplier(status: .poison, damage: .bleed, multiplier: 2),
        ),
        boon("phantom-counter", "Phantom Counter", shadowsteel, "Dodging draws and plays a Physical card.", .dodgeDrawsAndPlays(.physical)),
        boon(
            "perfect-tempo",
            "Perfect Tempo",
            shadowsteel,
            "Physical Critical Hits make you Dodge the next attack.",
            .criticalGrantsDodge(.physical),
        ),
        boon("purifying-waters", "Purifying Waters", renewal, "Cleansing restores 4 Health per effect.", .cleanseRestoresHealth(4)),
        boon("clean-slate", "Clean Slate", renewal, "Overhealing Cleanses one effect.", .overhealCleanses),
        boon(
            "firebrand",
            "Firebrand",
            cinderstrike,
            "Physical damage deals half as much Burn damage.",
            .mirroredDamage(source: .physical, result: .burn, multiplier: 0.5),
        ),
        boon(
            "backdraft",
            "Backdraft",
            cinderstrike,
            "Critical Hits detonate and consume all Burn.",
            .damageDetonates(damage: .physical, effect: .burn, requiresCritical: true),
        ),
        boon(
            "ashen-arsenal",
            "Ashen Arsenal",
            cinderstrike,
            "Burn damage draws a Physical card.",
            .damageDrawsCard(damage: .burn, card: .physical),
        ),
        boon(
            "furnace-rhythm",
            "Furnace Rhythm",
            cinderstrike,
            "Burn cards make the next Physical card play twice.",
            .cardPrimesRepeat(trigger: .burn, repeated: .physical),
        ),
        boon(
            "butchers-ledger",
            "Butcher's Ledger",
            bloodcraft,
            "Physical damage deals half as much Bleed damage.",
            .mirroredDamage(source: .physical, result: .bleed, multiplier: 0.5),
        ),
        boon(
            "arterial-cascade",
            "Arterial Cascade",
            bloodcraft,
            "Physical Critical Hits detonate and consume all Bleed.",
            .damageDetonates(damage: .physical, effect: .bleed, requiresCritical: true),
        ),
        boon(
            "bloodrush",
            "Bloodrush",
            bloodcraft,
            "Bleed damage draws a Physical card.",
            .damageDrawsCard(damage: .bleed, card: .physical),
        ),
        boon("redline", "Redline", bloodcraft, "Physical Critical Hits double Bleed duration.", .criticalDoublesBleedDuration(.physical)),
        boon("cold-storage", "Cold Storage", rimeguard, "Freeze damage grants equal Block.", .damageGrantsBlock(.freeze)),
        boon("avalanche-guard", "Avalanche Guard", rimeguard, "Freezing an enemy doubles party Block.", .controlDoublesPartyBlock(.freeze)),
        boon(
            "icebound-exchange",
            "Icebound Exchange",
            rimeguard,
            "Freeze damage steals enemy Block for the party.",
            .freezeDamageStealsBlock,
        ),
        boon(
            "glacial-reprieve",
            "Glacial Reprieve",
            rimeguard,
            "Blocked damage is returned as Freeze damage.",
            .blockedDamageReturned(.freeze),
        ),
        boon(
            "steam-explosion",
            "Steam Explosion",
            thermalFracture,
            "Freeze damage detonates and consumes all Burn.",
            .damageDetonates(damage: .freeze, effect: .burn, requiresCritical: false),
        ),
        boon(
            "frostfire",
            "Frostfire",
            thermalFracture,
            "Burn damage deals half as much Freeze damage.",
            .mirroredDamage(source: .burn, result: .freeze, multiplier: 0.5),
        ),
        boon(
            "elemental-paradox",
            "Elemental Paradox",
            thermalFracture,
            "Burning enemies take double Freeze damage.",
            .statusDamageMultiplier(status: .burn, damage: .freeze, multiplier: 2),
        ),
        boon(
            "temper-cycle",
            "Temper Cycle",
            thermalFracture,
            "Burn cards make the next Freeze card play twice.",
            .cardPrimesRepeat(trigger: .burn, repeated: .freeze),
        ),
    ]

    public static func boon(id: String) -> BoonDefinition? {
        all.first { $0.id == id }
    }

    private static func boon(
        _ id: String,
        _ name: String,
        _ category: BoonCategory,
        _ description: String,
        _ effect: BoonEffect,
    ) -> BoonDefinition {
        BoonDefinition(id: id, name: name, category: category, description: description, effect: effect)
    }
}
