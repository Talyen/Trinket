import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

enum CombatSFXMapper {
    private static let typedHitClipIDs: Set<String> = [
        SFXID.hitBurn,
        SFXID.hitFreeze,
    ]

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
