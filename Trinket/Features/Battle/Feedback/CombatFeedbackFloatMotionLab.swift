import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import UIKit

#if DEBUG

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
        let recipe = TrinketMotion.Battle.chip(for: item.kind.feedbackClass)
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
            .critical
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
            .previewDevice(PreviewDevice(rawValue: "iPad Pro 13-inch (M4)"))
            .previewInterfaceOrientation(.landscapeLeft)
            .previewDisplayName("Combat Float Motion Lab")
    }
}
#endif
