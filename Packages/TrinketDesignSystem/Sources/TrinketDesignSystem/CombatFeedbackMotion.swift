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
    case overflow
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

/// Motion + presentation recipe for a floating combat chip class.
public struct CombatFeedbackMotionRecipe: Sendable, Equatable {
    public let feedbackClass: CombatFeedbackClass
    public let initialScale: Double
    public let initialOpacity: Double
    public let initialOffsetY: Double
    public let initialOffsetX: Double
    public let initialRotation: Double
    public let scale: [CombatFeedbackKeyframeSample]
    public let opacity: [CombatFeedbackKeyframeSample]
    public let offsetY: [CombatFeedbackKeyframeSample]
    public let offsetX: [CombatFeedbackKeyframeSample]
    public let rotation: [CombatFeedbackKeyframeSample]
    public let lifetime: TimeInterval
    public let horizontalJitter: ClosedRange<CGFloat>
    /// Randomized angle away from vertical for the upward float path.
    public let floatAngleRange: ClosedRange<CGFloat>
    public let stackSpacing: CGFloat
    public let chrome: ChipChromeRole
    public let fontWeight: Font.Weight
    /// Dynamic Type text style for the primary float label (rounded + monospaced digits).
    public let textStyle: Font.TextStyle
    public let bouncesSymbol: Bool
    public let showsSecondaryCaption: Bool

    public init(
        feedbackClass: CombatFeedbackClass,
        initialScale: Double = 0.76,
        initialOpacity: Double = 0,
        initialOffsetY: Double = 12,
        initialOffsetX: Double = 0,
        initialRotation: Double = 0,
        scale: [CombatFeedbackKeyframeSample],
        opacity: [CombatFeedbackKeyframeSample],
        offsetY: [CombatFeedbackKeyframeSample],
        offsetX: [CombatFeedbackKeyframeSample] = [],
        rotation: [CombatFeedbackKeyframeSample] = [],
        lifetime: TimeInterval,
        horizontalJitter: ClosedRange<CGFloat>,
        floatAngleRange: ClosedRange<CGFloat> = -26 ... 26,
        stackSpacing: CGFloat,
        chrome: ChipChromeRole,
        fontWeight: Font.Weight,
        textStyle: Font.TextStyle,
        bouncesSymbol: Bool,
        showsSecondaryCaption: Bool
    ) {
        self.feedbackClass = feedbackClass
        self.initialScale = initialScale
        self.initialOpacity = initialOpacity
        self.initialOffsetY = initialOffsetY
        self.initialOffsetX = initialOffsetX
        self.initialRotation = initialRotation
        self.scale = scale
        self.opacity = opacity
        self.offsetY = offsetY
        self.offsetX = offsetX
        self.rotation = rotation
        self.lifetime = lifetime
        self.horizontalJitter = horizontalJitter
        self.floatAngleRange = floatAngleRange
        self.stackSpacing = stackSpacing
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
        case .overflow:
            style = .callout
            weight = .semibold
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
}

/// Short transform recipe for combatant card artwork on hit.
public struct CombatantHitReactionRecipe: Sendable, Equatable {
    public let kind: CombatantHitReactionKind
    public let scaleX: [CombatFeedbackKeyframeSample]
    public let scaleY: [CombatFeedbackKeyframeSample]
    public let offsetX: [CombatFeedbackKeyframeSample]
    public let offsetY: [CombatFeedbackKeyframeSample]
    public let flashOpacity: [CombatFeedbackKeyframeSample]
    public let duration: TimeInterval

    public init(
        kind: CombatantHitReactionKind,
        scaleX: [CombatFeedbackKeyframeSample],
        scaleY: [CombatFeedbackKeyframeSample],
        offsetX: [CombatFeedbackKeyframeSample],
        offsetY: [CombatFeedbackKeyframeSample],
        flashOpacity: [CombatFeedbackKeyframeSample],
        duration: TimeInterval
    ) {
        self.kind = kind
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.flashOpacity = flashOpacity
        self.duration = duration
    }
}

/// Deterministic layout helpers for chip scatter / stacking.
public enum CombatFeedbackLayout: Sendable {
    /// Stable pseudo-random in `0...1` from a positive integer seed.
    public static func unitNoise(seed: Int) -> CGFloat {
        let mixed = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15
        let shifted = (mixed ^ (mixed >> 33))
        return CGFloat(shifted % 10000) / 10000
    }

    public static func horizontalOffset(seed: Int, jitter: ClosedRange<CGFloat>) -> CGFloat {
        guard jitter.upperBound > jitter.lowerBound else { return jitter.lowerBound }
        let t = unitNoise(seed: seed)
        return jitter.lowerBound + (jitter.upperBound - jitter.lowerBound) * t
    }

    /// Stable pseudo-random angle in degrees, measured from the vertical axis.
    public static func floatAngle(seed: Int, range: ClosedRange<CGFloat>) -> CGFloat {
        horizontalOffset(seed: seed, jitter: range)
    }

    /// Horizontal travel needed to rise at `angleDegrees` from vertical.
    public static func horizontalDrift(angleDegrees: CGFloat, verticalTravel: CGFloat) -> CGFloat {
        let radians = Double(angleDegrees) * .pi / 180
        return CGFloat(tan(radians)) * abs(verticalTravel)
    }

    public static func stackOffset(index: Int, spacing: CGFloat) -> CGFloat {
        CGFloat(index) * spacing
    }

    /// Stable vertical lanes prevent rows from jumping when siblings expire.
    public static func presentationOffset(index: Int) -> CGFloat {
        switch index {
        case 0: 0
        case 1: 48
        case 2: 86
        default: 116 + CGFloat(max(0, index - 3)) * 28
        }
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
