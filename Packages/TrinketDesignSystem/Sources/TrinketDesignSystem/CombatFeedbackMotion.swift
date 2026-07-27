import CoreGraphics
import Foundation
import SwiftUI

/// Semantic classes for floating combat chips. Feature code maps engine events → these.
public enum CombatFeedbackClass: String, CaseIterable, Sendable, Equatable {
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

/// Glass chip chrome weight for combat feedback.
public enum ChipChromeRole: String, CaseIterable, Sendable, Equatable {
    case standard
    case compact
    case emphasis
    case utility
}

/// Visual hierarchy inside one synchronized combat-feedback action group.
public enum CombatFeedbackPresentationRole: String, CaseIterable, Sendable, Equatable {
    case headline
    case secondary
}

/// One keyframe sample for a combat-chip motion track.
public struct CombatFeedbackKeyframeSample: Sendable, Equatable {
    public let value: Double
    public let duration: TimeInterval
    public let usesSpring: Bool

    public init(value: Double, duration: TimeInterval, usesSpring: Bool = true) {
        self.value = value
        self.duration = duration
        self.usesSpring = usesSpring
    }
}

/// Visual styling for a floating combat chip class. All chips share one motion path.
public struct CombatFeedbackChipStyle: Sendable, Equatable {
    public let feedbackClass: CombatFeedbackClass
    public let chrome: ChipChromeRole
    public let fontWeight: Font.Weight
    /// Dynamic Type text style for the primary float label (rounded + monospaced digits).
    public let textStyle: Font.TextStyle
    public let bouncesSymbol: Bool
    public let showsSecondaryCaption: Bool

    public init(
        feedbackClass: CombatFeedbackClass,
        chrome: ChipChromeRole,
        fontWeight: Font.Weight,
        textStyle: Font.TextStyle,
        bouncesSymbol: Bool,
        showsSecondaryCaption: Bool
    ) {
        self.feedbackClass = feedbackClass
        self.chrome = chrome
        self.fontWeight = fontWeight
        self.textStyle = textStyle
        self.bouncesSymbol = bouncesSymbol
        self.showsSecondaryCaption = showsSecondaryCaption
    }

    public func font(for role: CombatFeedbackPresentationRole) -> Font {
        let style: Font.TextStyle
        let weight: Font.Weight
        switch role {
        case .headline:
            style = textStyle
            weight = fontWeight
        case .secondary:
            style = .title2
            weight = .bold
        }
        return .system(style, design: .rounded)
            .weight(weight)
            .monospacedDigit()
    }

    public var font: Font {
        font(for: .headline)
    }
}

/// Card-body hit reaction kinds paired with floating chips.
public enum CombatantHitReactionKind: String, CaseIterable, Sendable, Equatable {
    case none
    case damage
    case critical
    case block
    case heal
    case dodge
    case celebrate
}

/// Short transform recipe for combatant card artwork on hit.
public struct CombatantHitReactionRecipe: Sendable, Equatable {
    public let kind: CombatantHitReactionKind
    public let scaleX: [CombatFeedbackKeyframeSample]
    public let scaleY: [CombatFeedbackKeyframeSample]
    public let offsetX: [CombatFeedbackKeyframeSample]
    public let offsetY: [CombatFeedbackKeyframeSample]
    public let rotation: [CombatFeedbackKeyframeSample]
    public let duration: TimeInterval

    public init(
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
}

/// Whole-card attack telegraph kinds (enemy lunge before resolve).
public enum CombatantAttackReactionKind: String, CaseIterable, Sendable, Equatable {
    case none
    case attack
}

/// Attack telegraph phase. Party uses wind-up → swing/cancel; enemy uses `.full`.
public enum CombatantAttackPhase: String, CaseIterable, Sendable, Equatable {
    case windUp
    case swing
    case cancel
    case full
}

/// Live transform pose for interruptible attack springs.
public struct CombatantAttackPose: Sendable, Equatable {
    public var scaleX: Double
    public var scaleY: Double
    public var offsetX: Double
    public var offsetY: Double
    public var rotation: Double

    public init(
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

    public static let rest = Self()
}

/// Attack aim: recipe Y is authored for enemy→party (down). Party flips Y toward the enemy.
public enum CombatantAttackAim: String, CaseIterable, Sendable, Equatable {
    case towardParty
    case towardEnemy

    public func aimedOffsetY(_ recipeOffsetY: Double) -> Double {
        switch self {
        case .towardParty: recipeOffsetY
        case .towardEnemy: -recipeOffsetY
        }
    }

    public static func aim(isPartyMember: Bool) -> Self {
        isPartyMember ? .towardEnemy : .towardParty
    }
}

/// Transform recipe for a combatant card attacking (art + bars + border).
/// Keyframes are wind-up → swing → recover; `impactDelay` is when resolve should fire.
public struct CombatantAttackReactionRecipe: Sendable, Equatable {
    public let kind: CombatantAttackReactionKind
    public let scaleX: [CombatFeedbackKeyframeSample]
    public let scaleY: [CombatFeedbackKeyframeSample]
    public let offsetX: [CombatFeedbackKeyframeSample]
    public let offsetY: [CombatFeedbackKeyframeSample]
    public let rotation: [CombatFeedbackKeyframeSample]
    /// Time from animation start to swing peak (wind-up + swing durations).
    public let impactDelay: TimeInterval
    public let duration: TimeInterval

    public init(
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

    public var windUpDuration: TimeInterval {
        scaleX[safe: 0]?.duration ?? 0.01
    }

    public var swingDuration: TimeInterval {
        scaleX[safe: 1]?.duration ?? 0.01
    }

    public var recoverDuration: TimeInterval {
        scaleX[safe: 2]?.duration ?? 0.01
    }

    public func windUpPose(aim: CombatantAttackAim) -> CombatantAttackPose {
        pose(at: 0, aim: aim)
    }

    public func swingPose(aim: CombatantAttackAim) -> CombatantAttackPose {
        pose(at: 1, aim: aim)
    }

    public var restPose: CombatantAttackPose {
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

/// Vertical recoil direction for damage/critical portrait hit reactions.
/// Enemy cards kick up; party cards (hero/pet) kick down toward the hand edge.
public enum CombatantHitRecoilDirection: String, CaseIterable, Sendable, Equatable {
    case up
    case down

    /// Impact translation for damage/critical hits. Non-impact kinds use recipe offsets.
    public func impactOffset(magnitude: CGFloat) -> CGSize {
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
    public func impactScales(
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
public enum CombatFeedbackLayout: Sendable {
    /// Minimum vertical clearance between simultaneously visible chips in one stream.
    public static let streamGap: CGFloat = 4

    /// Stable pseudo-random value in `0...1` shared by non-pathing visual effects.
    public static func unitNoise(seed: Int) -> CGFloat {
        let mixed = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15
        let shifted = mixed ^ (mixed >> 33)
        return CGFloat(shifted % 10000) / 10000
    }

    public static func particleCount(for feedbackClass: CombatFeedbackClass) -> Int {
        switch feedbackClass {
        case .critical: 8
        case .directDamage, .heal: 5
        case .dot, .block: 3
        case .dodge, .control, .buff, .resource, .deathsDoor: 0
        }
    }
}
