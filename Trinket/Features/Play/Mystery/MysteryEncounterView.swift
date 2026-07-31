import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct MysteryEncounterView: View {
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave
    @Bindable var session: MysteryEncounterSession
    let onResolveChoice: (String?) -> Bool
    let onSelectItem: (String) -> Bool
    let onCorruptItem: (String) -> Bool
    let onCancelCorruptSelection: () -> Void
    let onFinish: () -> Bool
    let onFinishCorruptionReveal: () -> Bool

    @State private var selectedDetail: CombatantDetailContext?
    @State private var artAppeared = false
    @State private var narrativeAppeared = false
    @State private var selectedChoiceID: String?
    @State private var choiceFeedbackTrigger = 0

    var body: some View {
        Group {
            if session.showsReveal, let unlockedID = session.unlockedCombatantID {
                MysteryUnlockContent(
                    session: session,
                    unlockedID: unlockedID,
                    onSelectDetail: { selectedDetail = $0 },
                    onFinish: onFinish
                )
            } else if session.showsReward, let result = session.applyResult {
                MysteryRewardContent(session: session, result: result, onFinish: onFinish)
            } else if session.showsCorruptionReveal, let result = session.corruptionResult {
                MysteryCorruptionRevealContent(
                    session: session,
                    result: result,
                    onFinish: onFinishCorruptionReveal
                )
            } else if session.showsCorruptItemChoice {
                MysteryCorruptItemChoiceContent(
                    session: session,
                    onCorruptItem: onCorruptItem,
                    onCancelCorruptSelection: onCancelCorruptSelection
                )
            } else if session.showsItemChoice {
                MysteryItemChoiceContent(
                    session: session,
                    onSelectItem: { itemID in
                        _ = onSelectItem(itemID)
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
                    hapticsEnabled: options.hapticsEnabled,
                    effectsVolume: options.effectsVolume,
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
                _ = onResolveChoice(selectedChoiceID)
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
            enabled: options.hapticsEnabled
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
    // swiftlint:disable:next function_body_length
    private func mysteryReward(for effect: MysteryEffect) -> some View {
        switch effect {
        case let .gainGold(amount):
            rewardSummary(
                title: "Gold",
                value: "\(playerSave.homestead.effects.adjustedGold(amount))",
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

        case .corruptItem:
            rewardSummary(
                title: "Corrupt Item",
                value: "Risk",
                systemIcon: "flame.fill",
                tint: TrinketDesign.Colors.destructive
            )

        case .leave:
            rewardSummary(
                title: "Walk Away",
                value: "Safe",
                systemIcon: "figure.walk",
                tint: .secondary
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
        if let artID = session.event.artID, let art = ArtCatalog.encounterArtByID[artID] {
            Image.preparedAsset(named: art.imageName)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else if let artID = session.event.artID, let art = ArtCatalog.backgroundArtByID[artID] {
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

@MainActor
@ViewBuilder
func mysteryPersistFailureBanner(
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
