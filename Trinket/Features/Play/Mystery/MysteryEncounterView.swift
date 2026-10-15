import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct MysteryEncounterView: View {
    @Environment(\.locale) private var locale
    @Environment(\.requestFullGameOffer) private var requestOffer
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @Environment(EncounterPlayMode.self) private var encounters
    @Bindable var session: MysteryEncounterSession
    let preparedArtworkNames: [String]

    @State private var selectedDetail: CombatantDetailContext?
    @State private var selectedItem: InventoryItem?
    @State private var selectedChoiceID: String?
    @State private var choiceFeedbackTrigger = 0
    @State private var rewardFeedbackTrigger = 0
    @State private var corruptionWarningTrigger = 0
    @State private var mysteryPersistErrorTrigger = 0

    var body: some View {
        ZStack {
            if session.showsReveal, let unlockedID = session.unlockedCombatantID {
                MysteryUnlockContent(
                    session: session,
                    unlockedID: unlockedID,
                    onSelectDetail: presentCombatant,
                    onFinish: { encounters.finishMysteryEncounter(session: session, dismiss: false) },
                    onDismiss: { encounters.dismissMysteryEncounter(session: session) },
                )
                .transition(.opacity)
            } else if session.showsReward, let result = session.applyResult {
                MysteryRewardContent(
                    session: session,
                    result: result,
                    onClaim: { encounters.collectMysteryReward(session: session) },
                    onFinish: { encounters.dismissMysteryReward(session: session) },
                )
                .transition(.opacity)
            } else if session.showsCorruptionReveal, let result = session.corruptionResult {
                MysteryCorruptionRevealContent(
                    session: session,
                    result: result,
                    onFinish: {
                        let didFinish = encounters.finishMysteryCorruptionReveal(session: session)
                        if didFinish {
                            corruptionWarningTrigger &+= 1
                        }
                        return didFinish
                    },
                )
                .transition(.opacity)
            } else if session.showsCorruptItemChoice {
                MysteryCorruptItemChoiceContent(
                    session: session,
                    onCorruptItem: { encounters.corruptMysteryItem(session: session, itemID: $0) },
                    onCancelCorruptSelection: { encounters.cancelMysteryCorruptSelection(session: session) },
                )
                .transition(.opacity)
            } else if session.isCorruptionAltar || session.event.isRecruit {
                readingContent
                    .transition(.opacity)
            } else {
                offerContent
                    .transition(.opacity)
            }
        }
        .animation(TrinketMotion.Screen.crossfade, value: screenPhase)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketScreenBackground()
        .trinketSensoryFeedback(
            .success,
            trigger: rewardFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
        .trinketSensoryFeedback(
            .warning,
            trigger: corruptionWarningTrigger,
            enabled: options.hapticsEnabled,
        )
        .trinketSensoryFeedback(
            .error,
            trigger: mysteryPersistErrorTrigger,
            enabled: options.hapticsEnabled,
        )
        .onChange(of: session.showsReward) { _, isReward in
            if isReward {
                rewardFeedbackTrigger &+= 1
            }
        }
        .disabled(playerSave.isRetryingSaveAction)
        .onChange(of: session.persistFailureMessage) { _, newMessage in
            if newMessage != nil {
                selectedChoiceID = nil
                mysteryPersistErrorTrigger &+= 1
                if let id = session.event.unlockCombatantID, !playerSave.contentAccess.allowsCombatant(id) {
                    requestOffer(.combatant(id))
                }
            }
        }
        .preparedArtworkSheet(item: $selectedItem, artworkNames: {
            [$0.artReference?.imageName, $0.artReference?.thumbnailImageName].compactMap(\.self)
        }, content: { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .trinketDetailSheet()
        })
        .modifier(CombatantDetailSheet(
            selection: $selectedDetail,
            artworkNames: {
                CombatantDetailArtwork.rosterArtworkNames(for: $0.combatantID, playerSave: playerSave)
            },
            detailContent: { context in
                RosterCombatantDetailView(
                    kind: context.kind,
                    combatantID: context.combatantID,
                    hapticsEnabled: options.hapticsEnabled,
                    effectsVolume: options.effectsVolume,
                    hidesNavigationBar: false,
                )
            },
        ))
    }

    private func presentCombatant(_ context: CombatantDetailContext) {
        guard playerSave.contentAccess.allowsCombatant(context.combatantID) else {
            requestOffer(.combatant(context.combatantID))
            return
        }
        selectedDetail = context
    }

    private var screenPhase: MysteryScreenPhase {
        if session.showsReveal {
            return .reveal
        }
        if session.showsReward {
            return .reward
        }
        if session.showsCorruptionReveal {
            return .corruptionReveal
        }
        if session.showsCorruptItemChoice {
            return .corruptItemChoice
        }
        return .reading
    }

    private enum MysteryScreenPhase: Equatable {
        case reading
        case reveal
        case reward
        case corruptionReveal
        case corruptItemChoice
    }

    private var offerContent: some View {
        GeometryReader { geometry in
            DetailHeroScrollShell(
                title: session.event.title,
                heroHeightPolicy: .cinematicLandscape,
                hidesNavigationBar: true,
            ) { baseHeight in
                mysteryHeader(baseHeight: baseHeight, singleLineTitle: false)
            } bodyContent: {
                VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraLarge) {
                    Text(verbatim: session.event.localizedNarrative(for: session.offers, locale: locale))
                        .trinketTypography(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(AccessibilityID.Mystery.encounterNarrative)

                    MysteryOfferChoices(
                        offers: session.offers,
                        choices: session.event.choices,
                        width: geometry.size.width - TrinketDesign.Layout.contentMargin * 2,
                        preparedArtworkNames: preparedArtworkNames,
                        isDisabled: session.isResolvingChoice,
                        onInspect: { selectedItem = $0 },
                        onChoose: { _ = encounters.resolveMysteryChoice(session: session, choiceID: $0) },
                    )
                }
                .padding(TrinketDesign.Layout.contentMargin)
            }
        }
    }

    private var readingContent: some View {
        DetailHeroScrollShell(
            title: session.event.title,
            heroHeightPolicy: .cinematicLandscape,
            hidesNavigationBar: true,
        ) { baseHeight in
            mysteryHeader(baseHeight: baseHeight, singleLineTitle: true)
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Layout.contentMargin) {
                narrativeCard
                mysteryChoices
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.vertical, TrinketDesign.Spacing.large)
        }
        .safeAreaInset(edge: .bottom) {
            mysteryConfirmAction
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                .padding(.vertical, TrinketDesign.Spacing.medium)
        }
    }

    private func mysteryHeader(baseHeight: CGFloat, singleLineTitle: Bool) -> some View {
        DetailHeroHeader(
            eyebrow: String(localized: L10n.ui_mysteryencounterview_mystery_9a26a),
            title: session.event.title,
            titleAccessibilityIdentifier: AccessibilityID.Mystery.encounterTitle,
            baseHeight: baseHeight,
            horizontalPadding: TrinketDesign.Layout.contentMargin,
            bottomPadding: TrinketDesign.Spacing.large,
            singleLineTitle: singleLineTitle,
        ) {
            heroArtwork
        }
    }

    private var narrativeCard: some View {
        Text(verbatim: session.event.localizedNarrative(for: session.offers, locale: locale))
            .trinketTypography(.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(AccessibilityID.Mystery.encounterNarrative)
            .padding(TrinketDesign.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .trinketCardSurface()
    }

    private var mysteryChoices: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            if session.event.choices.count > 1 {
                Text(L10n.ui_mysteryencounterview_pick_a_reward_c1738)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            ForEach(session.event.choices, id: \.id) { choice in
                MysterySpecialChoiceCard(
                    choice: choice,
                    isSelected: selectedChoiceID == choice.id,
                    isDisabled: session.isResolvingChoice,
                ) {
                    guard selectedChoiceID != choice.id else { return }
                    selectedChoiceID = choice.id
                    choiceFeedbackTrigger += 1
                }
            }
        }
        .trinketSensoryFeedback(
            .selection,
            trigger: choiceFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
    }

    private var mysteryConfirmAction: some View {
        MysteryPrimaryFooter(
            title: String(localized: L10n.ui_mysteryencounterview_confirm_eebdd),
            accessibilityIdentifier: AccessibilityID.Mystery.confirmChoiceButton,
            isDisabled: selectedChoiceID == nil || session.isResolvingChoice,
        ) {
            guard let selectedChoiceID else { return }
            _ = encounters.resolveMysteryChoice(session: session, choiceID: selectedChoiceID)
        }
        .padding(.top, TrinketDesign.Spacing.small)
    }

    private var heroArtwork: some View {
        MysteryEventHeroArtwork(event: session.event, chapterID: session.stage.chapterID)
    }
}

struct MysteryPrimaryFooter: View {
    let title: String
    let accessibilityIdentifier: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            GameLabel(title)
                .frame(maxWidth: .infinity)
        }
        .trinketPrimaryActionButton(accessibilityIdentifier: accessibilityIdentifier)
        .trinketCenteredPrimaryAction()
        .disabled(isDisabled)
    }
}
