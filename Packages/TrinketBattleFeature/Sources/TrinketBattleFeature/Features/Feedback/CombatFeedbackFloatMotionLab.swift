import CoreGraphics
import Foundation
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

#if DEBUG
// DEBUG playground only — production motion lives in `TrinketMotion.Battle`. Do not ship lab UI.

/// DEBUG tuning bed for floating combat-text chips. It samples the same
/// `TrinketMotion.Battle` recipes production renders, comparing the two shipped
/// float recipes against a card stage.
struct CombatFeedbackFloatMotionLab: View {
    private struct RecipeOption: Identifiable {
        let recipe: CombatFeedbackFloatRecipe

        var id: CombatFeedbackFloatRecipe {
            recipe
        }

        var title: String {
            switch recipe {
            case .idealCore: "Ideal Core"
            case .alchemyPop: "Alchemy Pop (production)"
            }
        }

        var subtitle: String {
            switch recipe {
            case .idealCore: "Retained ease-out rise, kept for comparison."
            case .alchemyPop: "Pop overshoot, hold, cubic ease-in rise."
            }
        }
    }

    private enum Kind: String, CaseIterable {
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

    private enum Target: String, CaseIterable, Identifiable {
        case party
        case enemy

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .party: "Party"
            case .enemy: "Enemy"
            }
        }
    }

    private struct LabFloat: Identifiable {
        let id: Int
        let target: Target
        let kind: Kind
        let availableAt: Date
    }

    private struct FloatPose {
        var opacity: Double
        var scale: CGFloat
        var progress: Double
    }

    @State private var recipe = CombatFeedbackFloatRecipe.alchemyPop
    @State private var focusTarget = Target.enemy
    @State private var selectedEnemyID = GameContent.enemies.first?.id ?? ""
    @State private var floats: [LabFloat] = []
    @State private var nextFloatID = 1
    @State private var partyStreamClock = Date.distantPast
    @State private var enemyStreamClock = Date.distantPast

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
                recipeSection
            }
            .frame(width: 360)
        }
        .preferredColorScheme(.dark)
    }

    private var stage: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
                BattleLab.Title(
                    title: "Combat Float Motion Lab",
                    subtitle: "Pick a recipe, then fire chips to compare"
                )

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
                    ForEach(Kind.allCases, id: \.self) { kind in
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
        target: Target,
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
                        BattleLab.combatantCard(combatant)
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
        let style = CombatFeedbackChipRecipes.chip(for: item.kind.feedbackClass)
        let pose = pose(for: item, cardHeight: cardHeight, at: date)

        return HStack(spacing: 8) {
            if let text = item.kind.text {
                Text(text)
                    .font(style.font)
            }
            Image(systemName: item.kind.tint.symbolName)
                .font(style.font)
                .symbolRenderingMode(.monochrome)
        }
        .foregroundStyle(item.kind.tint.color)
        .trinketCombatFloatText()
        .scaleEffect(pose.scale)
        .offset(x: 0, y: verticalOffset)
        .opacity(pose.opacity)
        .allowsHitTesting(false)
    }

    private func fireButton(_ title: String, kind: Kind) -> some View {
        Button(title) {
            fire(kind: kind, on: focusTarget)
        }
        .trinketPrimaryActionButton(controlSize: .large)
    }

    private var playbackSection: some View {
        Section("Playback") {
            Picker("Focus target", selection: $focusTarget) {
                ForEach(Target.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)

            ForEach(Kind.allCases, id: \.self) { kind in
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
            BattleLab.enemyPicker($selectedEnemyID)
        }
    }

    private var recipeSection: some View {
        Section {
            Text("Both recipes render through production \(TrinketMotion.Battle.chipDisplayDuration)-s lifetime.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Self.recipeOptions) { option in
                Button {
                    recipe = option.recipe
                    floats.removeAll()
                    resetStreamClocks()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(option.title)
                                .fontWeight(recipe == option.recipe ? .semibold : .regular)
                            Spacer()
                            if recipe == option.recipe {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(TrinketDesign.Colors.accent)
                            }
                        }
                        Text(option.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Float Recipes")
        }
    }

    private static var recipeOptions: [RecipeOption] {
        CombatFeedbackFloatRecipe.allCases.map(RecipeOption.init(recipe:))
    }

    private var parameterSummary: String {
        let option = Self.recipeOptions.first { $0.recipe == recipe }
        let duration = TrinketMotion.Battle.displayDuration(for: recipe)
        return "\(option?.title ?? "") · \(String(format: "%.2f", duration))s lifetime"
    }

    private func fireBurst() {
        for kind in [
            Kind.physical,
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

    private func fire(kind: Kind, on target: Target) {
        let now = Date()
        let start = schedule(target: target, at: now)
        let float = LabFloat(
            id: nextFloatID,
            target: target,
            kind: kind,
            availableAt: start
        )
        nextFloatID += 1
        floats.append(float)
        focusTarget = target
    }

    private func schedule(target: Target, at date: Date) -> Date {
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
        let poses = items.map { pose(for: $0, cardHeight: cardHeight, at: date) }
        let offsets = CombatFeedbackRasterUIView.packedVerticalOffsets(
            desired: zip(items, poses).map { item, pose in
                -pose.progress * TrinketMotion.Battle.chipTravelDistance(
                    cardHeight: cardHeight,
                    chipHeight: chipHeight(for: item.kind)
                )
            },
            scaledHeights: zip(items, poses).map { item, pose in
                chipHeight(for: item.kind) * pose.scale
            }
        )
        return Dictionary(uniqueKeysWithValues: zip(items.map(\.id), offsets))
    }

    private func pose(for item: LabFloat, cardHeight _: CGFloat, at date: Date) -> FloatPose {
        let elapsed = max(0, date.timeIntervalSince(item.availableAt))
        return FloatPose(
            opacity: TrinketMotion.Battle.chipOpacity(elapsed: elapsed, recipe: recipe),
            scale: TrinketMotion.Battle.chipScale(elapsed: elapsed, recipe: recipe),
            progress: TrinketMotion.Battle.chipMotionProgress(elapsed: elapsed, recipe: recipe)
        )
    }

    private func chipHeight(for kind: Kind) -> CGFloat {
        kind == .critical ? 44 : 36
    }

    private func pruneExpired(at date: Date) {
        let lifetime = TrinketMotion.Battle.displayDuration(for: recipe) + 0.05
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
#endif
