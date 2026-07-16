#if DEBUG
import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import UIKit

private struct HandMotionPlayground: View {
    @State private var configuration = BattleHandMotionConfiguration()
    @State private var cardCount: CGFloat = 5
    @State private var includeUnplayableCard = true
    @State private var showThresholdGuides = true
    @State private var showFanLabels = false
    @State private var cards: [BattleCard] = HandMotionPlayground.makeCards(count: 5)
    @State private var dealGeneration = 0
    @State private var forcedDragTranslation: (cardID: Int, translation: CGSize)?
    @State private var releasePose: CardActivationRequest?
    @State private var copiedBannerVisible = false
    @State private var cancelDemoTask: Task<Void, Never>?
    @State private var releasePoseTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .trinketSurface(.base)

            Form {
                scenarioSection
                fanSection
                dealSection
                heldSection
                thresholdSection
                denySection
                springsSection
                armedVisualSection
                experimentalSection
                exportSection
            }
            .frame(width: 360)
        }
        .onChange(of: cardCount) { _, newValue in
            rebuildHand(count: Int(newValue.rounded()))
        }
        .onChange(of: includeUnplayableCard) { _, _ in
            rebuildHand(count: Int(cardCount.rounded()))
        }
        .onDisappear {
            cancelDemoTask?.cancel()
            releasePoseTask?.cancel()
        }
    }

    // MARK: - Stage

    private var stage: some View {
        GeometryReader { geometry in
            let battleFrame = CGRect(origin: .zero, size: geometry.size)
            ZStack(alignment: .bottom) {
                battlefieldBackdrop

                if showThresholdGuides {
                    thresholdGuides(in: battleFrame)
                }

                BattleHandView(
                    cards: cards,
                    isPlayable: { card in
                        !(includeUnplayableCard && card.id == cards.first?.id)
                    },
                    onTap: { _ in },
                    onPlay: { card, request in
                        handleSuccessfulPlay(card: card, request: request)
                    },
                    hapticsEnabled: false,
                    battleFrame: battleFrame,
                    configuration: configuration,
                    forcedDragTranslation: forcedDragTranslation
                )
                .frame(height: BattleCardGridLayout.handReservedHeight)
                .offset(y: -configuration.bottomRise)
                .id(dealGeneration)

                if showFanLabels {
                    fanLabels(in: battleFrame)
                }

                if let releasePose {
                    releasePoseOverlay(releasePose)
                }

                if copiedBannerVisible {
                    Text("Copied parameter dump")
                        .font(.caption.weight(.semibold))
                        .trinketGlassChip()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, TrinketDesign.Metrics.largeSpacing)
                        .transition(.opacity)
                }
            }
            .coordinateSpace(.named(BattleCoordinateSpace.field))
        }
    }

    private var battlefieldBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    TrinketDesign.Colors.canvas,
                    TrinketDesign.Colors.elevated.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack {
                Text("Hand Motion Lab")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Drag a card up to play · release pose freezes here")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Rectangle()
                    .fill(TrinketDesign.Colors.subtleStroke.opacity(0.35))
                    .frame(height: 1)
                    .padding(.bottom, BattleCardGridLayout.handReservedHeight + configuration.bottomRise)
            }
            .padding(.top, TrinketDesign.Metrics.extraLargeSpacing)
        }
    }

    private func thresholdGuides(in battleFrame: CGRect) -> some View {
        let layout = BattleHandLayout.metrics(
            containerWidth: battleFrame.width,
            cardCount: max(cards.count, 1),
            configuration: configuration
        )
        let restY = battleFrame.maxY
            - configuration.bottomRise
            - layout.cardHeight / 2
            + layout.cardHeight * configuration.restingYFraction
        let playY = restY - configuration.playDragThreshold
        let armReleaseY = restY - configuration.playDragThreshold * configuration.playArmReleaseRatio

        return ZStack {
            guideLine(
                midX: battleFrame.midX,
                y: playY,
                label: "Play \(Int(configuration.playDragThreshold))pt",
                color: TrinketDesign.Colors.success
            )
            guideLine(
                midX: battleFrame.midX,
                y: armReleaseY,
                label: "Arm release \(Int(configuration.playDragThreshold * configuration.playArmReleaseRatio))pt",
                color: TrinketDesign.Colors.informational
            )
        }
        .allowsHitTesting(false)
    }

    private func guideLine(midX: CGFloat, y: CGFloat, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(color)
                .padding(.horizontal, TrinketDesign.Metrics.denseSpacing)
                .padding(.vertical, 2)
                .background(TrinketDesign.Colors.elevated.opacity(0.9), in: Capsule())
            Rectangle()
                .fill(color.opacity(0.55))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .position(x: midX, y: y)
    }

    private func fanLabels(in battleFrame: CGRect) -> some View {
        let layout = BattleHandLayout.metrics(
            containerWidth: battleFrame.width,
            cardCount: max(cards.count, 1),
            configuration: configuration
        )
        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, _ in
                let rotation = BattleHandLayout.rotation(
                    index: index,
                    cardCount: cards.count,
                    fanAngleStep: configuration.fanAngleStep
                )
                Text(String(format: "%.0f°", rotation))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .position(
                        x: battleFrame.midX + BattleHandLayout.cardOffsetX(
                            index: index,
                            metrics: layout,
                            containerWidth: battleFrame.width
                        ),
                        y: battleFrame.maxY - configuration.bottomRise - 8
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func releasePoseOverlay(_ request: CardActivationRequest) -> some View {
        ZStack {
            Circle()
                .stroke(TrinketDesign.Colors.warning.opacity(0.8), lineWidth: 2)
                .frame(width: 18, height: 18)
                .position(request.center)

            BattleAbilityCardFace(artworkName: request.artworkName)
                .frame(width: request.size.width, height: request.size.height)
                .scaleEffect(request.scale)
                .rotationEffect(.radians(request.rotation), anchor: .bottom)
                .rotation3DEffect(
                    .degrees(request.verticalTilt),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: request.perspective
                )
                .position(request.center)
                .opacity(0.92)

            Text("Release pose")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, TrinketDesign.Metrics.chipCompactPaddingHorizontal)
                .padding(.vertical, TrinketDesign.Metrics.chipCompactPaddingVertical)
                .background(TrinketDesign.Colors.warning.opacity(0.85), in: Capsule())
                .position(x: request.center.x, y: request.center.y - request.size.height * 0.55)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Form sections

    private var scenarioSection: some View {
        Section("Scenario") {
            parameterSlider("Card count", value: $cardCount, range: 1 ... 5, format: "%.0f")
            Toggle("First card unplayable", isOn: $includeUnplayableCard)
            Toggle("Show threshold guides", isOn: $showThresholdGuides)
            Toggle("Show fan angle labels", isOn: $showFanLabels)
            Button("Replay Deal") { replayDeal() }
            Button("Replay Cancel") { replayCancel() }
            Button("Clear Release Pose") { releasePose = nil }
                .disabled(releasePose == nil)
        }
    }

    private var fanSection: some View {
        Section("Fan Layout") {
            parameterSlider("Min width", value: $configuration.minCardWidth, range: 120 ... 180, format: "%.0f")
            parameterSlider("Max width", value: $configuration.maxCardWidth, range: 150 ... 220, format: "%.0f")
            parameterSlider("Width ratio", value: $configuration.widthRatio, range: 0.25 ... 0.6, format: "%.2f")
            parameterSlider("Overlap ratio", value: $configuration.maxOverlapRatio, range: 0.15 ... 0.7, format: "%.2f")
            parameterSlider("Fan angle step", value: $configuration.fanAngleStep, range: 0 ... 18, format: "%.1f°")
            parameterSlider("Fan lift step", value: $configuration.fanLiftStep, range: 0 ... 24, format: "%.0f")
            parameterSlider("Bottom rise", value: $configuration.bottomRise, range: 0 ... 60, format: "%.0f")
            parameterSlider("Rest Y fraction", value: $configuration.restingYFraction, range: 0 ... 0.5, format: "%.2f")
            parameterSlider("Horizontal inset", value: $configuration.horizontalInset, range: 0 ... 24, format: "%.0f")
        }
    }

    private var dealSection: some View {
        Section("Deal / Draw") {
            parameterSlider("Insert offset X", value: $configuration.dealInsertOffsetX, range: 0 ... 120, format: "%.0f")
            parameterSlider("Insert offset Y", value: $configuration.dealInsertOffsetY, range: 0 ... 140, format: "%.0f")
            parameterSlider("Insert scale", value: $configuration.dealInsertScale, range: 0.5 ... 1, format: "%.2f")
            parameterSlider(
                "Draw stagger",
                value: Binding(
                    get: { CGFloat(configuration.cardDrawStagger) },
                    set: { configuration.cardDrawStagger = TimeInterval($0) }
                ),
                range: 0 ... 0.2,
                format: "%.3f s"
            )
            springSliders(
                title: "Deal spring",
                response: $configuration.dealResponse,
                damping: $configuration.dealDamping
            )
            springSliders(
                title: "Hand reflow",
                response: $configuration.handReflowResponse,
                damping: $configuration.handReflowDamping
            )
        }
    }

    private var heldSection: some View {
        Section("Pickup / Held") {
            parameterSlider("Held scale", value: $configuration.cardHeldScale, range: 1 ... 1.2, format: "%.3f")
            parameterSlider("Shadow radius", value: $configuration.cardHeldShadowRadius, range: 0 ... 40, format: "%.0f")
            parameterSlider("Shadow Y", value: $configuration.cardHeldShadowY, range: 0 ... 30, format: "%.0f")
            parameterSlider(
                "Max tilt °",
                value: Binding(
                    get: { CGFloat(configuration.cardMaximumTiltDegrees) },
                    set: { configuration.cardMaximumTiltDegrees = Double($0) }
                ),
                range: 0 ... 20,
                format: "%.1f"
            )
            parameterSlider(
                "Tilt lean ×",
                value: Binding(
                    get: { CGFloat(configuration.tiltLeanMultiplier) },
                    set: { configuration.tiltLeanMultiplier = Double($0) }
                ),
                range: 0 ... 1,
                format: "%.2f"
            )
            parameterSlider(
                "Vertical tilt gain",
                value: Binding(
                    get: { CGFloat(configuration.verticalTiltGain) },
                    set: { configuration.verticalTiltGain = Double($0) }
                ),
                range: 0 ... 12,
                format: "%.1f"
            )
            parameterSlider(
                "Vertical tilt clamp",
                value: Binding(
                    get: { CGFloat(configuration.verticalTiltClamp) },
                    set: { configuration.verticalTiltClamp = Double($0) }
                ),
                range: 0 ... 12,
                format: "%.1f"
            )
            parameterSlider("Perspective", value: $configuration.perspective, range: 0.1 ... 1, format: "%.2f")
            springSliders(
                title: "Press",
                response: $configuration.cardPressResponse,
                damping: $configuration.cardPressDamping
            )
            springSliders(
                title: "Lift",
                response: $configuration.cardLiftResponse,
                damping: $configuration.cardLiftDamping
            )
            springSliders(
                title: "Return",
                response: $configuration.cardReturnResponse,
                damping: $configuration.cardReturnDamping
            )
        }
    }

    private var thresholdSection: some View {
        Section("Drag / Play Thresholds") {
            parameterSlider("Play threshold", value: $configuration.playDragThreshold, range: 30 ... 160, format: "%.0f")
            parameterSlider("Arm release ratio", value: $configuration.playArmReleaseRatio, range: 0.4 ... 1, format: "%.2f")
            parameterSlider("Drag min distance", value: $configuration.dragMinimumDistance, range: 0 ... 40, format: "%.0f")
            parameterSlider(
                "Armed horizontal allow",
                value: $configuration.armedHorizontalAllowance,
                range: 0.4 ... 1.2,
                format: "%.2f"
            )
        }
    }

    private var denySection: some View {
        Section("Deny Resist") {
            parameterSlider("Overshoot factor", value: $configuration.denyOvershootFactor, range: 0.5 ... 4, format: "%.2f")
            parameterSlider("Width damp", value: $configuration.denyWidthDamp, range: 0.3 ... 1, format: "%.2f")
        }
    }

    private var springsSection: some View {
        Section("Springs (summary)") {
            Text("Press / Lift / Return / Reflow / Deal knobs live in Held and Deal sections.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var armedVisualSection: some View {
        Section("Armed Visual") {
            Toggle("Show armed ring", isOn: $configuration.showArmedRing)
            parameterSlider("Armed scale boost", value: $configuration.armedScaleBoost, range: 0 ... 0.15, format: "%.3f")
            parameterSlider("Armed brightness", value: $configuration.armedBrightness, range: 0 ... 0.25, format: "%.3f")
            parameterSlider("Ring opacity", value: $configuration.armedRingOpacity, range: 0 ... 1, format: "%.2f")
            parameterSlider("Ring line width", value: $configuration.armedRingLineWidth, range: 1 ... 6, format: "%.1f")
        }
    }

    private var experimentalSection: some View {
        Section("Experimental (unused in production)") {
            springSliders(
                title: "Pickup",
                response: $configuration.pickupResponse,
                damping: $configuration.pickupDamping
            )
            springSliders(
                title: "Readiness",
                response: $configuration.readinessResponse,
                damping: $configuration.readinessDamping
            )
            springSliders(
                title: "Commit / cast",
                response: $configuration.cardCommitResponse,
                damping: $configuration.cardCommitDamping
            )
            springSliders(
                title: "Impact",
                response: $configuration.impactResponse,
                damping: $configuration.impactDamping
            )
            parameterSlider(
                "Max stretch",
                value: $configuration.cardMaximumStretch,
                range: 0 ... 0.1,
                format: "%.3f"
            )
            Text("These springs are not wired into the hand path yet. Tune for future commit-flight work.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var exportSection: some View {
        Section("Export") {
            Button("Copy Values") {
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
            Button("Reset Defaults") {
                cancelDemoTask?.cancel()
                forcedDragTranslation = nil
                releasePose = nil
                configuration = BattleHandMotionConfiguration()
                includeUnplayableCard = true
                cardCount = 5
                rebuildHand(count: 5)
            }
            Text(configuration.parameterDump())
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func rebuildHand(count: Int) {
        cancelDemoTask?.cancel()
        forcedDragTranslation = nil
        cards = Self.makeCards(count: max(1, min(5, count)))
        dealGeneration &+= 1
    }

    private func replayDeal() {
        cancelDemoTask?.cancel()
        forcedDragTranslation = nil
        releasePose = nil
        let count = Int(cardCount.rounded())
        cards = []
        dealGeneration &+= 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(configuration.deal) {
                cards = Self.makeCards(count: count)
            }
        }
    }

    private func replayCancel() {
        cancelDemoTask?.cancel()
        releasePose = nil
        guard let target = cards.first(where: { card in
            !(includeUnplayableCard && card.id == cards.first?.id)
        }) ?? cards.first else { return }

        let lift = CGSize(width: 0, height: -(configuration.playDragThreshold * 0.85))
        withAnimation(configuration.cardPress) {
            forcedDragTranslation = (cardID: target.id, translation: lift)
        }

        cancelDemoTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            withAnimation(configuration.cardReturn) {
                forcedDragTranslation = nil
            }
        }
    }

    private func handleSuccessfulPlay(card: BattleCard, request: CardActivationRequest) -> Bool {
        cancelDemoTask?.cancel()
        forcedDragTranslation = nil
        releasePoseTask?.cancel()
        releasePose = request
        cards.removeAll { $0.id == card.id }
        releasePoseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }
            withAnimation(configuration.handReflow) {
                releasePose = nil
                if cards.count < Int(cardCount.rounded()) {
                    cards = Self.makeCards(count: Int(cardCount.rounded()))
                }
            }
        }
        return true
    }

    private static func makeCards(count: Int) -> [BattleCard] {
        let abilities: [Ability] = [
            .slash,
            .bash,
            .heal,
            .smite,
            .slash
        ]
        return (0 ..< count).map { index in
            BattleCard(
                id: index + 1,
                ability: abilities[index % abilities.count],
                owner: index % 2 == 0 ? .hero : .companion
            )
        }
    }

    // MARK: - Controls

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

    private func springSliders(
        title: String,
        response: Binding<Double>,
        damping: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            parameterSlider(
                "Response",
                value: Binding(
                    get: { CGFloat(response.wrappedValue) },
                    set: { response.wrappedValue = Double($0) }
                ),
                range: 0.08 ... 0.8,
                format: "%.2f"
            )
            parameterSlider(
                "Damping",
                value: Binding(
                    get: { CGFloat(damping.wrappedValue) },
                    set: { damping.wrappedValue = Double($0) }
                ),
                range: 0.5 ... 1.1,
                format: "%.2f"
            )
        }
    }
}

#Preview("Hand Motion Lab") {
    HandMotionPlayground()
}
#endif
