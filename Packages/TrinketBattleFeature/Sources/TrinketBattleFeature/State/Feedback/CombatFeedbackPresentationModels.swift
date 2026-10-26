import CoreGraphics
import Foundation
import TrinketCore

enum CombatFeedbackClass: String, CaseIterable, Hashable {
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

struct CombatFeedbackKeyframeSample: Equatable {
    let value: Double
    let duration: TimeInterval
}

struct CombatFeedbackAppearance: Hashable {
    let typography: CombatFeedbackTypographyTier
    let presentation: CombatFeedbackChipPresentation

    init(feedbackClass: CombatFeedbackClass, presentation: CombatFeedbackChipPresentation) {
        typography = feedbackClass.typographyTier
        self.presentation = presentation
    }

    init(item: CombatFeedbackItem) {
        self.init(feedbackClass: item.feedbackClass, presentation: item.chipPresentation)
    }
}

enum CombatFeedbackTypographyTier: Hashable, CaseIterable {
    case emphasis
    case normal
}

extension CombatFeedbackClass {
    var typographyTier: CombatFeedbackTypographyTier {
        switch self {
        case .critical, .deathsDoor:
            .emphasis
        case .directDamage, .heal, .dot, .block, .dodge, .control, .buff, .resource:
            .normal
        }
    }
}

enum CombatantHitReactionKind: String, CaseIterable, Equatable {
    case none
    case damage
    case critical
    case block
    case heal
    case dodge
    case celebrate

    var priority: Int {
        switch self {
        case .critical: 5
        case .damage: 4
        case .block: 3
        case .dodge: 2
        case .heal, .celebrate: 1
        case .none: 0
        }
    }
}

struct CombatantMotionPhase: Equatable {
    let pose: CombatantPose
    let duration: TimeInterval
}

struct CombatantHitReactionRecipe: Equatable {
    let kind: CombatantHitReactionKind
    let impact: CombatantMotionPhase
    let recovery: CombatantMotionPhase
    var rotation: [CombatFeedbackKeyframeSample] = []
    /// Scheduling lifetime is independent of the transform phases (notably celebration and no reaction).
    let duration: TimeInterval
}

enum CombatantAttackPhase: String, CaseIterable, Equatable {
    case windUp
    case swing
    case cancel
    case recover
    case rest
}

struct CombatantPose: Equatable {
    var scaleX: Double
    var scaleY: Double
    var offsetX: Double
    var offsetY: Double
    var rotation: Double
    var rotationX: Double

    init(
        scaleX: Double = 1,
        scaleY: Double = 1,
        offsetX: Double = 0,
        offsetY: Double = 0,
        rotation: Double = 0,
        rotationX: Double = 0,
    ) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.rotation = rotation
        self.rotationX = rotationX
    }

    static let rest = Self()

    func aimed(_ aim: CombatantAttackAim) -> Self {
        var pose = self
        pose.offsetY = aim.aimedOffsetY(offsetY)
        return pose
    }
}

enum CombatantAttackAim: String, CaseIterable, Equatable {
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

struct CombatantAttackReactionRecipe: Equatable {
    let windUp: CombatantMotionPhase
    let swing: CombatantMotionPhase
    let recovery: CombatantMotionPhase
}

enum CombatantHitRecoilDirection: String, CaseIterable, Equatable {
    case up
    case down

    @inlinable
    func impactOffset(magnitude: CGFloat) -> CGSize {
        switch self {
        case .up:
            CGSize(width: 0, height: -magnitude)
        case .down:
            CGSize(width: 0, height: magnitude)
        }
    }

    @inlinable
    func impactScales(
        scaleX: Double,
        scaleY: Double,
    ) -> (x: Double, y: Double) {
        switch self {
        case .up:
            (scaleY, scaleX)
        case .down:
            (scaleX, scaleY)
        }
    }
}

enum CombatFeedbackLayout {
    @inlinable
    static func unitNoise(seed: Int) -> CGFloat {
        let mixed = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15
        let shifted = mixed ^ (mixed >> 33)
        return CGFloat(shifted % 10000) / 10000
    }
}
