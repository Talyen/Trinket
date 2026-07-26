import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct MysteryEncounterView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: MysteryEncounterSession

    @State private var selectedDetail: CombatantDetailContext?
    @State private var artAppeared = false
    @State private var narrativeAppeared = false
    @State private var selectedChoiceID: String?
    @State private var choiceFeedbackTrigger = 0
    @State private var unlockFeedbackTrigger = 0
    @State private var unlockRevealPhase: UnlockRevealPhase = .hidden
    @State private var hasStartedUnlockReveal = false
    @State private var unlockRevealTask: Task<Void, Never>?

    var body: some View {
        Group {
            if session.showsReveal, let unlockedID = session.unlockedCombatantID {
                unlockRevealContent(unlockedID: unlockedID)
            } else if session.showsReward, let result = session.applyResult {
                MysteryRewardContent(session: session, result: result)
            } else if session.showsItemChoice {
                MysteryItemChoiceContent(
                    session: session,
                    onSelectItem: { itemID in
                        _ = appState.selectActiveMysteryItem(itemID: itemID)
                    }
                )
            } else {
                readingContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketScreenBackground()
        .sheet(item: $selectedDetail) { context in
            NavigationStack {
                RosterCombatantDetailView(
                    kind: context.kind,
                    combatantID: context.combatantID,
                    hidesNavigationBar: false
                )
            }
            .trinketDetailSheet()
        }
        .onAppear {
            EncounterReadingEntrance.present(
                artAppeared: $artAppeared,
                copyAppeared: $narrativeAppeared
            )
        }
        .onDisappear {
            unlockRevealTask?.cancel()
            unlockRevealTask = nil
            // Cancel without completion left Recruit locked when @State survived
            // (same class as VictoryView / ExperienceBar onDisappear snap).
            if hasStartedUnlockReveal {
                finishUnlockReveal()
            }
        }
    }

    private var readingContent: some View {
        DetailHeroScrollShell(
            title: session.event.title,
            heroHeightPolicy: .cinematicLandscape,
            hidesNavigationBar: true
        ) { baseHeight, overscroll in
            DetailHeroHeader(
                eyebrow: "MYSTERY EVENT",
                title: session.event.title,
                titleAccessibilityIdentifier: AccessibilityID.Mystery.encounterTitle,
                baseHeight: baseHeight,
                overscroll: overscroll,
                horizontalPadding: TrinketDesign.Metrics.contentMargin,
                bottomPadding: TrinketDesign.Metrics.largeSpacing
            ) {
                heroArtwork
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                narrativeCard
                mysteryPersistFailureBanner(session.persistFailureMessage)
                mysteryChoices
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.top, TrinketDesign.Metrics.largeSpacing)
            .padding(.bottom, TrinketDesign.Metrics.compactTabBarContentClearance)
        }
    }

    private var narrativeCard: some View {
        Text(session.event.narrative)
            .trinketTypography(.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(AccessibilityID.Mystery.encounterNarrative)
            .padding(TrinketDesign.Metrics.largeSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .trinketCardSurface()
    }

    private var mysteryChoices: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
            if session.event.choices.count > 1 {
                Text("CHOOSE YOUR PATH")
                    .trinketTypography(.eyebrow)
                    .foregroundStyle(.secondary)
                    .padding(.leading, TrinketDesign.Metrics.smallSpacing)
            }

            ForEach(session.event.choices, id: \.id) { choice in
                mysteryChoiceButton(choice)
            }

            Button {
                guard let selectedChoiceID else { return }
                _ = appState.resolveActiveMysteryChoice(choiceID: selectedChoiceID)
            } label: {
                Text("Confirm")
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton(
                accessibilityIdentifier: AccessibilityID.Mystery.confirmChoiceButton
            )
            .disabled(selectedChoiceID == nil || session.isResolvingChoice)
            .padding(.top, TrinketDesign.Metrics.smallSpacing)
        }
        .trinketSensoryFeedback(
            .selection,
            trigger: choiceFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
    }

    private func mysteryChoiceButton(_ choice: MysteryChoice) -> some View {
        let isSelected = selectedChoiceID == choice.id

        return Button {
            guard !isSelected else { return }
            selectedChoiceID = choice.id
            choiceFeedbackTrigger += 1
        } label: {
            HStack(alignment: .center, spacing: TrinketDesign.Metrics.largeSpacing) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? TrinketDesign.Colors.accent : .secondary)

                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
                    Text(choice.label)
                        .trinketTypography(.rowTitle)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    mysteryRewards(choice)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(TrinketDesign.Metrics.largeSpacing)
            .contentShape(Rectangle())
        }
        .trinketQuietTapButtonStyle()
        .trinketCardSurface()
        .accessibilityIdentifier(AccessibilityID.Mystery.choiceButton(choiceID: choice.id))
        .disabled(session.isResolvingChoice)
    }

    private func mysteryRewards(_ choice: MysteryChoice) -> some View {
        HStack(alignment: .top, spacing: TrinketDesign.Metrics.mediumSpacing) {
            ForEach(Array(choice.effects.enumerated()), id: \.offset) { _, effect in
                mysteryReward(for: effect)
            }
        }
    }

    @ViewBuilder
    private func mysteryReward(for effect: MysteryEffect) -> some View {
        switch effect {
        case let .gainGold(amount):
            rewardSummary(
                title: "Gold",
                value: "\(appState.homestead.effects.adjustedGold(amount))",
                resource: .gold,
                tint: HomesteadResource.gold.tint
            )

        case let .gainMaterial(resource, amount):
            rewardSummary(
                title: resource.displayName,
                value: "\(amount)",
                resource: resource,
                tint: resource.tint
            )

        case let .gainExperience(amount):
            rewardSummary(
                title: "XP",
                value: "\(amount)",
                systemIcon: "star.fill",
                tint: TrinketDesign.Colors.warning
            )

        case let .gainGeneratedItem(baseTypeID, guaranteedAffixIDs):
            rewardSummary(
                title: generatedItemRewardText(
                    baseTypeID: baseTypeID,
                    guaranteedAffixIDs: guaranteedAffixIDs
                ),
                value: "1",
                systemIcon: "shippingbox.fill",
                tint: TrinketDesign.Colors.encounterEvent
            )

        case .gainRandomItem:
            rewardSummary(
                title: "Random Item",
                value: "1",
                systemIcon: "shippingbox.fill",
                tint: TrinketDesign.Colors.encounterEvent
            )

        case .chooseItem:
            rewardSummary(
                title: "Choose Item",
                value: "1 of \(MysteryEffectApplier.chooseItemCandidateCount)",
                systemIcon: "square.grid.2x2.fill",
                tint: TrinketDesign.Colors.encounterEvent
            )

        case let .unlockCombatant(combatantID):
            rewardSummary(
                title: combatantName(id: combatantID),
                value: "Unlock",
                systemIcon: "person.crop.circle.badge.plus",
                tint: TrinketDesign.Colors.accent
            )
        }
    }

    private func rewardSummary(
        title: String,
        value: String,
        resource: HomesteadResource? = nil,
        systemIcon: String? = nil,
        tint: Color
    ) -> some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            if let resource {
                HomesteadResourceArtwork(resource: resource)
                    .frame(
                        width: TrinketDesign.Metrics.walletResourceArtworkSize,
                        height: TrinketDesign.Metrics.walletResourceArtworkSize
                    )
            } else if let systemIcon {
                Image(systemName: systemIcon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(
                        width: TrinketDesign.Metrics.walletResourceArtworkSize,
                        height: TrinketDesign.Metrics.walletResourceArtworkSize
                    )
            }

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
                Text(title)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(value)
                    .trinketTypography(.statValue)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: TrinketDesign.Metrics.walletResourceRowMinHeight,
            alignment: .leading
        )
    }

    private func generatedItemRewardText(
        baseTypeID: String,
        guaranteedAffixIDs: [String]
    ) -> String {
        let itemName = GameContent.itemBaseTypes.first { $0.id == baseTypeID }?.name ?? "Item"
        let guaranteedAffixes = guaranteedAffixIDs.compactMap {
            GameContent.itemAffixDefinition(matching: $0)?.title
        }
        let affixText = guaranteedAffixes.map { "\($0) guaranteed" }
        return ([itemName] + affixText).joined(separator: " • ")
    }

    private func combatantName(id: String) -> String {
        let combatant = (GameContent.heroes + GameContent.companions).first { $0.id == id }
        return combatant?.name ?? "Combatant"
    }

    @ViewBuilder
    private var heroArtwork: some View {
        if let artID = session.event.artID, let art = ArtCatalog.backgroundArtByID[artID] {
            Image.preparedAsset(named: art.imageName)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else if let art = ArtCatalog.backgroundArtByID[session.stage.chapterID] {
            Image.preparedAsset(named: art.imageName)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else {
            TrinketDesign.Colors.encounterEvent
        }
    }
}

// MARK: - Unlock Reveal Extension

extension MysteryEncounterView {
    @ViewBuilder
    private func unlockRevealContent(unlockedID: String) -> some View {
        if let combatant = revealCombatant(id: unlockedID) {
            recruitUnlockStage(combatant: combatant)
                .trinketSensoryFeedback(
                    .success,
                    trigger: unlockFeedbackTrigger,
                    enabled: appState.options.hapticsEnabled
                )
                .onAppear {
                    unlockFeedbackTrigger += 1
                    startUnlockReveal()
                }
        }
    }

    private func recruitUnlockStage(combatant: Combatant) -> some View {
        let artVisible = unlockRevealPhase >= .art

        return RewardRevealShell(
            eyebrow: combatant.role == .companion ? "New Companion" : "New Hero",
            eyebrowAccessibilityIdentifier: AccessibilityID.Mystery.unlockEyebrow,
            title: combatant.name,
            subtitle: "UNLOCKED",
            subtitleAccessibilityIdentifier: AccessibilityID.Mystery.unlockSubtitle,
            titleAccessibilityIdentifier: AccessibilityID.Mystery.unlockName,
            eyebrowOpacity: unlockRevealPhase.opacity(visibleFrom: .eyebrow),
            titleOpacity: unlockRevealPhase.opacity(visibleFrom: .title),
            subtitleOpacity: unlockRevealPhase.opacity(visibleFrom: .subtitle),
            content: {
                VStack(spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    Button {
                        selectedDetail = CombatantDetailContext(
                            kind: combatant.role == .companion ? .companion : .hero,
                            combatantID: combatant.id
                        )
                    } label: {
                        CombatantArtwork(combatant: combatant, variant: .hero)
                            .aspectRatio(session.stage.encounter.artAspectRatio, contentMode: .fit)
                            .clipShape(TrinketDesign.cardShape)
                            .trinketCardSurface()
                    }
                    // UIStyleCheck: allow - Unlock art is the tap target for combatant detail; no button chrome.
                    .trinketQuietTapButtonStyle()
                    .accessibilityIdentifier(AccessibilityID.Mystery.unlockCard(name: combatant.name))
                    .opacity(artVisible ? 1 : 0)
                    .scaleEffect(artVisible ? 1 : 0.94)
                    .frame(maxWidth: 430)
                    .allowsHitTesting(artVisible)

                    mysteryPersistFailureBanner(session.persistFailureMessage, centered: true)
                }
            },
            primaryActionTitle: unlockRevealPhase >= .complete ? "Recruit" : nil,
            primaryActionAccessibilityIdentifier: AccessibilityID.Mystery.continueButton,
            isPrimaryActionDisabled: false,
            onPrimaryAction: {
                _ = appState.finishActiveMysteryEncounter()
            },
            pinsPrimaryActionToBottom: false,
            primaryActionWidthFraction: 0.5
        )
    }

    private func startUnlockReveal() {
        guard !hasStartedUnlockReveal else { return }
        hasStartedUnlockReveal = true
        unlockRevealTask?.cancel()
        unlockRevealTask = Task { @MainActor in
            let clock = SuspendingClock()
            let stagger = TrinketMotion.Reward.resourceStagger
            let steps: [(UnlockRevealPhase, Animation)] = [
                (.eyebrow, TrinketMotion.Reward.reveal),
                (.title, TrinketMotion.Reward.reveal),
                (.subtitle, TrinketMotion.Reward.stateChange),
                (.art, TrinketMotion.Reward.reveal)
            ]

            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.itemRevealDelay))
            guard !Task.isCancelled else { return }

            for (index, step) in steps.enumerated() {
                if index > 0 {
                    try? await clock.sleep(for: .seconds(stagger))
                    guard !Task.isCancelled else { return }
                }
                withAnimation(step.1) {
                    unlockRevealPhase = step.0
                }
            }

            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.completionDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.stateChange) {
                finishUnlockReveal()
            }
            unlockRevealTask = nil
        }
    }

    private func finishUnlockReveal() {
        guard unlockRevealPhase != .complete else { return }
        unlockRevealPhase = .complete
    }

    private func revealCombatant(id: String) -> Combatant? {
        if let sessionCombatant = session.combatant, sessionCombatant.id == id {
            return appState.roster.configuredCombatant(sessionCombatant)
        }
        let catalog = GameContent.heroes + GameContent.companions
        guard let combatant = catalog.first(where: { $0.id == id }) else { return nil }
        return appState.roster.configuredCombatant(combatant)
    }
}

/// Ordered chrome reveal for mystery unlock; drives `RewardRevealShell` opacities.
private enum UnlockRevealPhase: Int, Comparable {
    case hidden = 0
    case eyebrow = 1
    case title = 2
    case subtitle = 3
    case art = 4
    case complete = 5

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func opacity(visibleFrom phase: UnlockRevealPhase) -> Double {
        self >= phase ? 1 : 0
    }
}

@MainActor
@ViewBuilder
private func mysteryPersistFailureBanner(
    _ message: String?,
    centered: Bool = false
) -> some View {
    if let message {
        Text(message)
            .trinketTypography(.badge)
            .foregroundStyle(TrinketDesign.Colors.warning)
            .multilineTextAlignment(centered ? .center : .leading)
            .accessibilityIdentifier(AccessibilityID.Mystery.persistFailure)
            .transition(.opacity)
    }
}

private struct MysteryItemChoiceContent: View {
    @Bindable var session: MysteryEncounterSession
    let onSelectItem: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    Text("Choose a Find")
                        .trinketTypography(.screenTitle)
                        .accessibilityIdentifier(AccessibilityID.Mystery.chooseItemTitle)

                    Text("Three relics answer the scrolls. Take one.")
                        .trinketTypography(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    mysteryPersistFailureBanner(session.persistFailureMessage)
                }

                LazyVGrid(
                    columns: TrinketDesign.Metrics.collectionGridItems,
                    spacing: TrinketDesign.Metrics.largeSpacing
                ) {
                    ForEach(session.itemCandidates) { item in
                        EncounterItemTile(
                            item: item,
                            showsName: true,
                            isDisabled: session.isResolvingChoice,
                            accessibilityID: AccessibilityID.Mystery.chooseItemCard(itemID: item.id),
                            onSelect: { onSelectItem(item.id) }
                        )
                    }
                }
            }
            .padding(TrinketDesign.Metrics.extraLargeSpacing)
        }
    }
}
