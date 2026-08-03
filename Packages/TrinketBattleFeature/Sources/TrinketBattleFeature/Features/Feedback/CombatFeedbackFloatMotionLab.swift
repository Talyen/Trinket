import CoreGraphics
import Foundation
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

#if DEBUG
// DEBUG playground only — production motion lives in recipe/config types. Do not ship lab UI.

// Lab-only tunable recipe + candidate presets (not production surface).

/// Tunable floating-combat-text motion recipe for the DEBUG Float Motion Lab.
///
/// Defaults match production Ideal Core (`TrinketMotion.Battle`).
/// The lab mutates a copy; promote dialed-in values into production sampling
/// after picking a winner.
private struct CombatFeedbackFloatMotionConfiguration: Equatable {
    enum VerticalDirection: String, CaseIterable, Identifiable {
        case up
        case down

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .up: "Up"
            case .down: "Down"
            }
        }
    }

    enum Easing: String, CaseIterable, Identifiable {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case power

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .linear: "Linear"
            case .easeIn: "Ease In"
            case .easeOut: "Ease Out"
            case .easeInOut: "Ease In-Out"
            case .power: "Power"
            }
        }
    }

    struct Pose: Equatable {
        var opacity: Double
        var offsetX: CGFloat
        var offsetY: CGFloat
        var scale: CGFloat
        var rotationDegrees: Double
    }

    // MARK: Timing

    var duration: TimeInterval = TrinketMotion.Battle.chipDisplayDuration
    var fadeOutDuration: TimeInterval = TrinketMotion.Battle.chipFadeOutDuration
    /// Fraction of `duration` that stays fully opaque before fade begins.
    var opaqueHoldFraction: Double = TrinketMotion.Battle.chipOpaqueHoldFraction
    /// Fraction of `duration` spent parked at origin before vertical travel begins.
    var riseDelayFraction: Double = 0

    // MARK: Path

    var travelFraction: CGFloat = TrinketMotion.Battle.chipTravelFraction
    var verticalDirection: VerticalDirection = .up
    /// Constant horizontal bias as a fraction of chip width (negative = left).
    var lateralBias: CGFloat = 0
    /// Peak lateral arc as a fraction of chip width (parabola mid-flight).
    var arcAmplitude: CGFloat = 0
    /// Lateral sine amplitude as a fraction of chip width.
    var driftAmplitude: CGFloat = 0
    var driftFrequency: Double = 2
    /// Extra rise past travel, then drop back by this fraction near the end (0 = none).
    var settleAmount: CGFloat = 0

    // MARK: Easing

    var easing: Easing = .easeOut
    var easingPower: Double = 2

    // MARK: Scale

    var startScale: CGFloat = TrinketMotion.Battle.chipStartScale
    var peakScale: CGFloat = TrinketMotion.Battle.chipPeakScale
    var endScale: CGFloat = TrinketMotion.Battle.chipEndScale
    var peakProgress: Double = TrinketMotion.Battle.chipPeakProgress

    // MARK: Rotation

    var startRotation: Double = 0
    var endRotation: Double = 0
    var shakeAmplitude: Double = 0
    var shakeFrequency: Double = 8

    // MARK: Travel

    func travelDistance(cardHeight: CGFloat, chipHeight: CGFloat) -> CGFloat {
        let proportionalTravel = cardHeight * travelFraction
        let topSafeTravel = cardHeight / 2 - chipHeight / 2 - TrinketMotion.Battle.chipTopClearance
        return max(0, min(proportionalTravel, topSafeTravel))
    }

    // MARK: Sampling

    func sample(
        elapsed: TimeInterval,
        seed: Int,
        chipWidth: CGFloat,
        travelDistance: CGFloat
    ) -> Pose {
        let t = min(max(elapsed / max(duration, 0.001), 0), 1)
        let delay = min(max(riseDelayFraction, 0), 0.95)
        let riseWindow = max(1 - delay, 0.001)
        let riseT = t <= delay ? 0 : min((t - delay) / riseWindow, 1)
        let easedRise = applyEasing(riseT)
        let noise = CombatFeedbackLayout.unitNoise(seed: seed)
        let phase = Double(noise) * .pi * 2
        let arcSign: CGFloat = noise < 0.5 ? -1 : 1

        let biasX = lateralBias * chipWidth
        let arcX = arcAmplitude * chipWidth * 4 * easedRise * (1 - easedRise) * arcSign
        let driftX = driftAmplitude * chipWidth
            * CGFloat(sin(2 * Double.pi * driftFrequency * Double(riseT) + phase))
        let offsetX = biasX + arcX + driftX

        let riseProgress = verticalProgress(eased: easedRise)
        let ySign: CGFloat = verticalDirection == .up ? -1 : 1
        let offsetY = ySign * travelDistance * riseProgress

        let baseRotation = startRotation + (endRotation - startRotation) * easedRise
        let shake = shakeAmplitude
            * sin(2 * Double.pi * shakeFrequency * Double(t) + phase * 1.7)

        return Pose(
            opacity: opacity(elapsed: elapsed),
            offsetX: offsetX,
            offsetY: offsetY,
            scale: scale(at: t),
            rotationDegrees: baseRotation + shake
        )
    }

    /// Paste-friendly dump of every knob for promoting lab values into production.
    func parameterDump() -> String {
        """
        // Timing
        duration: \(fmt(duration))
        fadeOutDuration: \(fmt(fadeOutDuration))
        opaqueHoldFraction: \(fmt(opaqueHoldFraction))
        riseDelayFraction: \(fmt(riseDelayFraction))

        // Path
        travelFraction: \(fmt(travelFraction))
        verticalDirection: \(verticalDirection.rawValue)
        lateralBias: \(fmt(lateralBias))
        arcAmplitude: \(fmt(arcAmplitude))
        driftAmplitude: \(fmt(driftAmplitude))
        driftFrequency: \(fmt(driftFrequency))
        settleAmount: \(fmt(settleAmount))

        // Easing
        easing: \(easing.rawValue)
        easingPower: \(fmt(easingPower))

        // Scale
        startScale: \(fmt(startScale))
        peakScale: \(fmt(peakScale))
        endScale: \(fmt(endScale))
        peakProgress: \(fmt(peakProgress))

        // Rotation
        startRotation: \(fmt(startRotation))
        endRotation: \(fmt(endRotation))
        shakeAmplitude: \(fmt(shakeAmplitude))
        shakeFrequency: \(fmt(shakeFrequency))
        """
    }

    // MARK: Private

    private func applyEasing(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        switch easing {
        case .linear:
            return clamped
        case .easeIn:
            return clamped * clamped
        case .easeOut:
            let inv = 1 - clamped
            return 1 - inv * inv
        case .easeInOut:
            if clamped < 0.5 {
                return 2 * clamped * clamped
            }
            let inv = -2 * clamped + 2
            return 1 - (inv * inv) / 2
        case .power:
            return pow(clamped, max(easingPower, 0.01))
        }
    }

    private func verticalProgress(eased: Double) -> CGFloat {
        guard settleAmount > 0 else { return CGFloat(eased) }
        let peak = 1 + settleAmount
        let settleStart = 0.72
        if eased < settleStart {
            return CGFloat(eased / settleStart) * peak
        }
        let u = (eased - settleStart) / (1 - settleStart)
        let settled = 1 - settleAmount * 0.35
        return peak + (settled - peak) * CGFloat(u)
    }

    private func scale(at t: Double) -> CGFloat {
        let peakAt = min(max(peakProgress, 0.001), 0.999)
        if t <= peakAt {
            let u = t / peakAt
            return startScale + (peakScale - startScale) * CGFloat(u)
        }
        let u = (t - peakAt) / (1 - peakAt)
        return peakScale + (endScale - peakScale) * CGFloat(u)
    }

    private func opacity(elapsed: TimeInterval) -> Double {
        let holdEnd = min(duration * opaqueHoldFraction, duration - 0.001)
        guard elapsed > holdEnd else { return 1 }
        let fadeLen = max(min(fadeOutDuration, duration - holdEnd), 0.001)
        return min(max((holdEnd + fadeLen - elapsed) / fadeLen, 0), 1)
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.4g", value)
    }

    private func fmt(_ value: CGFloat) -> String {
        String(format: "%.4g", Double(value))
    }
}

/// Ideal combat-float family: one cohesive recipe plus micro-variations.
///
/// Design intent — immediate readable impact, ease-out rise (never accelerates
/// away), fade only after the number has been readable, pure vertical path.
/// Candidates mainly explore how hard the number punches in and how far it
/// scales down as it rises.
private enum CombatFeedbackFloatMotionIdealCandidate: Int, CaseIterable, Identifiable {
    case core = 1
    case softerImpact
    case firmerImpact
    case growIn
    case holdThenShrink
    case flatScale
    case deepRecede
    case snapPunch
    case slowBloom
    case microBeat

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .core: "1. Ideal Core"
        case .softerImpact: "2. Softer Impact"
        case .firmerImpact: "3. Firmer Impact"
        case .growIn: "4. Grow In"
        case .holdThenShrink: "5. Hold Then Shrink"
        case .flatScale: "6. Flat Scale"
        case .deepRecede: "7. Deep Recede"
        case .snapPunch: "8. Snap Punch"
        case .slowBloom: "9. Slow Bloom"
        case .microBeat: "10. Micro Beat"
        }
    }

    var blurb: String {
        switch self {
        case .core:
            "1.06→1.10→0.96 — balanced punch and settle"
        case .softerImpact:
            "Quieter punch, gentler settle (1.02→1.05→0.98)"
        case .firmerImpact:
            "Stronger punch, clearer settle (1.10→1.18→0.93)"
        case .growIn:
            "Starts small, blooms up, soft settle (0.88→1.10→0.96)"
        case .holdThenShrink:
            "Spawns large, holds, then shrinks while rising"
        case .flatScale:
            "Almost no scale change — motion is rise + fade only"
        case .deepRecede:
            "Solid punch, then stronger scale-down as it rises"
        case .snapPunch:
            "Fast peak early, then settles for the rest of the rise"
        case .slowBloom:
            "Scale peaks later mid-rise, then eases down"
        case .microBeat:
            "Brief park at peak size, then lift + shrink"
        }
    }

    var configuration: CombatFeedbackFloatMotionConfiguration {
        switch self {
        case .core:
            .idealCore
        case .softerImpact:
            .idealVarying(
                from: .idealCore,
                startScale: 1.02,
                peakScale: 1.05,
                endScale: 0.98,
                peakProgress: 0.12
            )
        case .firmerImpact:
            .idealVarying(
                from: .idealCore,
                startScale: 1.10,
                peakScale: 1.18,
                endScale: 0.93,
                peakProgress: 0.09
            )
        case .growIn:
            .idealVarying(
                from: .idealCore,
                startScale: 0.88,
                peakScale: 1.10,
                endScale: 0.96,
                peakProgress: 0.16
            )
        case .holdThenShrink:
            .idealVarying(
                from: .idealCore,
                startScale: 1.16,
                peakScale: 1.16,
                endScale: 0.88,
                peakProgress: 0.22
            )
        case .flatScale:
            .idealVarying(
                from: .idealCore,
                startScale: 1.0,
                peakScale: 1.0,
                endScale: 1.0,
                peakProgress: 0.5
            )
        case .deepRecede:
            .idealVarying(
                from: .idealCore,
                startScale: 1.08,
                peakScale: 1.12,
                endScale: 0.86,
                peakProgress: 0.12
            )
        case .snapPunch:
            .idealVarying(
                from: .idealCore,
                startScale: 0.92,
                peakScale: 1.14,
                endScale: 0.95,
                peakProgress: 0.06
            )
        case .slowBloom:
            .idealVarying(
                from: .idealCore,
                startScale: 0.98,
                peakScale: 1.12,
                endScale: 0.94,
                peakProgress: 0.32
            )
        case .microBeat:
            .idealVarying(
                from: .idealCore,
                duration: 1.06,
                riseDelayFraction: 0.06,
                startScale: 1.14,
                peakScale: 1.14,
                endScale: 0.92,
                peakProgress: 0.08
            )
        }
    }
}

extension CombatFeedbackFloatMotionConfiguration {
    /// Matches production Ideal Core (`TrinketMotion.Battle` float recipe).
    static var idealCore: CombatFeedbackFloatMotionConfiguration {
        CombatFeedbackFloatMotionConfiguration()
    }

    fileprivate static func idealVarying(
        from base: CombatFeedbackFloatMotionConfiguration,
        duration: TimeInterval? = nil,
        fadeOutDuration: TimeInterval? = nil,
        opaqueHoldFraction: Double? = nil,
        riseDelayFraction: Double? = nil,
        travelFraction: CGFloat? = nil,
        startScale: CGFloat? = nil,
        peakScale: CGFloat? = nil,
        endScale: CGFloat? = nil,
        peakProgress: Double? = nil
    ) -> CombatFeedbackFloatMotionConfiguration {
        var config = base
        if let duration {
            config.duration = duration
        }
        if let fadeOutDuration {
            config.fadeOutDuration = fadeOutDuration
        }
        if let opaqueHoldFraction {
            config.opaqueHoldFraction = opaqueHoldFraction
        }
        if let riseDelayFraction {
            config.riseDelayFraction = riseDelayFraction
        }
        if let travelFraction {
            config.travelFraction = travelFraction
        }
        if let startScale {
            config.startScale = startScale
        }
        if let peakScale {
            config.peakScale = peakScale
        }
        if let endScale {
            config.endScale = endScale
        }
        if let peakProgress {
            config.peakProgress = peakProgress
        }
        return config
    }
}

private struct CombatFeedbackFloatMotionLab: View {
    private enum StageTarget: String, CaseIterable, Identifiable {
        case party
        case enemy

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .party: "Party"
            case .enemy: "Enemy"
            }
        }
    }

    private enum ChipKind: String, CaseIterable {
        case physical
        case burn
        case heal
        case critical
        case block

        var feedbackClass: CombatFeedbackClass {
            switch self {
            case .physical, .burn: .directDamage
            case .heal: .heal
            case .critical: .critical
            case .block: .block
            }
        }

        /// Visible amount text. Production amount chips show digits only.
        var text: String? {
            switch self {
            case .physical: "12"
            case .burn: "9"
            case .heal: "8"
            case .critical: "24"
            case .block: "5"
            }
        }

        var tint: Keyword.VisualStyle {
            switch self {
            case .physical, .critical: Keyword.physical.visualStyle
            case .burn: Keyword.burn.visualStyle
            case .heal: Keyword.health.visualStyle
            case .block: Keyword.block.visualStyle
            }
        }

        var fireTitle: String {
            switch self {
            case .physical: "Physical"
            case .burn: "Burn"
            case .heal: "Heal"
            case .critical: "Crit"
            case .block: "Block"
            }
        }
    }

    private struct LabFloat: Identifiable {
        let id: Int
        let target: StageTarget
        let kind: ChipKind
        let availableAt: Date
        let seed: Int
    }

    @State private var selectedCandidate = CombatFeedbackFloatMotionIdealCandidate.core
    @State private var configuration = CombatFeedbackFloatMotionConfiguration.idealCore
    @State private var focusTarget = StageTarget.enemy
    @State private var selectedEnemyID = GameContent.enemies.first?.id ?? ""
    @State private var floats: [LabFloat] = []
    @State private var nextFloatID = 1
    @State private var partyStreamClock = Date.distantPast
    @State private var enemyStreamClock = Date.distantPast
    @State private var copiedBannerVisible = false

    private var selectedEnemy: Enemy? {
        GameContent.enemy(matching: selectedEnemyID)
    }

    private var selectedHero: Combatant? {
        GameContent.heroes.first
    }

    var body: some View {
        HStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .trinketSurface(.base)

            Form {
                playbackSection
                subjectSection
                candidatesSection
                exportSection
            }
            .frame(width: 360)
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if copiedBannerVisible {
                Text("Copied parameter dump")
                    .font(.caption.weight(.semibold))
                    .trinketGlassChip(.compact)
                    .padding(.top, TrinketDesign.Metrics.mediumSpacing)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var stage: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
                VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                    Text("Combat Float Motion Lab")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Pick an ideal candidate, then fire chips to compare")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .center, spacing: TrinketDesign.Metrics.extraLargeSpacing) {
                    targetStage(
                        title: "Party · 1 stream",
                        target: .party,
                        aspectRatio: BattleCardGridLayout.partyAspectRatio,
                        combatant: selectedHero,
                        now: now
                    )

                    targetStage(
                        title: "Enemy · 1 stream",
                        target: .enemy,
                        aspectRatio: BattleCardGridLayout.enemyAspectRatio,
                        combatant: selectedEnemy?.combatant,
                        now: now
                    )
                }
                .frame(maxHeight: .infinity)

                HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
                    ForEach(ChipKind.allCases, id: \.self) { kind in
                        fireButton(kind.fireTitle, kind: kind)
                    }
                    Button("Burst ×7") {
                        fireBurst()
                    }
                    .trinketPrimaryActionButton(controlSize: .large)
                }

                Text(parameterSummary)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(TrinketDesign.Metrics.extraLargeSpacing)
            .onChange(of: now) { _, date in
                pruneExpired(at: date)
            }
        }
    }

    private func targetStage(
        title: String,
        target: StageTarget,
        aspectRatio: CGFloat,
        combatant: Combatant?,
        now: Date
    ) -> some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            Text(title)
                .font(.headline)
                .foregroundStyle(focusTarget == target ? .primary : .secondary)

            GeometryReader { geometry in
                let cardSize = fittedCardSize(in: geometry.size, aspectRatio: aspectRatio)
                ZStack {
                    if let combatant {
                        cardChrome(combatant: combatant)
                            .frame(width: cardSize.width, height: cardSize.height)
                    } else {
                        ContentUnavailableView(
                            target == .party ? "No Hero" : "No Enemy",
                            systemImage: "person.crop.rectangle"
                        )
                        .frame(width: cardSize.width, height: cardSize.height)
                    }

                    let targetFloats = floats
                        .filter { $0.target == target }
                        .sorted {
                            if $0.availableAt == $1.availableAt {
                                return $0.id < $1.id
                            }
                            return $0.availableAt < $1.availableAt
                        }
                    let packedOffsets = packedLabOffsets(
                        for: targetFloats,
                        cardHeight: cardSize.height,
                        at: now
                    )
                    ForEach(targetFloats) { item in
                        labChip(
                            item,
                            cardHeight: cardSize.height,
                            verticalOffset: packedOffsets[item.id] ?? 0,
                            at: now
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: 320)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        focusTarget == target
                            ? TrinketDesign.Colors.accent.opacity(0.55)
                            : Color.clear,
                        lineWidth: 2
                    )
            }
            .onTapGesture {
                focusTarget = target
            }
        }
    }

    private func labChip(
        _ item: LabFloat,
        cardHeight: CGFloat,
        verticalOffset: CGFloat,
        at date: Date
    ) -> some View {
        let recipe = CombatFeedbackChipRecipes.chip(for: item.kind.feedbackClass)
        let chipHeight = chipHeight(for: item.kind)
        let chipWidth = chipWidth(for: item.kind)
        let travel = configuration.travelDistance(cardHeight: cardHeight, chipHeight: chipHeight)
        let pose = configuration.sample(
            elapsed: max(0, date.timeIntervalSince(item.availableAt)),
            seed: item.seed,
            chipWidth: chipWidth,
            travelDistance: travel
        )

        return HStack(spacing: 8) {
            if let text = item.kind.text {
                Text(text)
                    .font(recipe.font)
            }
            Image(systemName: item.kind.tint.symbolName)
                .font(recipe.font)
                .symbolRenderingMode(.monochrome)
        }
        .foregroundStyle(item.kind.tint.color)
        .trinketCombatFloatText()
        .scaleEffect(pose.scale)
        .rotationEffect(.degrees(pose.rotationDegrees))
        .offset(x: pose.offsetX, y: verticalOffset)
        .opacity(pose.opacity)
        .allowsHitTesting(false)
    }

    private func cardChrome(combatant: Combatant) -> some View {
        ZStack(alignment: .bottom) {
            CombatantArtwork(combatant: combatant, variant: .battle)
            CombatHealthBar(
                health: 72,
                maxHealth: 100,
                fillColor: TrinketDesign.Colors.battleHealth,
                style: .battleBorder,
                height: TrinketDesign.Metrics.battleHealthBarHeight
            )
        }
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape.strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
        }
    }

    private func fireButton(_ title: String, kind: ChipKind) -> some View {
        Button(title) {
            fire(kind: kind, on: focusTarget)
        }
        .trinketPrimaryActionButton(controlSize: .large)
    }

    private var playbackSection: some View {
        Section("Playback") {
            Picker("Focus target", selection: $focusTarget) {
                ForEach(StageTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)

            ForEach(ChipKind.allCases, id: \.self) { kind in
                Button("Fire \(kind.fireTitle)") { fire(kind: kind, on: focusTarget) }
            }
            Button("Burst ×7 on focus") { fireBurst() }
            Button("Clear Floats") {
                floats.removeAll()
                resetStreamClocks()
            }
            LabeledContent("Active floats", value: "\(floats.count)")
        }
    }

    private var subjectSection: some View {
        Section("Subject") {
            Picker("Enemy", selection: $selectedEnemyID) {
                ForEach(GameContent.enemies, id: \.id) { enemy in
                    Text(enemy.name).tag(enemy.id)
                }
            }
        }
    }

    private var candidatesSection: some View {
        Section {
            Text("Ease-out rise, soft impact punch, fade after readable — pure vertical. Candidates only nudge one axis.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(CombatFeedbackFloatMotionIdealCandidate.allCases) { candidate in
                Button {
                    load(candidate)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(candidate.title)
                                .fontWeight(selectedCandidate == candidate ? .semibold : .regular)
                            Spacer()
                            if selectedCandidate == candidate {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(TrinketDesign.Colors.accent)
                            }
                        }
                        Text(candidate.blurb)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Ideal Candidates")
        }
    }

    private var exportSection: some View {
        Section("Export") {
            Button("Copy Selected Values") {
                UIPasteboard.general.string = configuration.parameterDump()
                withAnimation {
                    copiedBannerVisible = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(1.4))
                    withAnimation {
                        copiedBannerVisible = false
                    }
                }
            }
            Text(configuration.parameterDump())
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var parameterSummary: String {
        "\(selectedCandidate.title) · \(String(format: "%.2f", configuration.duration))s · travel "
            + "\(String(format: "%.2f", configuration.travelFraction))"
    }

    private func load(_ candidate: CombatFeedbackFloatMotionIdealCandidate) {
        selectedCandidate = candidate
        configuration = candidate.configuration
        floats.removeAll()
        resetStreamClocks()
    }

    private func fireBurst() {
        for kind in [
            ChipKind.physical,
            .burn,
            .critical,
            .heal,
            .block,
            .physical,
            .critical,
        ] {
            fire(kind: kind, on: focusTarget)
        }
    }

    private func fire(kind: ChipKind, on target: StageTarget) {
        let now = Date()
        let start = schedule(target: target, at: now)
        let float = LabFloat(
            id: nextFloatID,
            target: target,
            kind: kind,
            availableAt: start,
            seed: nextFloatID
        )
        nextFloatID += 1
        floats.append(float)
        focusTarget = target
    }

    private func schedule(target: StageTarget, at date: Date) -> Date {
        let clock = target == .party ? partyStreamClock : enemyStreamClock
        let start = max(date, clock)
        let next = start.addingTimeInterval(TrinketMotion.Battle.feedbackStreamStagger)
        if target == .party {
            partyStreamClock = next
        } else {
            enemyStreamClock = next
        }
        return start
    }

    private func packedLabOffsets(
        for items: [LabFloat],
        cardHeight: CGFloat,
        at date: Date
    ) -> [Int: CGFloat] {
        let poses = items.map { item in
            let height = chipHeight(for: item.kind)
            let travel = configuration.travelDistance(cardHeight: cardHeight, chipHeight: height)
            return configuration.sample(
                elapsed: max(0, date.timeIntervalSince(item.availableAt)),
                seed: item.seed,
                chipWidth: chipWidth(for: item.kind),
                travelDistance: travel
            )
        }
        let offsets = CombatFeedbackRasterUIView.packedVerticalOffsets(
            desired: poses.map(\.offsetY),
            scaledHeights: zip(items, poses).map { item, pose in
                chipHeight(for: item.kind) * pose.scale
            }
        )
        return Dictionary(uniqueKeysWithValues: zip(items.map(\.id), offsets))
    }

    private func chipHeight(for kind: ChipKind) -> CGFloat {
        kind == .critical ? 44 : 36
    }

    private func chipWidth(for kind: ChipKind) -> CGFloat {
        kind == .critical ? 88 : 72
    }

    private func pruneExpired(at date: Date) {
        let lifetime = configuration.duration + 0.05
        floats.removeAll { date.timeIntervalSince($0.availableAt) > lifetime }
    }

    private func resetStreamClocks() {
        partyStreamClock = .distantPast
        enemyStreamClock = .distantPast
    }

    private func fittedCardSize(in size: CGSize, aspectRatio: CGFloat) -> CGSize {
        let widthLimited = CGSize(width: size.width, height: size.width / aspectRatio)
        if widthLimited.height <= size.height {
            return widthLimited
        }
        return CGSize(width: size.height * aspectRatio, height: size.height)
    }
}

struct CombatFeedbackFloatMotionLab_Previews: PreviewProvider {
    static var previews: some View {
        CombatFeedbackFloatMotionLab()
            .preferredColorScheme(.dark)
            .previewDevice(PreviewDevice(rawValue: "iPad Pro 13-inch (M5)"))
            .previewInterfaceOrientation(.landscapeLeft)
            .previewDisplayName("Combat Float Motion Lab")
    }
}
#endif
