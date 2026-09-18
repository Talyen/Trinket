import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

enum CombatSFXMapper {
    /// Battle-warm set: every mapper output plus battle-flow stingers.
    /// Owned here — not in TrinketContent — because battle event interpretation
    /// is BattleFeature's concern; TrinketContent only owns the clip catalog.
    /// When adding a Keyword, update `controlClipID` and `damageClipID`
    /// together, then extend this list if the new mapping adds an output.
    static let battlePrewarmIDs = [
        SFXID.abilityDraw,
        SFXID.hit,
        SFXID.hitBurn,
        SFXID.hitFreeze,
        SFXID.heal,
        SFXID.buff,
        SFXID.block,
        SFXID.controlFreeze,
        SFXID.controlStun,
        SFXID.purge,
        SFXID.deathsDoor,
        SFXID.victory,
        SFXID.defeat,
    ]

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

    static func uniqueClipIDs(for items: [CombatFeedbackItem], damageKeywords: [Keyword] = []) -> [String] {
        var clips: [String] = []
        var seen: Set<String> = []
        var hasTypedHit = false
        var hasSuppressibleGenericHit = false
        var hasHitAsKeywordSFX = false

        let candidates = items.compactMap { item in clipID(for: item).map { (item.keyword, $0) } }
            + damageKeywords.map { ($0, damageClipID(for: $0)) }
        for (keyword, clipID) in candidates {
            if typedHitClipIDs.contains(clipID) {
                hasTypedHit = true
            }
            if clipID == SFXID.hit {
                if hitAsKeywordIdentity.contains(keyword) {
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
        case .physical, .burn, .holy, .poison, .bleed, .leech, .thorns, .health,
             .gold, .block, .dodge, .purge, .cleanse, .mana, .deathsDoor:
            // No dedicated stinger: fall back to the generic control hit so a
            // control event is never silent. Exhaustive so a new Keyword forces
            // an explicit choice here instead of silently taking this branch.
            SFXID.controlStun
        }
    }

    private static func buffFamilyClipID(for item: CombatFeedbackItem) -> String {
        // Label wins over keyword: a cleanse/purge word describes the event
        // even when the underlying keyword is something else (e.g. block).
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
        case .physical, .holy, .poison, .bleed, .leech, .thorns, .health, .gold,
             .block, .dodge, .purge, .cleanse, .mana, .deathsDoor:
            // Exhaustive so a new Keyword forces an explicit choice here.
            SFXID.hit
        }
    }
}
