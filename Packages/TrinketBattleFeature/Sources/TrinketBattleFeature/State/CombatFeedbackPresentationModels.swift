import CoreGraphics
import Foundation
import SwiftUI
import TrinketCore

/// Semantic classes for floating combat chips. Feature code maps engine events → these.
enum CombatFeedbackClass: String, CaseIterable, Sendable, Equatable {
    case directDamage
    case critical
    case dot
    case heal
    case block
    case dodge
    case control
    case buff
    case resource
    case deathsDoor
}

/// Visual hierarchy inside one synchronized combat-feedback action group.
enum CombatFeedbackPresentationRole: String, CaseIterable, Sendable, Equatable {
    case headline
    case secondary
}

/// One keyframe sample for a combat-chip motion track.
struct CombatFeedbackKeyframeSample: Sendable, Equatable {
    let value: Double
    let duration: TimeInterval
    let usesSpring: Bool

    init(value: Double, duration: TimeInterval, usesSpring: Bool = true) {
        self.value = value
        self.duration = duration
        self.usesSpring = usesSpring
    }
}

/// The two chip typography tiers. Single source for class→font mapping:
/// emphasis heavy / largeTitle (critical, deaths door), normal bold / title for the rest.
enum CombatFeedbackTypographyTier: Hashable, CaseIterable, Sendable {
    case emphasis
    case normal

    var fontWeight: Font.Weight {
        switch self {
        case .emphasis: .heavy
        case .normal: .bold
        }
    }

    var textStyle: Font.TextStyle {
        switch self {
        case .emphasis: .largeTitle
        case .normal: .title
        }
    }
}

extension CombatFeedbackClass {
    /// Which typography tier renders this feedback class.
    var typographyTier: CombatFeedbackTypographyTier {
        switch self {
        case .critical, .deathsDoor:
            .emphasis
        case .directDamage, .heal, .dot, .block, .dodge, .control, .buff, .resource:
            .normal
        }
    }
}

/// Visual styling for a floating combat chip class. All chips share one motion path.
struct CombatFeedbackChipStyle: Sendable, Equatable {
    let feedbackClass: CombatFeedbackClass
    let fontWeight: Font.Weight
    /// Dynamic Type text style for the primary float label (rounded + monospaced digits).
    let textStyle: Font.TextStyle

    /// Chip styling derived from the shared typography tier mapping.
    static func forClass(_ feedbackClass: CombatFeedbackClass) -> Self {
        let tier = feedbackClass.typographyTier
        return Self(
            feedbackClass: feedbackClass,
            fontWeight: tier.fontWeight,
            textStyle: tier.textStyle
        )
    }
}

/// Card-body hit reaction kinds paired with floating chips.
enum CombatantHitReactionKind: String, CaseIterable, Sendable, Equatable {
    case none
    case damage
    case critical
    case block
    case heal
    case dodge
    case celebrate
}

/// Short transform recipe for combatant card artwork on hit.
struct CombatantHitReactionRecipe: Sendable, Equatable {
    let kind: CombatantHitReactionKind
    let scaleX: [CombatFeedbackKeyframeSample]
    let scaleY: [CombatFeedbackKeyframeSample]
    let offsetX: [CombatFeedbackKeyframeSample]
    let offsetY: [CombatFeedbackKeyframeSample]
    let rotation: [CombatFeedbackKeyframeSample]
    let duration: TimeInterval

    init(
        kind: CombatantHitReactionKind,
        scaleX: [CombatFeedbackKeyframeSample],
        scaleY: [CombatFeedbackKeyframeSample],
        offsetX: [CombatFeedbackKeyframeSample],
        offsetY: [CombatFeedbackKeyframeSample],
        rotation: [CombatFeedbackKeyframeSample] = [],
        duration: TimeInterval
    ) {
        self.kind = kind
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.rotation = rotation
        self.duration = duration
    }

    var impactDuration: TimeInterval {
        scaleX[safe: 0]?.duration ?? 0.08
    }

    var recoveryDuration: TimeInterval {
        scaleX[safe: 1]?.duration ?? 0.16
    }

    var rawImpactScaleX: Double {
        scaleX[safe: 0]?.value ?? 1.0
    }

    var rawImpactScaleY: Double {
        scaleY[safe: 0]?.value ?? 1.0
    }

    var rawImpactOffsetX: Double {
        offsetX[safe: 0]?.value ?? 0.0
    }

    var rawImpactOffsetY: Double {
        offsetY[safe: 0]?.value ?? 0.0
    }

    var recoveryScaleX: Double {
        scaleX[safe: 1]?.value ?? 1.0
    }

    var recoveryScaleY: Double {
        scaleY[safe: 1]?.value ?? 1.0
    }

    var recoverOffsetX: Double {
        offsetX[safe: 1]?.value ?? 0.0
    }

    var recoverOffsetY: Double {
        offsetY[safe: 1]?.value ?? 0.0
    }
}

/// Whole-card attack telegraph kinds (enemy lunge before resolve).
enum CombatantAttackReactionKind: String, CaseIterable, Sendable, Equatable {
    case none
    case attack
}

/// Attack telegraph phase. Party uses wind-up → swing/cancel; enemy uses `.full`.
enum CombatantAttackPhase: String, CaseIterable, Sendable, Equatable {
    case windUp
    case swing
    case cancel
    case full
}

/// Live transform pose for interruptible attack springs.
struct CombatantAttackPose: Sendable, Equatable {
    var scaleX: Double
    var scaleY: Double
    var offsetX: Double
    var offsetY: Double
    var rotation: Double

    init(
        scaleX: Double = 1,
        scaleY: Double = 1,
        offsetX: Double = 0,
        offsetY: Double = 0,
        rotation: Double = 0
    ) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.rotation = rotation
    }

    static let rest = Self()
}

/// Attack aim: recipe Y is authored for enemy→party (down). Party flips Y toward the enemy.
enum CombatantAttackAim: String, CaseIterable, Sendable, Equatable {
    case towardParty
    case towardEnemy

    func aimedOffsetY(_ recipeOffsetY: Double) -> Double {
        switch self {
        case .towardParty: recipeOffsetY
        case .towardEnemy: -recipeOffsetY
        }
    }

    static func aim(isPartyMember: Bool) -> Self {
        isPartyMember ? .towardEnemy : .towardParty
    }
}

/// Transform recipe for a combatant card attacking (art + bars + border).
/// Keyframes are wind-up → swing → recover; `impactDelay` is when resolve should fire.
struct CombatantAttackReactionRecipe: Sendable, Equatable {
    let kind: CombatantAttackReactionKind
    let scaleX: [CombatFeedbackKeyframeSample]
    let scaleY: [CombatFeedbackKeyframeSample]
    let offsetX: [CombatFeedbackKeyframeSample]
    let offsetY: [CombatFeedbackKeyframeSample]
    let rotation: [CombatFeedbackKeyframeSample]
    /// Time from animation start to swing peak (wind-up + swing durations).
    let impactDelay: TimeInterval
    let duration: TimeInterval

    init(
        kind: CombatantAttackReactionKind,
        scaleX: [CombatFeedbackKeyframeSample],
        scaleY: [CombatFeedbackKeyframeSample],
        offsetX: [CombatFeedbackKeyframeSample],
        offsetY: [CombatFeedbackKeyframeSample],
        rotation: [CombatFeedbackKeyframeSample] = [],
        impactDelay: TimeInterval,
        duration: TimeInterval
    ) {
        self.kind = kind
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.rotation = rotation
        self.impactDelay = impactDelay
        self.duration = duration
    }

    var windUpDuration: TimeInterval {
        scaleX[safe: 0]?.duration ?? 0.01
    }

    var swingDuration: TimeInterval {
        scaleX[safe: 1]?.duration ?? 0.01
    }

    var recoverDuration: TimeInterval {
        scaleX[safe: 2]?.duration ?? 0.01
    }

    func windUpPose(aim: CombatantAttackAim) -> CombatantAttackPose {
        pose(at: 0, aim: aim)
    }

    func swingPose(aim: CombatantAttackAim) -> CombatantAttackPose {
        pose(at: 1, aim: aim)
    }

    var restPose: CombatantAttackPose {
        .rest
    }

    private func pose(at index: Int, aim: CombatantAttackAim) -> CombatantAttackPose {
        CombatantAttackPose(
            scaleX: scaleX[safe: index]?.value ?? 1,
            scaleY: scaleY[safe: index]?.value ?? 1,
            offsetX: offsetX[safe: index]?.value ?? 0,
            offsetY: aim.aimedOffsetY(offsetY[safe: index]?.value ?? 0),
            rotation: rotation[safe: index]?.value ?? 0
        )
    }
}

/// Vertical recoil direction for damage/critical portrait hit reactions.
/// Enemy cards kick up; party cards (hero/pet) kick down toward the hand edge.
enum CombatantHitRecoilDirection: String, CaseIterable, Sendable, Equatable {
    case up
    case down

    /// Impact translation for damage/critical hits. Non-impact kinds use recipe offsets.
    @inlinable
    func impactOffset(magnitude: CGFloat) -> CGSize {
        switch self {
        case .up:
            CGSize(width: 0, height: -magnitude)
        case .down:
            CGSize(width: 0, height: magnitude)
        }
    }

    /// Impact scale axes for damage/critical squash.
    /// `.up` swaps recipe axes (horizontal compress / vertical stretch).
    /// `.down` keeps recipe axes (vertical compress / horizontal stretch).
    @inlinable
    func impactScales(
        scaleX: Double,
        scaleY: Double
    ) -> (x: Double, y: Double) {
        switch self {
        case .up:
            (scaleY, scaleX)
        case .down:
            (scaleX, scaleY)
        }
    }
}

/// Shared constants for the fixed-anchor floating combat text presentation.
enum CombatFeedbackLayout: Sendable {
    /// Minimum vertical clearance between simultaneously visible chips in one stream.
    static let streamGap: CGFloat = 4

    /// Stable pseudo-random value in `0...1` shared by non-pathing visual effects.
    @inlinable
    static func unitNoise(seed: Int) -> CGFloat {
        let mixed = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15
        let shifted = mixed ^ (mixed >> 33)
        return CGFloat(shifted % 10000) / 10000
    }
}
