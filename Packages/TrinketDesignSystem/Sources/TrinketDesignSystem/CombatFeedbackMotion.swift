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

    public static let rest = CombatantAttackPose()
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

    public static func aim(isPartyMember: Bool) -> CombatantAttackAim {
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

    /// Shared vertical pitch for concurrent chips on one combatant.
    /// Sized for ~title/largeTitle chip height at peak scale so lanes don't collide.
    public static let presentationLaneSpacing: CGFloat = 54

    /// Floor spacing used when packing dense (5–6 chip) clusters inside art.
    public static let presentationLaneSpacingFloor: CGFloat = 34

    /// Individual chips kept before collapsing the rest into one overflow chip.
    public static let maxVisibleIndividualChips = 5

    /// Base horizontal fan amplitude; grows slightly for deeper lanes.
    public static let presentationFanAmplitude: CGFloat = 20

    /// Density-aware lane pitch: full spacing for sparse groups, floor at 6+.
    public static func presentationSpacing(forCount count: Int) -> CGFloat {
        let clamped = max(1, count)
        guard clamped > 3 else { return presentationLaneSpacing }
        let t = min(1, CGFloat(clamped - 3) / 3)
        return presentationLaneSpacing
            + (presentationLaneSpacingFloor - presentationLaneSpacing) * t
    }

    /// Scales float travel so dense packs stay inside the art band.
    /// Sparse (≤3) keeps full rise; dense lerps toward ~0.55.
    public static func floatTravelScale(forCount count: Int) -> CGFloat {
        let clamped = max(1, count)
        guard clamped >= 4 else { return 1 }
        let t = min(1, CGFloat(clamped - 3) / 3)
        return 0.7 - 0.15 * t
    }

    /// Fan amplitude shrinks slightly for dense groups so long labels stay on-art.
    public static func presentationFanAmplitude(forCount count: Int) -> CGFloat {
        let clamped = max(1, count)
        guard clamped > 3 else { return presentationFanAmplitude }
        let t = min(1, CGFloat(clamped - 3) / 3)
        return presentationFanAmplitude * (1 - 0.35 * t)
    }

    /// Centered vertical lanes: index 0 at mid, then alternate up/down (±1, ±2…).
    /// Stable by index so rows do not jump when siblings expire.
    public static func presentationOffset(
        index: Int,
        count: Int = 1,
        spacing: CGFloat? = nil
    ) -> CGFloat {
        let pitch = spacing ?? presentationSpacing(forCount: count)
        guard index > 0 else { return 0 }
        let ring = (index + 1) / 2
        let sign: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        return sign * CGFloat(ring) * pitch
    }

    /// Deterministic left/right fan so multi-emit bursts read as a cluster,
    /// not a single overlapping column. Index 0 stays centered.
    public static func presentationHorizontalFan(
        index: Int,
        count: Int = 1,
        amplitude: CGFloat? = nil
    ) -> CGFloat {
        guard index > 0 else { return 0 }
        let amp = amplitude ?? presentationFanAmplitude(forCount: count)
        let sign: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        let magnitude = amp + CGFloat((index - 1) / 2) * 8
        return sign * magnitude
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
