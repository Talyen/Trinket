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
        public let collapsesWalletToSingleColumnForAccessibility: Bool

        public init(
            items: [InventoryItem],
            gold: Int,
            materials: [ResourceAmount],
            showsIncreasePrefix: Bool,
            emptyMessage: String?,
            itemAccessibilityID: @escaping (String) -> String,
            lootAccessibilityIdentifier: String? = nil,
            lootSpacing: CGFloat = TrinketDesign.Metrics.largeSpacing,
            collapsesWalletToSingleColumnForAccessibility: Bool = false
        ) {
            self.items = items
            self.gold = gold
            self.materials = materials
            self.showsIncreasePrefix = showsIncreasePrefix
            self.emptyMessage = emptyMessage
            self.itemAccessibilityID = itemAccessibilityID
            self.lootAccessibilityIdentifier = lootAccessibilityIdentifier
            self.lootSpacing = lootSpacing
            self.collapsesWalletToSingleColumnForAccessibility = collapsesWalletToSingleColumnForAccessibility
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    }

    public var body: some View {
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
                        walletColumnCount: walletColumnCount,
                        spacing: loot.lootSpacing,
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
        .sheet(item: $selectedRewardItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .trinketDetailSheet()
        }
        .onAppear {
            if !hasExperienceAwards {
                revealSequence.start(itemCount: loot.items.count, walletCount: walletRewardCount)
            }
        }
        .onDisappear {
            revealSequence.cancel(walletCount: walletRewardCount)
        }
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

    private var walletColumnCount: Int {
        if loot.collapsesWalletToSingleColumnForAccessibility, dynamicTypeSize.isAccessibilitySize {
            return 1
        }
        return walletRewardCount
    }
}
