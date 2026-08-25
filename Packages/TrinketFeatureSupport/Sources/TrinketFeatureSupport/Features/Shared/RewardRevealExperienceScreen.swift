import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

/// Shared victory / mystery loot reveal: sequence lock, loot, and item-detail sheet.
public struct RewardRevealExperienceScreen<Experience: View>: View {
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
            lootSpacing: CGFloat = TrinketDesign.Metrics.largeSpacing
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
    let hasExperienceAwards: Bool
    let experience: (@escaping () -> Void) -> Experience
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
        hasExperienceAwards: Bool,
        loot: Loot,
        primaryActionTitle: String,
        primaryActionAccessibilityIdentifier: String,
        onPrimaryAction: @escaping () -> Bool,
        contentTopPadding: CGFloat = TrinketDesign.Metrics.smallSpacing,
        contentStackSpacing: CGFloat = TrinketDesign.Metrics.largeSpacing,
        @ViewBuilder experience: @escaping (@escaping () -> Void) -> Experience
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.hasExperienceAwards = hasExperienceAwards
        self.experience = experience
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
                isMotionActive: selectedRewardItem == nil
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
                        experience(onExperienceBarCompleted)
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
                            onSelectItem: { selectedRewardItem = $0 }
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
                pinsPrimaryActionToBottom: false
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
            if !hasExperienceAwards {
                revealSequence.start(itemCount: loot.items.count, walletCount: walletRewardCount)
            }
        }
        .onDisappear {
            revealSequence.cancel(walletCount: walletRewardCount)
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
            requiredCount: 2,
            itemCount: loot.items.count,
            walletCount: walletRewardCount
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
