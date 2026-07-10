import TrinketCore
import TrinketDesignSystem

/// Maps battle feedback items to curated SFX catalog IDs.
enum CombatSFXMapper {
    static func clipID(for item: CombatFeedbackItem) -> String? {
        switch item.feedbackClass {
        case .dodge, .block, .resource:
            // Block absorb / dodge / resource chips have no dedicated SFX in v1.
            return nil
        case .heal:
            return SFXID.heal
        case .deathsDoor:
            return SFXID.deathsDoor
        case .control:
            return controlClipID(for: item.keyword)
        case .buff:
            return buffFamilyClipID(for: item)
        case .directDamage, .critical, .dot:
            return damageClipID(for: item.keyword)
        }
    }

    private static func controlClipID(for keyword: Keyword) -> String {
        switch keyword {
        case .freeze:
            return SFXID.controlFreeze
        case .stun:
            return SFXID.controlStun
        default:
            return SFXID.controlStun
        }
    }

    private static func buffFamilyClipID(for item: CombatFeedbackItem) -> String {
        // Cleanse/purge are classified as `.buff` for chip motion; route by keyword/text.
        if item.text.hasPrefix("Cleanse") {
            return SFXID.heal
        }
        if item.text.hasPrefix("Purge") {
            return SFXID.purge
        }
        switch item.keyword {
        case .block, .armor:
            return SFXID.block
        case .purge:
            return SFXID.purge
        default:
            return SFXID.buff
        }
    }

    private static func damageClipID(for keyword: Keyword) -> String {
        switch keyword {
        case .burn:
            return SFXID.hitBurn
        case .freeze:
            return SFXID.hitFreeze
        case .stun:
            return SFXID.controlStun
        case .physical, .nature, .holy, .poison, .bleed, .leech:
            return SFXID.hit
        default:
            return SFXID.hit
        }
    }
}
