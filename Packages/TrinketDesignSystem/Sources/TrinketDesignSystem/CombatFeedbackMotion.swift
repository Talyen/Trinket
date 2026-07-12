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
    public let scale: [CombatFeedbackKeyframeSample]
    public let opacity: [CombatFeedbackKeyframeSample]
    public let offsetY: [CombatFeedbackKeyframeSample]
    public let offsetX: [CombatFeedbackKeyframeSample]
    public let rotation: [CombatFeedbackKeyframeSample]
    public let lifetime: TimeInterval
    public let horizontalJitter: ClosedRange<CGFloat>
    public let stackSpacing: CGFloat
    public let chrome: ChipChromeRole
    public let fontWeight: Font.Weight
    /// Dynamic Type text style for the primary float label (rounded + monospaced digits).
    public let textStyle: Font.TextStyle
    public let bouncesSymbol: Bool
    public let showsSecondaryCaption: Bool

    public init(
        feedbackClass: CombatFeedbackClass,
        scale: [CombatFeedbackKeyframeSample],
        opacity: [CombatFeedbackKeyframeSample],
        offsetY: [CombatFeedbackKeyframeSample],
        offsetX: [CombatFeedbackKeyframeSample] = [],
        rotation: [CombatFeedbackKeyframeSample] = [],
        lifetime: TimeInterval,
        horizontalJitter: ClosedRange<CGFloat>,
        stackSpacing: CGFloat,
        chrome: ChipChromeRole,
        fontWeight: Font.Weight,
        textStyle: Font.TextStyle,
        bouncesSymbol: Bool,
        showsSecondaryCaption: Bool
    ) {
        self.feedbackClass = feedbackClass
        self.scale = scale
        self.opacity = opacity
        self.offsetY = offsetY
        self.offsetX = offsetX
        self.rotation = rotation
        self.lifetime = lifetime
        self.horizontalJitter = horizontalJitter
        self.stackSpacing = stackSpacing
        self.chrome = chrome
        self.fontWeight = fontWeight
        self.textStyle = textStyle
        self.bouncesSymbol = bouncesSymbol
        self.showsSecondaryCaption = showsSecondaryCaption
    }

    public var font: Font {
        .system(textStyle, design: .rounded)
            .weight(fontWeight)
            .monospacedDigit()
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
    public let scale: [CombatFeedbackKeyframeSample]
    public let offsetX: [CombatFeedbackKeyframeSample]
    public let flashOpacity: [CombatFeedbackKeyframeSample]
    public let duration: TimeInterval

    public init(
        kind: CombatantHitReactionKind,
        scale: [CombatFeedbackKeyframeSample],
        offsetX: [CombatFeedbackKeyframeSample],
        flashOpacity: [CombatFeedbackKeyframeSample],
        duration: TimeInterval
    ) {
        self.kind = kind
        self.scale = scale
        self.offsetX = offsetX
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

    public static func stackOffset(index: Int, spacing: CGFloat) -> CGFloat {
        CGFloat(index) * spacing
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
