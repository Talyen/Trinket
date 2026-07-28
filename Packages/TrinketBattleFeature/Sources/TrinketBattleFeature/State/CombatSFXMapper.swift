import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Maps battle feedback items to curated SFX catalog IDs.
enum CombatSFXMapper {
    /// Keyword-specific hit clips that supersede a concurrent generic `hit`
    /// when that `hit` is only covering non-keyword damage (physical, etc.).
    private static let typedHitClipIDs: Set<String> = [
        SFXID.hitBurn,
        SFXID.hitFreeze,
    ]

    /// Keywords that use the generic `hit` clip as their identity SFX (no typed clip).
    private static let hitAsKeywordIdentity: Set<Keyword> = [
        .poison,
        .bleed,
    ]

    static func clipID(for item: CombatFeedbackItem) -> String? {
        if item.visualRole == .negativeStatus {
            return nil
        }
        return switch item.feedbackClass {
        case .dodge, .block, .resource:
            // Block absorb / dodge / resource chips have no dedicated SFX in v1.
            nil
        case .heal:
            SFXID.heal
        case .deathsDoor:
            SFXID.deathsDoor
        case .control:
            controlClipID(for: item.keyword)
        case .buff:
            buffFamilyClipID(for: item)
        case .directDamage, .critical, .dot:
            damageClipID(for: item.keyword)
        }
    }

    /// Unique clip IDs for a presentation batch: one play per clip. Typed hits
    /// suppress a concurrent generic `hit` unless that `hit` is the keyword SFX
    /// for poison/bleed (so burn + poison can still both play).
    static func uniqueClipIDs(for items: [CombatFeedbackItem]) -> [String] {
        var clips: [String] = []
        var seen: Set<String> = []
        var hasTypedHit = false
        var hasSuppressibleGenericHit = false
        var hasHitAsKeywordSFX = false

        for item in items {
            guard let clipID = clipID(for: item) else { continue }

            if typedHitClipIDs.contains(clipID) {
                hasTypedHit = true
            }
            if clipID == SFXID.hit {
                if hitAsKeywordIdentity.contains(item.keyword) {
                    hasHitAsKeywordSFX = true
                } else {
                    hasSuppressibleGenericHit = true
                }
            }

            guard seen.insert(clipID).inserted else { continue }
            clips.append(clipID)
        }

        if hasTypedHit, hasSuppressibleGenericHit, !hasHitAsKeywordSFX {
            clips.removeAll { $0 == SFXID.hit }
        }
        return clips
    }

    private static func controlClipID(for keyword: Keyword) -> String {
        switch keyword {
        case .freeze:
            SFXID.controlFreeze
        case .stun:
            SFXID.controlStun
        default:
            SFXID.controlStun
        }
    }

    private static func buffFamilyClipID(for item: CombatFeedbackItem) -> String {
        // Cleanse/purge are classified as `.buff` for chip motion; route by label case.
        if case .word(.cleanse) = item.label {
            return SFXID.heal
        }
        if case .word(.purge) = item.label {
            return SFXID.purge
        }
        switch item.keyword {
        case .block:
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
            SFXID.hitBurn
        case .freeze:
            SFXID.hitFreeze
        case .stun:
            SFXID.controlStun
        case .physical, .holy, .poison, .bleed, .leech:
            SFXID.hit
        default:
            SFXID.hit
        }
    }
}
