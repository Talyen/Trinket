import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

#if DEBUG

private struct BattleHitReactionMotionLab: View {
    @State private var selectedEnemyID = GameContent.enemies.first?.id ?? ""
    @State private var direction = HitDirection.up
    @State private var cyclesDirection = false
    @State private var deformation = Deformation.squish
    @State private var impactSpring = SpringPreset.snappy
    @State private var recoverySpring = SpringPreset.bouncy
    @State private var impactDuration = 0.08
    @State private var recoveryDuration = 0.16
    @State private var impactExtraBounce = 0.0
    @State private var recoveryExtraBounce = 0.0
    @State private var customImpactDamping = 0.82
    @State private var customRecoveryDamping = 0.72
    @State private var squash = 0.04
    @State private var stretch = 0.025
    @State private var recoilDistance = 4.0
    @State private var hitTrigger = 0

    private var selectedEnemy: Enemy? {
        GameContent.enemy(matching: selectedEnemyID)
    }

    private var activeDirection: HitDirection {
        let cycleIndex = max(0, hitTrigger - 1) % HitDirection.allCases.count
        return cyclesDirection ? HitDirection.allCases[cycleIndex] : direction
    }

    var body: some View {
        HStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .trinketSurface(.base)

            Form {
                subjectSection
                playbackSection
                springSection(
                    title: "Impact Spring",
                    preset: $impactSpring,
                    duration: $impactDuration,
                    extraBounce: $impactExtraBounce,
                    damping: $customImpactDamping
                )
                springSection(
                    title: "Recovery Spring",
                    preset: $recoverySpring,
                    duration: $recoveryDuration,
                    extraBounce: $recoveryExtraBounce,
                    damping: $customRecoveryDamping
                )
                deformationSection
                presetsSection
            }
            .frame(width: 380)
        }
        .preferredColorScheme(.dark)
    }

    private var stage: some View {
        VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
            VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                Text("Battle Hit Reaction Lab")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Tune native SwiftUI springs on production enemy artwork")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let selectedEnemy {
                HitReactionPreview(
                    combatant: selectedEnemy.combatant,
                    direction: activeDirection,
                    deformation: deformation,
                    impactSpring: impactSpring.spring(
                        duration: impactDuration,
                        extraBounce: impactExtraBounce,
                        damping: customImpactDamping
                    ),
                    recoverySpring: recoverySpring.spring(
                        duration: recoveryDuration,
                        extraBounce: recoveryExtraBounce,
                        damping: customRecoveryDamping
                    ),
                    impactDuration: impactDuration,
                    recoveryDuration: recoveryDuration,
                    squash: squash,
                    stretch: stretch,
                    recoilDistance: recoilDistance,
                    trigger: hitTrigger
                )
                .frame(maxWidth: 480)
                .aspectRatio(BattleCardGridLayout.enemyAspectRatio, contentMode: .fit)
                .overlay {
                    TrinketDesign.cardShape
                        .stroke(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
                }

                Text(selectedEnemy.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
            } else {
                ContentUnavailableView("No Enemy", systemImage: "person.crop.rectangle")
            }

            Button("Hit Portrait") {
                hitTrigger += 1
            }
            .trinketPrimaryActionButton(controlSize: .large)
            .keyboardShortcut(.space, modifiers: [])

            Text(parameterSummary)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(TrinketDesign.Metrics.extraLargeSpacing)
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

    private var playbackSection: some View {
        Section("Playback") {
            Toggle("Cycle left, right, up", isOn: $cyclesDirection)
            Picker("Direction", selection: $direction) {
                ForEach(HitDirection.allCases) { direction in
                    Text(direction.title).tag(direction)
                }
            }
            .disabled(cyclesDirection)
            Button("Hit Portrait") {
                hitTrigger += 1
            }
        }
    }

    private func springSection(
        title: String,
        preset: Binding<SpringPreset>,
        duration: Binding<Double>,
        extraBounce: Binding<Double>,
        damping: Binding<Double>
    ) -> some View {
        Section(title) {
            Picker("Preset", selection: preset) {
                ForEach(SpringPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            parameterSlider("Duration", value: duration, range: 0.04 ... 0.5, format: "%.2f s")

            if preset.wrappedValue == .custom {
                parameterSlider("Damping", value: damping, range: 0.35 ... 1.15, format: "%.2f")
            } else {
                parameterSlider(
                    "Extra bounce",
                    value: extraBounce,
                    range: -0.2 ... 0.35,
                    format: "%.2f"
                )
            }
        }
    }

    private var deformationSection: some View {
        Section("Transform") {
            Picker("Deformation", selection: $deformation) {
                ForEach(Deformation.allCases) { deformation in
                    Text(deformation.title).tag(deformation)
                }
            }
            parameterSlider("Squash", value: $squash, range: 0 ... 0.15, format: "%.3f")
                .disabled(deformation == .none)
            parameterSlider("Stretch", value: $stretch, range: 0 ... 0.12, format: "%.3f")
                .disabled(deformation == .none || deformation == .uniformPulse)
            parameterSlider("Recoil", value: $recoilDistance, range: 0 ... 20, format: "%.1f pt")
        }
    }

    private var presetsSection: some View {
        Section("Production Starting Points") {
            Button("Load Normal Hit") {
                loadNormalHit()
            }
            Button("Load Critical Hit") {
                loadCriticalHit()
            }
        }
    }

    private var parameterSummary: String {
        let directionLabel = cyclesDirection ? "cycling" : activeDirection.title.lowercased()
        return "\(impactSpring.title) → \(recoverySpring.title) · \(directionLabel) · "
            + "\(String(format: "%.2f", impactDuration))s / "
            + "\(String(format: "%.2f", recoveryDuration))s"
    }

    private func parameterSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(title, value: String(format: format, value.wrappedValue))
            Slider(value: value, in: range)
        }
    }

    private func loadNormalHit() {
        direction = .up
        cyclesDirection = false
        deformation = .squish
        impactSpring = .snappy
        recoverySpring = .bouncy
        impactDuration = 0.08
        recoveryDuration = 0.16
        squash = 0.04
        stretch = 0.025
        recoilDistance = 4
        hitTrigger += 1
    }

    private func loadCriticalHit() {
        direction = .up
        cyclesDirection = false
        deformation = .squish
        impactSpring = .snappy
        recoverySpring = .bouncy
        impactDuration = 0.08
        recoveryDuration = 0.18
        squash = 0.07
        stretch = 0.04
        recoilDistance = 7
        hitTrigger += 1
    }
}

private struct HitReactionPreview: View {
    let combatant: Combatant
    let direction: HitDirection
    let deformation: Deformation
    let impactSpring: Spring
    let recoverySpring: Spring
    let impactDuration: TimeInterval
    let recoveryDuration: TimeInterval
    let squash: Double
    let stretch: Double
    let recoilDistance: Double
    let trigger: Int

    var body: some View {
        let impactScale = deformation.scale(direction: direction, squash: squash, stretch: stretch)
        let impactOffset = direction.offset(distance: recoilDistance)

        KeyframeAnimator(initialValue: HitReactionState(), trigger: trigger) { state in
            CombatantArtwork(combatant: combatant, variant: .battle)
                .clipShape(TrinketDesign.cardShape)
                .scaleEffect(x: state.scaleX, y: state.scaleY)
                .offset(x: state.offsetX, y: state.offsetY)
        } keyframes: { _ in
            KeyframeTrack(\.scaleX) {
                SpringKeyframe(impactScale.x, duration: impactDuration, spring: impactSpring)
                SpringKeyframe(1, duration: recoveryDuration, spring: recoverySpring)
            }
            KeyframeTrack(\.scaleY) {
                SpringKeyframe(impactScale.y, duration: impactDuration, spring: impactSpring)
                SpringKeyframe(1, duration: recoveryDuration, spring: recoverySpring)
            }
            KeyframeTrack(\.offsetX) {
                SpringKeyframe(impactOffset.width, duration: impactDuration, spring: impactSpring)
                SpringKeyframe(0, duration: recoveryDuration, spring: recoverySpring)
            }
            KeyframeTrack(\.offsetY) {
                SpringKeyframe(impactOffset.height, duration: impactDuration, spring: impactSpring)
                SpringKeyframe(0, duration: recoveryDuration, spring: recoverySpring)
            }
        }
    }
}

private struct HitReactionState {
    var scaleX = 1.0
    var scaleY = 1.0
    var offsetX = 0.0
    var offsetY = 0.0
}

private enum HitDirection: String, CaseIterable, Identifiable {
    case left
    case right
    case up

    var id: Self {
        self
    }

    var title: String {
        rawValue.capitalized
    }

    func offset(distance: Double) -> CGSize {
        switch self {
        case .left:
            CGSize(width: -distance, height: 0)
        case .right:
            CGSize(width: distance, height: 0)
        case .up:
            CGSize(width: 0, height: -distance)
        }
    }
}

private enum Deformation: String, CaseIterable, Identifiable {
    case none
    case squish
    case stretch
    case uniformPulse

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .none: "None"
        case .squish: "Squish"
        case .stretch: "Stretch"
        case .uniformPulse: "Uniform Pulse"
        }
    }

    func scale(direction: HitDirection, squash: Double, stretch: Double) -> (x: Double, y: Double) {
        switch self {
        case .none:
            (1, 1)
        case .squish:
            direction == .up ? (1 + stretch, 1 - squash) : (1 - squash, 1 + stretch)
        case .stretch:
            direction == .up ? (1 - squash, 1 + stretch) : (1 + stretch, 1 - squash)
        case .uniformPulse:
            (1 + squash, 1 + squash)
        }
    }
}

private enum SpringPreset: String, CaseIterable, Identifiable {
    case smooth
    case snappy
    case bouncy
    case custom

    var id: Self {
        self
    }

    var title: String {
        rawValue.capitalized
    }

    func spring(duration: TimeInterval, extraBounce: Double, damping: Double) -> Spring {
        switch self {
        case .smooth:
            .smooth(duration: duration, extraBounce: extraBounce)
        case .snappy:
            .snappy(duration: duration, extraBounce: extraBounce)
        case .bouncy:
            .bouncy(duration: duration, extraBounce: extraBounce)
        case .custom:
            Spring(response: duration, dampingRatio: damping)
        }
    }
}

struct BattleHitReactionMotionLab_Previews: PreviewProvider {
    static var previews: some View {
        BattleHitReactionMotionLab()
            .preferredColorScheme(.dark)
            .previewDevice(PreviewDevice(rawValue: "iPad Pro 13-inch (M4)"))
            .previewInterfaceOrientation(.landscapeLeft)
            .previewDisplayName("Battle Hit Reaction Motion Lab")
    }
}
#endif
