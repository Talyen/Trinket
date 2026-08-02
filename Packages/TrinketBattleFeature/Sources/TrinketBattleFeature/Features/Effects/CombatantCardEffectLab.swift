import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

#if DEBUG
// DEBUG playground only — production motion lives in recipe/config types. Do not ship lab UI.

enum LabCombatantSlot: String, CaseIterable, Identifiable {
    case enemy
    case hero
    case companion

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .enemy: "Enemy"
        case .hero: "Hero"
        case .companion: "Companion"
        }
    }
}

private struct CombatantCardEffectLab: View {
    @State private var selectedEnemyID = GameContent.enemies.first?.id ?? ""
    @State private var selectedHeroID = GameContent.heroes.first?.id ?? ""
    @State private var selectedCompanionID = GameContent.companions.first?.id ?? ""
    @State private var focusSlot = LabCombatantSlot.enemy

    @State private var category = CombatantCardEffectCategory.stunned
    @State private var statusKind = CombatantStatusEffectKind.swirlingStars
    @State private var deathKind = CombatantDeathEffectKind.slice
    @State private var statusConfig = CombatantStatusEffectConfig.defaults(for: .swirlingStars)
    @State private var deathConfig = CombatantDeathEffectConfig.defaults(for: .slice)

    @State private var playsAutomatically = true
    @State private var duration: CGFloat = 1.6
    @State private var scrubProgress: CGFloat = 0
    @State private var playbackStart = Date()

    private var selectedEnemy: Enemy? {
        GameContent.enemy(matching: selectedEnemyID)
    }

    private var selectedHero: Combatant? {
        GameContent.heroes.first { $0.id == selectedHeroID }
    }

    private var selectedCompanion: Combatant? {
        GameContent.companions.first { $0.id == selectedCompanionID }
    }

    private var isDeathCategory: Bool {
        category == .death
    }

    /// Effects only run while auto-playing or scrubbing above rest.
    private var showsEffect: Bool {
        playsAutomatically || scrubProgress > 0
    }

    var body: some View {
        HStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .trinketSurface(.base)

            CombatantCardEffectLabControls(
                selectedEnemyID: $selectedEnemyID,
                selectedHeroID: $selectedHeroID,
                selectedCompanionID: $selectedCompanionID,
                focusSlot: $focusSlot,
                category: $category,
                statusKind: $statusKind,
                deathKind: $deathKind,
                statusConfig: $statusConfig,
                deathConfig: $deathConfig,
                playsAutomatically: $playsAutomatically,
                duration: $duration,
                scrubProgress: $scrubProgress,
                playbackStart: $playbackStart
            )
            .frame(width: 380)
        }
        .preferredColorScheme(.dark)
        .onChange(of: category) { _, newCategory in
            switch newCategory {
            case .stunned:
                statusKind = .swirlingStars
                statusConfig = .defaults(for: .swirlingStars)
                duration = CombatantCardEffectLabDuration.defaults(category: .stunned)
            case .frozen:
                statusKind = .iceCrystals
                statusConfig = .defaults(for: .iceCrystals)
                duration = CombatantCardEffectLabDuration.defaults(category: .frozen)
            case .death:
                deathKind = .slice
                deathConfig = .defaults(for: .slice)
                duration = CombatantCardEffectLabDuration.defaults(
                    category: .death,
                    deathKind: .slice
                )
            }
            replay()
        }
        .onChange(of: statusKind) { _, kind in
            statusConfig = .defaults(for: kind)
            duration = CombatantCardEffectLabDuration.defaults(category: category)
            replay()
        }
        .onChange(of: deathKind) { _, kind in
            deathConfig = .defaults(for: kind)
            duration = CombatantCardEffectLabDuration.defaults(
                category: category,
                deathKind: kind
            )
            replay()
        }
        .task(id: artworkWarmupKey) {
            await warmupArtwork()
        }
    }

    private var artworkWarmupKey: String {
        [selectedEnemyID, selectedHeroID, selectedCompanionID].joined(separator: "|")
    }

    private var stage: some View {
        VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
            VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                Text("Combatant Card Effect Lab")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(stageSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TimelineView(.animation(paused: !playsAutomatically)) { timeline in
                let progress = progress(at: timeline.date)
                battlefield(progress: progress)
            }
            .frame(maxWidth: 560, maxHeight: .infinity)

            Button("Replay") {
                replay()
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

    private var stageSubtitle: String {
        "Tap a combatant to focus · \(category.title) on \(focusSlot.title)"
    }

    private func battlefield(progress: CGFloat) -> some View {
        GeometryReader { geometry in
            // Reserve no hand band in the lab so the triptych fills the stage.
            let layout = BattleCardGridLayout.metrics(
                in: geometry.size,
                handReservedHeight: 0
            )
            VStack(spacing: layout.cardSpacing) {
                combatantPane(
                    slot: .enemy,
                    combatant: selectedEnemy?.combatant,
                    size: layout.enemySize,
                    progress: progress
                )
                HStack(spacing: layout.cardSpacing) {
                    combatantPane(
                        slot: .hero,
                        combatant: selectedHero,
                        size: layout.partySize,
                        progress: progress
                    )
                    combatantPane(
                        slot: .companion,
                        combatant: selectedCompanion,
                        size: layout.partySize,
                        progress: progress
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func combatantPane(
        slot: LabCombatantSlot,
        combatant: Combatant?,
        size: CGSize,
        progress: CGFloat
    ) -> some View {
        let isFocused = focusSlot == slot
        Button {
            focusSlot = slot
            replay()
        } label: {
            Group {
                if let combatant {
                    if isFocused, showsEffect {
                        effectedPortrait(
                            combatant: combatant,
                            size: size,
                            progress: progress
                        )
                    } else {
                        LabCombatantPortrait(combatant: combatant, size: size)
                    }
                } else {
                    missingCombatantPlaceholder(slot: slot, size: size)
                }
            }
            .overlay {
                TrinketDesign.cardShape
                    .strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func effectedPortrait(
        combatant: Combatant,
        size: CGSize,
        progress: CGFloat
    ) -> some View {
        if isDeathCategory {
            CombatantDeathEffect(
                kind: deathKind,
                config: deathConfig,
                progress: progress
            ) {
                LabCombatantPortrait(combatant: combatant, size: size)
            }
            .frame(width: size.width, height: size.height)
        } else {
            LabCombatantPortrait(combatant: combatant, size: size)
                .modifier(
                    CombatantStatusCardTransform(
                        kind: statusKind,
                        config: statusConfig,
                        progress: progress
                    )
                )
                .overlay {
                    CombatantStatusEffectOverlay(
                        kind: statusKind,
                        config: statusConfig,
                        progress: progress
                    )
                }
        }
    }

    private func missingCombatantPlaceholder(slot: LabCombatantSlot, size: CGSize) -> some View {
        ContentUnavailableView(
            "No \(slot.title)",
            systemImage: "person.crop.rectangle"
        )
        .frame(width: size.width, height: size.height)
        .background(TrinketDesign.Colors.subtleStroke.opacity(0.2))
        .clipShape(TrinketDesign.cardShape)
    }

    private var parameterSummary: String {
        let variantTitle = isDeathCategory ? deathKind.title : statusKind.title
        let intensity = isDeathCategory ? deathConfig.intensity : statusConfig.intensity
        return "\(focusSlot.title) · \(category.title) · \(variantTitle) · "
            + "intensity \(String(format: "%.2f", intensity))"
    }

    private func progress(at date: Date) -> CGFloat {
        if !playsAutomatically {
            return scrubProgress
        }
        let elapsed = max(0, date.timeIntervalSince(playbackStart))
        let cycle = TimeInterval(duration)
        guard cycle > 0 else { return 0 }
        let unit = elapsed / cycle
        // Frozen plays once then holds fully frosted — looping would thaw and re-freeze.
        if category == .frozen {
            return CGFloat(min(unit, 1))
        }
        // Stunned uses absolute time so fade-in / wobble happen once; orbit keeps moving.
        if category == .stunned {
            return CGFloat(unit)
        }
        return CGFloat(unit.truncatingRemainder(dividingBy: 1))
    }

    private func replay() {
        scrubProgress = 0
        playbackStart = Date()
        playsAutomatically = true
    }

    private func warmupArtwork() async {
        var names: [String] = []
        if let name = selectedEnemy?.combatant.artReference?.imageName {
            names.append(name)
        }
        if let name = selectedHero?.artReference?.imageName {
            names.append(name)
        }
        if let name = selectedCompanion?.artReference?.imageName {
            names.append(name)
        }
        await PreparedArtworkCache.shared.prepareAndPin(names: names)
    }
}

struct CombatantCardEffectLab_Previews: PreviewProvider {
    static var previews: some View {
        CombatantCardEffectLab()
            .preferredColorScheme(.dark)
            .previewDevice(PreviewDevice(rawValue: "iPad Pro 13-inch (M4)"))
            .previewInterfaceOrientation(.landscapeLeft)
            .previewDisplayName("Combatant Card Effect Lab")
    }
}
#endif
