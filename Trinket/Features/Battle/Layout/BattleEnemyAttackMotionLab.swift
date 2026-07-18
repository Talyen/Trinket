#if DEBUG
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

private struct BattleEnemyAttackMotionLab: View {
    @State private var selectedEnemyID = GameContent.enemies.first?.id ?? ""
    @State private var windUpDuration = 0.40
    @State private var swingDuration = 0.15
    @State private var recoverDuration = 0.45
    @State private var windUpOffsetY = -12.0
    @State private var swingOffsetY = 28.0
    @State private var windUpScaleX = 0.96
    @State private var windUpScaleY = 1.04
    @State private var swingScaleX = 1.05
    @State private var swingScaleY = 0.94
    @State private var windUpRotation = -4.0
    @State private var swingRotation = 3.0
    @State private var attackTrigger = 0

    private var selectedEnemy: Enemy? {
        GameContent.enemy(matching: selectedEnemyID)
    }

    private var impactDelay: TimeInterval {
        windUpDuration + swingDuration
    }

    private var totalDuration: TimeInterval {
        windUpDuration + swingDuration + recoverDuration
    }

    var body: some View {
        HStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .trinketSurface(.base)

            Form {
                subjectSection
                playbackSection
                timingSection
                transformSection
                presetsSection
            }
            .frame(width: 380)
        }
        .preferredColorScheme(.dark)
    }

    private var stage: some View {
        VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
            VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                Text("Enemy Attack Motion Lab")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Whole-card telegraph (art + HP + border) toward the party")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let selectedEnemy {
                AttackPreview(
                    combatant: selectedEnemy.combatant,
                    windUpDuration: windUpDuration,
                    swingDuration: swingDuration,
                    recoverDuration: recoverDuration,
                    windUpOffsetY: windUpOffsetY,
                    swingOffsetY: swingOffsetY,
                    windUpScaleX: windUpScaleX,
                    windUpScaleY: windUpScaleY,
                    swingScaleX: swingScaleX,
                    swingScaleY: swingScaleY,
                    windUpRotation: windUpRotation,
                    swingRotation: swingRotation,
                    trigger: attackTrigger
                )
                .frame(maxWidth: 480)
                .aspectRatio(BattleCardGridLayout.enemyAspectRatio, contentMode: .fit)

                Text(selectedEnemy.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
            } else {
                ContentUnavailableView("No Enemy", systemImage: "person.crop.rectangle")
            }

            Button("Attack") {
                attackTrigger += 1
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
            Button("Attack") {
                attackTrigger += 1
            }
            LabeledContent("Impact delay", value: String(format: "%.2f s", impactDelay))
            LabeledContent("Total duration", value: String(format: "%.2f s", totalDuration))
        }
    }

    private var timingSection: some View {
        Section("Timing") {
            parameterSlider("Wind-up", value: $windUpDuration, range: 0.08 ... 0.7, format: "%.2f s")
            parameterSlider("Swing", value: $swingDuration, range: 0.06 ... 0.4, format: "%.2f s")
            parameterSlider("Recover", value: $recoverDuration, range: 0.1 ... 0.8, format: "%.2f s")
        }
    }

    private var transformSection: some View {
        Section("Transform") {
            parameterSlider("Wind-up Y", value: $windUpOffsetY, range: -40 ... 0, format: "%.0f pt")
            parameterSlider("Swing Y", value: $swingOffsetY, range: 0 ... 60, format: "%.0f pt")
            parameterSlider("Wind-up scale X", value: $windUpScaleX, range: 0.85 ... 1.1, format: "%.2f")
            parameterSlider("Wind-up scale Y", value: $windUpScaleY, range: 0.9 ... 1.15, format: "%.2f")
            parameterSlider("Swing scale X", value: $swingScaleX, range: 0.9 ... 1.15, format: "%.2f")
            parameterSlider("Swing scale Y", value: $swingScaleY, range: 0.85 ... 1.1, format: "%.2f")
            parameterSlider("Wind-up rotation", value: $windUpRotation, range: -20 ... 20, format: "%.0f°")
            parameterSlider("Swing rotation", value: $swingRotation, range: -20 ... 20, format: "%.0f°")
        }
    }

    private var presetsSection: some View {
        Section("Presets") {
            Button("1. Lunge (production)") { loadLunge() }
            Button("2. Chop") { loadChop() }
            Button("3. Pounce") { loadPounce() }
            Button("4. Jab") { loadJab() }
            Button("5. Menace") { loadMenace() }
            Button("6. Coil") { loadCoil() }
        }
    }

    private var parameterSummary: String {
        "impact \(String(format: "%.2f", impactDelay))s · total "
            + "\(String(format: "%.2f", totalDuration))s · swing \(Int(swingOffsetY))pt"
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

    private func loadLunge() {
        windUpDuration = 0.40
        swingDuration = 0.15
        recoverDuration = 0.45
        windUpOffsetY = -12
        swingOffsetY = 28
        windUpScaleX = 0.96
        windUpScaleY = 1.04
        swingScaleX = 1.05
        swingScaleY = 0.94
        windUpRotation = -4
        swingRotation = 3
        attackTrigger += 1
    }

    private func loadChop() {
        windUpDuration = 0.35
        swingDuration = 0.18
        recoverDuration = 0.42
        windUpOffsetY = -6
        swingOffsetY = 22
        windUpScaleX = 0.98
        windUpScaleY = 1.02
        swingScaleX = 1.02
        swingScaleY = 0.97
        windUpRotation = -14
        swingRotation = 10
        attackTrigger += 1
    }

    private func loadPounce() {
        windUpDuration = 0.42
        swingDuration = 0.14
        recoverDuration = 0.48
        windUpOffsetY = -8
        swingOffsetY = 36
        windUpScaleX = 1.06
        windUpScaleY = 0.88
        swingScaleX = 0.94
        swingScaleY = 1.08
        windUpRotation = 0
        swingRotation = 2
        attackTrigger += 1
    }

    private func loadJab() {
        windUpDuration = 0.18
        swingDuration = 0.10
        recoverDuration = 0.32
        windUpOffsetY = -4
        swingOffsetY = 18
        windUpScaleX = 0.98
        windUpScaleY = 1.02
        swingScaleX = 1.03
        swingScaleY = 0.96
        windUpRotation = -2
        swingRotation = 4
        attackTrigger += 1
    }

    private func loadMenace() {
        windUpDuration = 0.55
        swingDuration = 0.16
        recoverDuration = 0.40
        windUpOffsetY = -10
        swingOffsetY = 16
        windUpScaleX = 0.99
        windUpScaleY = 1.01
        swingScaleX = 1.02
        swingScaleY = 0.98
        windUpRotation = -8
        swingRotation = 5
        attackTrigger += 1
    }

    private func loadCoil() {
        windUpDuration = 0.48
        swingDuration = 0.12
        recoverDuration = 0.55
        windUpOffsetY = -20
        swingOffsetY = 40
        windUpScaleX = 0.92
        windUpScaleY = 1.08
        swingScaleX = 1.08
        swingScaleY = 0.90
        windUpRotation = -6
        swingRotation = 5
        attackTrigger += 1
    }
}

private struct AttackPreview: View {
    let combatant: Combatant
    let windUpDuration: TimeInterval
    let swingDuration: TimeInterval
    let recoverDuration: TimeInterval
    let windUpOffsetY: Double
    let swingOffsetY: Double
    let windUpScaleX: Double
    let windUpScaleY: Double
    let swingScaleX: Double
    let swingScaleY: Double
    let windUpRotation: Double
    let swingRotation: Double
    let trigger: Int

    var body: some View {
        KeyframeAnimator(initialValue: AttackPreviewState(), trigger: trigger) { state in
            cardChrome
                .scaleEffect(x: state.scaleX, y: state.scaleY)
                .rotationEffect(.degrees(state.rotation))
                .offset(x: state.offsetX, y: state.offsetY)
        } keyframes: { _ in
            KeyframeTrack(\.scaleX) {
                SpringKeyframe(windUpScaleX, duration: windUpDuration, spring: .smooth(duration: windUpDuration))
                SpringKeyframe(swingScaleX, duration: swingDuration, spring: .snappy(duration: swingDuration))
                SpringKeyframe(1, duration: recoverDuration, spring: .bouncy(duration: recoverDuration))
            }
            KeyframeTrack(\.scaleY) {
                SpringKeyframe(windUpScaleY, duration: windUpDuration, spring: .smooth(duration: windUpDuration))
                SpringKeyframe(swingScaleY, duration: swingDuration, spring: .snappy(duration: swingDuration))
                SpringKeyframe(1, duration: recoverDuration, spring: .bouncy(duration: recoverDuration))
            }
            KeyframeTrack(\.offsetX) {
                SpringKeyframe(0, duration: windUpDuration, spring: .smooth(duration: windUpDuration))
                SpringKeyframe(0, duration: swingDuration, spring: .snappy(duration: swingDuration))
                SpringKeyframe(0, duration: recoverDuration, spring: .bouncy(duration: recoverDuration))
            }
            KeyframeTrack(\.offsetY) {
                SpringKeyframe(windUpOffsetY, duration: windUpDuration, spring: .smooth(duration: windUpDuration))
                SpringKeyframe(swingOffsetY, duration: swingDuration, spring: .snappy(duration: swingDuration))
                SpringKeyframe(0, duration: recoverDuration, spring: .bouncy(duration: recoverDuration))
            }
            KeyframeTrack(\.rotation) {
                CubicKeyframe(windUpRotation, duration: windUpDuration)
                CubicKeyframe(swingRotation, duration: swingDuration)
                CubicKeyframe(0, duration: recoverDuration)
            }
        }
    }

    private var cardChrome: some View {
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
}

private struct AttackPreviewState {
    var scaleX = 1.0
    var scaleY = 1.0
    var offsetX = 0.0
    var offsetY = 0.0
    var rotation = 0.0
}

struct BattleEnemyAttackMotionLab_Previews: PreviewProvider {
    static var previews: some View {
        BattleEnemyAttackMotionLab()
            .preferredColorScheme(.dark)
            .previewDevice(PreviewDevice(rawValue: "iPad Pro 13-inch (M4)"))
            .previewInterfaceOrientation(.landscapeLeft)
            .previewDisplayName("Battle Enemy Attack Motion Lab")
    }
}
#endif
