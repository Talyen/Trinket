import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public struct RewardRevealExperienceAward: Identifiable, Sendable {
    public let id: String
    public let combatantName: String
    public let artworkName: String?
    public let progressionBefore: CombatantProgression
    public let progressionAfter: CombatantProgression
    public let experienceAward: Int
    public let accessibilityIdentifier: String?

    public init(
        id: String,
        combatantName: String,
        artworkName: String? = nil,
        progressionBefore: CombatantProgression,
        progressionAfter: CombatantProgression,
        experienceAward: Int,
        accessibilityIdentifier: String? = nil,
    ) {
        self.id = id
        self.combatantName = combatantName
        self.artworkName = artworkName
        self.progressionBefore = progressionBefore
        self.progressionAfter = progressionAfter
        self.experienceAward = experienceAward
        self.accessibilityIdentifier = accessibilityIdentifier
    }
}

public struct RewardRevealExperienceScreen<EmptyExperience: View>: View {
    public typealias Award = RewardRevealExperienceAward

    public struct Loot {
        public let items: [InventoryItem]
        public let gold: Int
        public let materials: [ResourceAmount]
        public let showsIncreasePrefix: Bool
        public let emptyMessage: String?
        public let itemAccessibilityID: (String) -> String
        public let lootAccessibilityIdentifier: String?
        public let lootSpacing: CGFloat

        public init(
            items: [InventoryItem],
            gold: Int,
            materials: [ResourceAmount],
            showsIncreasePrefix: Bool,
            emptyMessage: String?,
            itemAccessibilityID: @escaping (String) -> String,
            lootAccessibilityIdentifier: String? = nil,
            lootSpacing: CGFloat = TrinketDesign.Metrics.largeSpacing,
        ) {
            self.items = items
            self.gold = gold
            self.materials = materials
            self.showsIncreasePrefix = showsIncreasePrefix
            self.emptyMessage = emptyMessage
            self.itemAccessibilityID = itemAccessibilityID
            self.lootAccessibilityIdentifier = lootAccessibilityIdentifier
            self.lootSpacing = lootSpacing
        }
    }

    let eyebrow: String?
    let title: String
    let titleAccessibilityIdentifier: String
    let experienceAwards: [Award]
    let experienceAccessibilityIdentifier: String?
    let experienceSpacing: CGFloat
    let emptyExperience: () -> EmptyExperience
    let loot: Loot
    let primaryActionTitle: String
    let primaryActionAccessibilityIdentifier: String
    let onPrimaryAction: () -> Bool
    var contentTopPadding: CGFloat
    var contentStackSpacing: CGFloat

    @State private var isCompleting = false
    @State private var revealSequence = RewardRevealSequenceState()
    @State private var selectedRewardItem: InventoryItem?
    @State private var focusedItemID: String?

    public init(
        eyebrow: String?,
        title: String,
        titleAccessibilityIdentifier: String,
        experienceAwards: [Award] = [],
        experienceAccessibilityIdentifier: String? = nil,
        experienceSpacing: CGFloat = TrinketDesign.Metrics.mediumSpacing,
        loot: Loot,
        primaryActionTitle: String,
        primaryActionAccessibilityIdentifier: String,
        onPrimaryAction: @escaping () -> Bool,
        contentTopPadding: CGFloat = TrinketDesign.Metrics.smallSpacing,
        contentStackSpacing: CGFloat = TrinketDesign.Metrics.largeSpacing,
        @ViewBuilder emptyExperience: @escaping () -> EmptyExperience,
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.experienceAwards = experienceAwards
        self.experienceAccessibilityIdentifier = experienceAccessibilityIdentifier
        self.experienceSpacing = experienceSpacing
        self.emptyExperience = emptyExperience
        self.loot = loot
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionAccessibilityIdentifier = primaryActionAccessibilityIdentifier
        self.onPrimaryAction = onPrimaryAction
        self.contentTopPadding = contentTopPadding
        self.contentStackSpacing = contentStackSpacing
        _focusedItemID = State(initialValue: loot.items.first?.id)
    }

    public var body: some View {
        ZStack {
            KeywordPlasmaBackground(
                keywords: focusedPlasmaKeywords,
                isMotionActive: selectedRewardItem == nil,
            )

            RewardRevealShell(
                eyebrow: eyebrow,
                eyebrowAccessibilityIdentifier: nil,
                title: title,
                subtitle: nil,
                titleAccessibilityIdentifier: titleAccessibilityIdentifier,
                titleColor: TrinketDesign.Colors.accent,
                content: {
                    VStack(spacing: contentStackSpacing) {
                        experienceSection
                        RewardRevealLootSection(
                            items: loot.items,
                            gold: loot.gold,
                            materials: loot.materials,
                            showsIncreasePrefix: loot.showsIncreasePrefix,
                            emptyMessage: loot.emptyMessage,
                            itemAccessibilityID: loot.itemAccessibilityID,
                            areItemsVisible: revealSequence.areItemsVisible,
                            visibleWalletRewardCount: revealSequence.visibleWalletRewardCount,
                            spacing: loot.lootSpacing,
                            focusedItemID: $focusedItemID,
                            onSelectItem: { selectedRewardItem = $0 },
                        )
                        .accessibilityIdentifier(loot.lootAccessibilityIdentifier ?? titleAccessibilityIdentifier)
                    }
                },
                primaryActionTitle: revealSequence.isSequenceComplete ? primaryActionTitle : nil,
                primaryActionAccessibilityIdentifier: primaryActionAccessibilityIdentifier,
                isPrimaryActionDisabled: isCompleting,
                onPrimaryAction: complete,
                contentTopPadding: contentTopPadding,
                contentStackSpacing: contentStackSpacing,
                pinsPrimaryActionToBottom: false,
            )
        }
        .sheet(item: $selectedRewardItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .trinketDetailSheet()
        }
        .onAppear {
            if focusedItemID == nil {
                focusedItemID = loot.items.first?.id
            }
            if experienceAwards.isEmpty {
                revealSequence.start(itemCount: loot.items.count, walletCount: walletRewardCount)
            }
        }
        .onDisappear {
            revealSequence.cancel(walletCount: walletRewardCount)
        }
    }

    @ViewBuilder
    private var experienceSection: some View {
        if !experienceAwards.isEmpty {
            VStack(alignment: .leading, spacing: experienceSpacing) {
                ForEach(experienceAwards) { award in
                    ExperienceBar(
                        combatantName: award.combatantName,
                        artworkName: award.artworkName,
                        pre: award.progressionBefore,
                        post: award.progressionAfter,
                        fillColor: TrinketDesign.Colors.accentEmphasized,
                        experienceAward: award.experienceAward,
                        snapToFinal: false,
                        onAnimationCompleted: onExperienceBarCompleted,
                    )
                    .accessibilityIdentifier(award.accessibilityIdentifier ?? "\(award.combatantName) experience bar")
                }
            }
            .trinketSurface(.secondary)
            .accessibilityIdentifier(experienceAccessibilityIdentifier ?? "")
        } else if EmptyExperience.self != EmptyView.self {
            emptyExperience()
                .trinketSurface(.secondary)
                .accessibilityIdentifier(experienceAccessibilityIdentifier ?? "")
        }
    }

    private var focusedPlasmaKeywords: [Keyword] {
        guard let focusedItemID,
              let item = loot.items.first(where: { $0.id == focusedItemID })
        else {
            return loot.items.first?.plasmaKeywords ?? []
        }
        return item.plasmaKeywords
    }

    private func onExperienceBarCompleted() {
        revealSequence.experienceBarCompleted(
            requiredCount: experienceAwards.count,
            itemCount: loot.items.count,
            walletCount: walletRewardCount,
        )
    }

    private func complete() {
        guard revealSequence.isSequenceComplete, !isCompleting else { return }
        isCompleting = onPrimaryAction()
    }

    private var walletRewardCount: Int {
        RewardRevealLootSection.walletRewardCount(gold: loot.gold, materials: loot.materials)
    }
}

public extension RewardRevealExperienceScreen where EmptyExperience == EmptyView {
    init(
        eyebrow: String?,
        title: String,
        titleAccessibilityIdentifier: String,
        experienceAwards: [Award] = [],
        experienceAccessibilityIdentifier: String? = nil,
        experienceSpacing: CGFloat = TrinketDesign.Metrics.mediumSpacing,
        loot: Loot,
        primaryActionTitle: String,
        primaryActionAccessibilityIdentifier: String,
        onPrimaryAction: @escaping () -> Bool,
        contentTopPadding: CGFloat = TrinketDesign.Metrics.smallSpacing,
        contentStackSpacing: CGFloat = TrinketDesign.Metrics.largeSpacing,
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            titleAccessibilityIdentifier: titleAccessibilityIdentifier,
            experienceAwards: experienceAwards,
            experienceAccessibilityIdentifier: experienceAccessibilityIdentifier,
            experienceSpacing: experienceSpacing,
            loot: loot,
            primaryActionTitle: primaryActionTitle,
            primaryActionAccessibilityIdentifier: primaryActionAccessibilityIdentifier,
            onPrimaryAction: onPrimaryAction,
            contentTopPadding: contentTopPadding,
            contentStackSpacing: contentStackSpacing,
            emptyExperience: { EmptyView() },
        )
    }
}
