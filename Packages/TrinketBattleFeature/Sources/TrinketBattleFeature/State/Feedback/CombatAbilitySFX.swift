import BattleEngine
import TrinketContent

/// Changes a winning result's recording without changing its strength or priority.
enum CombatAbilitySFX {
    static let prewarmIDs = [
        SFXID.attackSlash, SFXID.attackStab, SFXID.attackSlashCritical, SFXID.attackStabCritical,
        SFXID.attackBow, SFXID.attackBowAlt, SFXID.attackBite, SFXID.consumeFood, SFXID.consumePotion,
        SFXID.castIceWard, SFXID.castManaShield, SFXID.castAvatar, SFXID.castEvade,
        SFXID.attackSunder, SFXID.attackRock, SFXID.castSniff, SFXID.thornsGain, SFXID.itemCorrupt,
        SFXID.astralBowBurn, SFXID.astralBowFreeze, SFXID.astralBowPiercing,
        SFXID.astralBowBurnCritical, SFXID.astralBowFreezeCritical, SFXID.astralBowPiercingCritical,
    ]

    static func clipID(_ clip: String, for event: ActionEvent?) -> String {
        guard let event, event.origin != .periodic,
              event.kind == .abilityDamage || event.effectKind != nil
        else { return clip }
        switch (event.abilityID, clip) {
        case ("slash", SFXID.hit): return SFXID.attackSlash
        case ("slash", SFXID.hitCritical): return SFXID.attackSlashCritical
        case ("stab", SFXID.hit): return SFXID.attackStab
        case ("stab", SFXID.hitCritical): return SFXID.attackStabCritical
        case ("astral-arrow", SFXID.hitBurn): return SFXID.astralBowBurn
        case ("astral-arrow", SFXID.hitFreeze): return SFXID.astralBowFreeze
        case ("astral-arrow", SFXID.hitPiercing): return SFXID.astralBowPiercing
        case ("astral-arrow", SFXID.hitBurnCritical): return SFXID.astralBowBurnCritical
        case ("astral-arrow", SFXID.hitFreezeCritical): return SFXID.astralBowFreezeCritical
        case ("astral-arrow", SFXID.hitPiercingCritical): return SFXID.astralBowPiercingCritical
        case ("fire-arrow", SFXID.hitBurn), ("ice-shot", SFXID.hitFreeze): return SFXID.attackBow
        case ("venom-arrow", SFXID.hitPiercing), ("bounty-shot", SFXID.hitStun): return SFXID.attackBowAlt
        case ("fangs", SFXID.hitPiercing), ("venom-fangs", SFXID.hitPiercing),
             ("predators-focus", SFXID.hitPiercing), ("pack-tactics", SFXID.hit): return SFXID.attackBite
        case ("apple", SFXID.heal), ("mana-berries", SFXID.heal),
             ("mana-berries", SFXID.restoreMana): return SFXID.consumeFood
        case ("acid-potion", SFXID.hitPiercing), ("mana-potion", SFXID.restoreMana),
             ("mana-potion", SFXID.abilityDraw), ("stoneskin-potion", SFXID.block),
             ("luck-potion", SFXID.block), ("luck-potion", SFXID.heal),
             ("luck-potion", SFXID.thornsGain): return SFXID.consumePotion
        case ("blood-offering", SFXID.hitPiercing), ("blood-offering", SFXID.abilityDraw),
             ("dark-pact", SFXID.hitBurn), ("dark-pact", SFXID.abilityDraw),
             ("faustian-bargain", SFXID.hitBurn), ("faustian-bargain", SFXID.abilityDraw): return SFXID.itemCorrupt
        case ("glacial-ward", SFXID.block): return SFXID.castIceWard
        case ("mana-shield", SFXID.block): return SFXID.castManaShield
        case ("avatar-of-justice", SFXID.hitHoly), ("avatar-of-justice", SFXID.block),
             ("avatar-of-justice", SFXID.buff): return SFXID.castAvatar
        case ("feint", SFXID.buff), ("feint", SFXID.abilityDraw), ("shadowstep", SFXID.hit): return SFXID.castEvade
        case ("sniff-out", SFXID.hitPiercing), ("sniff-out", SFXID.buff): return SFXID.castSniff
        case ("sunder", SFXID.hit): return SFXID.attackSunder
        case ("meteor", SFXID.hitBurn), ("earthquake", SFXID.hitStun): return SFXID.attackRock
        case ("steal", SFXID.hit): return SFXID.lootCollect
        default: return clip
        }
    }
}
