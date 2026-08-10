import SwiftUI
import TrinketContent
import TrinketDesignSystem

#if DEBUG
// DEBUG playground only — production motion lives in recipe/config types. Do not ship lab UI.

struct CombatantCardEffectLabControls: View {
    @Binding var selectedEnemyID: String
    @Binding var selectedHeroID: String
    @Binding var selectedCompanionID: String
    @Binding var focusSlot: LabCombatantSlot
    @Binding var category: CombatantCardEffectCategory
    @Binding var statusKind: CombatantStatusEffectKind
    @Binding var deathKind: CombatantDeathEffectKind
    @Binding var statusConfig: CombatantStatusEffectConfig
    @Binding var deathConfig: CombatantDeathEffectConfig
    @Binding var playsAutomatically: Bool
    @Binding var duration: CGFloat
    @Binding var scrubProgress: CGFloat
    @Binding var playbackStart: Date

    private var isDeathCategory: Bool {
        category == .death
    }

    private var isShadowstepCategory: Bool {
        category == .shadowstep
    }

    private var isStatusCategory: Bool {
        category == .stunned || category == .frozen
    }

    var body: some View {
        Form {
            subjectSection
            categorySection
            playbackSection
            if !isShadowstepCategory {
                sharedParametersSection
                variantParametersSection
            }
            if isStatusCategory || isDeathCategory {
                presetsSection
            }
        }
    }

    private var subjectSection: some View {
        Section("Battlefield") {
            Picker("Focus", selection: $focusSlot) {
                ForEach(LabCombatantSlot.allCases) { slot in
                    Text(slot.title).tag(slot)
                }
            }
            .pickerStyle(.segmented)

            Picker("Enemy", selection: $selectedEnemyID) {
                ForEach(GameContent.enemies, id: \.id) { enemy in
                    Text(enemy.name).tag(enemy.id)
                }
            }
            Picker("Hero", selection: $selectedHeroID) {
                ForEach(GameContent.heroes, id: \.id) { hero in
                    Text(hero.name).tag(hero.id)
                }
            }
            Picker("Companion", selection: $selectedCompanionID) {
                ForEach(GameContent.companions, id: \.id) { companion in
                    Text(companion.name).tag(companion.id)
                }
            }
        }
    }

    private var categorySection: some View {
        Section("Effect") {
            Picker("Category", selection: $category) {
                ForEach(CombatantCardEffectCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.segmented)

            if isDeathCategory {
                Picker("Variant", selection: $deathKind) {
                    ForEach(CombatantDeathEffectKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
            } else if isStatusCategory {
                Picker("Variant", selection: $statusKind) {
                    ForEach(CombatantStatusEffectKind.kinds(for: category)) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
            } else if isShadowstepCategory {
                Text("Shimmer Border")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var playbackSection: some View {
        Section("Playback") {
            Toggle("Auto-play", isOn: $playsAutomatically)
                .onChange(of: playsAutomatically) { _, isPlaying in
                    if isPlaying {
                        playbackStart = Date()
                    } else {
                        scrubProgress = 0
                    }
                }
            parameterSlider("Duration", value: $duration, range: 0.5 ... 6, format: "%.2f s")
            parameterSlider("Progress", value: $scrubProgress, range: 0 ... 1, format: "%.2f")
                .disabled(playsAutomatically)
            Button("Replay") {
                replay()
            }
        }
    }

    private var sharedParametersSection: some View {
        Section("Shared") {
            if isDeathCategory {
                parameterSlider(
                    "Intensity",
                    value: $deathConfig.intensity,
                    range: 0.2 ... 2,
                    format: "%.2f"
                )
                Stepper(
                    "Particles: \(deathConfig.particleCount)",
                    value: $deathConfig.particleCount,
                    in: 0 ... 80,
                    step: 2
                )
                parameterSlider(
                    "Tint strength",
                    value: $deathConfig.tintStrength,
                    range: 0 ... 1,
                    format: "%.2f"
                )
                parameterSlider(
                    "Speed",
                    value: $deathConfig.speed,
                    range: 0.25 ... 2.5,
                    format: "%.2f"
                )
            } else {
                parameterSlider(
                    "Intensity",
                    value: $statusConfig.intensity,
                    range: 0.2 ... 2,
                    format: "%.2f"
                )
                Stepper(
                    "Particles: \(statusConfig.particleCount)",
                    value: $statusConfig.particleCount,
                    in: 0 ... 80,
                    step: 2
                )
                parameterSlider(
                    "Tint strength",
                    value: $statusConfig.tintStrength,
                    range: 0 ... 1,
                    format: "%.2f"
                )
                parameterSlider(
                    "Speed",
                    value: $statusConfig.speed,
                    range: 0.25 ... 2.5,
                    format: "%.2f"
                )
            }
        }
    }

    @ViewBuilder
    private var variantParametersSection: some View {
        if isDeathCategory {
            deathParametersSection
        } else {
            statusParametersSection
        }
    }

    private var deathParametersSection: some View {
        Section("Death Parameters") {
            switch deathKind {
            case .slice:
                parameterSlider(
                    "Slice gap",
                    value: $deathConfig.splitGap,
                    range: 0.05 ... 0.6,
                    format: "%.2f"
                )
                parameterSlider(
                    "Slice delay",
                    value: $deathConfig.splitDelay,
                    range: 0 ... 0.5,
                    format: "%.2f"
                )
            case .dissolveBaseline:
                Toggle("Celebrate dissolve", isOn: $deathConfig.celebrateDissolve)
            }
        }
    }

    private var statusParametersSection: some View {
        Section("Status Parameters") {
            switch statusKind {
            case .swirlingStars:
                Stepper(
                    "Stars: \(statusConfig.starCount)",
                    value: $statusConfig.starCount,
                    in: 3 ... 16
                )
                parameterSlider(
                    "Orbit radius",
                    value: $statusConfig.orbitRadius,
                    range: 0.2 ... 0.7,
                    format: "%.2f"
                )
                parameterSlider(
                    "Wobble",
                    value: $statusConfig.wobbleDegrees,
                    range: 0 ... 8,
                    format: "%.1f°"
                )
            case .iceCrystals:
                parameterSlider(
                    "Frost density",
                    value: $statusConfig.crackDensity,
                    range: 0.1 ... 1,
                    format: "%.2f"
                )
                parameterSlider(
                    "Frost opacity",
                    value: $statusConfig.frostOpacity,
                    range: 0.1 ... 1,
                    format: "%.2f"
                )
            }
        }
    }

    private var presetsSection: some View {
        Section("Presets") {
            Button("Reset Defaults") {
                if isDeathCategory {
                    deathConfig = .defaults(for: deathKind)
                } else {
                    statusConfig = .defaults(for: statusKind)
                }
                duration = CombatantCardEffectLabDuration.defaults(
                    category: category,
                    deathKind: deathKind
                )
                replay()
            }
            if !isDeathCategory {
                Button("Load Intense") {
                    statusConfig.intensity = 1.6
                    statusConfig.tintStrength = min(statusConfig.tintStrength + 0.2, 1)
                    statusConfig.speed = 1.35
                    replay()
                }
            } else {
                Button("Load Dramatic") {
                    deathConfig.intensity = min(deathConfig.intensity + 0.35, 2)
                    deathConfig.particleCount = min(deathConfig.particleCount + 10, 80)
                    deathConfig.splitGap = min(deathConfig.splitGap + 0.1, 1)
                    replay()
                }
            }
        }
    }

    private func replay() {
        scrubProgress = 0
        playbackStart = Date()
        playsAutomatically = true
    }

    private func parameterSlider(
        _ title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        format: String
    ) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(title, value: String(format: format, value.wrappedValue))
            Slider(value: value, in: range)
        }
    }
}

#endif
