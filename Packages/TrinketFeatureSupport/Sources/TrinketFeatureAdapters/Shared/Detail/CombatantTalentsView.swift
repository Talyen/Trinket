import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

public struct CombatantTalentsView: View {
    let tree: TalentTree
    let progression: CombatantProgression
    @Binding var unlockedTalents: Set<String>
    let allowsEditing: Bool
    let visibleNodeIDs: Set<String>?
    let showsReset: Bool
    let nodeAccessibilityIdentifier: (String) -> String
    let unlockAccessibilityIdentifier: String
    let onUnlockTalent: (TalentNode, TalentTree) -> Void
    let onResetTalents: () -> Void

    @State private var selectedNodeID: String?

    public init(
        tree: TalentTree,
        progression: CombatantProgression,
        unlockedTalents: Binding<Set<String>>,
        allowsEditing: Bool = true,
        initialSelectedNodeID: String? = nil,
        visibleNodeIDs: Set<String>? = nil,
        showsReset: Bool = true,
        nodeAccessibilityIdentifier: @escaping (String) -> String = AccessibilityID.CombatantDetail.talentsNode,
        unlockAccessibilityIdentifier: String = AccessibilityID.CombatantDetail.talentsUnlockButton,
        onUnlockTalent: @escaping (TalentNode, TalentTree) -> Void,
        onResetTalents: @escaping () -> Void,
    ) {
        self.tree = tree
        self.progression = progression
        _unlockedTalents = unlockedTalents
        self.allowsEditing = allowsEditing
        self.visibleNodeIDs = visibleNodeIDs
        self.showsReset = showsReset
        self.nodeAccessibilityIdentifier = nodeAccessibilityIdentifier
        self.unlockAccessibilityIdentifier = unlockAccessibilityIdentifier
        self.onUnlockTalent = onUnlockTalent
        self.onResetTalents = onResetTalents

        let defaultInitialID = tree.nodes.first(where: { visibleNodeIDs?.contains($0.id) ?? true })?.id
        let initialID = initialSelectedNodeID.flatMap { id in
            (visibleNodeIDs?.contains(id) ?? true) ? id : nil
        } ?? defaultInitialID

        _selectedNodeID = State(
            initialValue: initialID,
        )
    }

    private var availablePoints: Int {
        progression.availableTalentPoints(unlockedCount: unlockedTalents.count)
    }

    private var selectedNode: TalentNode? {
        if let selectedNodeID, let node = displayedNodes.first(where: { $0.id == selectedNodeID }) {
            return node
        }
        return displayedNodes.first
    }

    private var displayedNodes: [TalentNode] {
        tree.nodes.filter { visibleNodeIDs?.contains($0.id) ?? true }
    }

    public var body: some View {
        DetailHeroScrollShell(title: tree.name, heroHeightPolicy: .cinematicLandscape) { baseHeight in
            DetailHeroHeader(
                eyebrow: "TALENTS",
                title: tree.name,
                baseHeight: baseHeight,
            ) {
                talentArtwork
            }
        } bodyContent: {
            talentGrid
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                .padding(.top, TrinketDesign.Spacing.medium)
                .padding(.bottom, TrinketDesign.Spacing.large)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inspectorContent
                .padding(TrinketDesign.Layout.contentMargin)
                .frame(maxWidth: .infinity, alignment: .leading)
                .trinketMaterial(.bottomBar)
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                .padding(.bottom, TrinketDesign.Spacing.medium)
                .trinketSheetChromeIgnoresDismissDrag()
        }
        .onChange(of: tree.id) { _, _ in
            selectedNodeID = displayedNodes.first?.id
        }
        .onChange(of: visibleNodeIDs) { _, _ in
            if !displayedNodes.contains(where: { $0.id == selectedNodeID }) {
                selectedNodeID = displayedNodes.first?.id
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if showsReset, allowsEditing, hasTreeUnlocks {
                    Button("Reset") {
                        onResetTalents()
                    }
                    .trinketTypography(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(TrinketDesign.Colors.accent)
                    .accessibilityIdentifier(AccessibilityID.CombatantDetail.talentsResetButton)
                }
            }
        }
    }

    private var hasTreeUnlocks: Bool {
        tree.nodes.contains { unlockedTalents.contains($0.id) }
    }

    @ViewBuilder
    private var talentArtwork: some View {
        if let artReference = tree.keyword.artReference {
            Image.preparedAsset(artReference, displaySize: .full)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fill)
                .clipped()
                .decorativePreparedArtwork()
        } else {
            PlaceholderArtwork(
                tree.keyword.visualStyle,
                iconPointSize: 64,
                relativeTo: .largeTitle,
            )
        }
    }

    private var talentGrid: some View {
        VStack(spacing: TrinketDesign.Spacing.medium) {
            ForEach(tree.rows, id: \.self) { row in
                let rowNodes = displayedNodes.filter { $0.row == row }
                if !rowNodes.isEmpty {
                    let isRowLocked = row > 1
                        && !tree.isRowComplete(row - 1, unlockedNodeIDs: unlockedTalents)

                    HStack(spacing: TrinketDesign.Spacing.medium) {
                        ForEach(rowNodes) { node in
                            talentNodeCard(node: node, isRowLocked: isRowLocked)
                        }
                    }
                }
            }
        }
    }

    private func talentNodeCard(node: TalentNode, isRowLocked: Bool) -> some View {
        let isUnlocked = unlockedTalents.contains(node.id)
        let isSelected = selectedNodeID == node.id
        let style = node.keyword.visualStyle
        let symbolName = node.symbolName ?? style.symbolName

        return Button {
            selectedNodeID = node.id
        } label: {
            VStack(spacing: TrinketDesign.Spacing.small) {
                if isUnlocked {
                    Image(systemName: symbolName)
                        .trinketTypography(.screenTitle)
                        .foregroundStyle(style.color)
                        .accessibilityHidden(true)
                } else if isRowLocked {
                    Image(systemName: "lock.fill")
                        .trinketTypography(.sectionTitle)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: symbolName)
                        .trinketTypography(.screenTitle)
                        .foregroundStyle(style.color.opacity(0.75))
                        .accessibilityHidden(true)
                }

                Text(balanced: node.name)
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(isUnlocked ? .primary : (isRowLocked ? .tertiary : .secondary))
                    .multilineTextAlignment(.center)
                    .trinketFittedText()
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 104)
            .background(
                RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)
                    .fill(TrinketDesign.Colors.panel),
            )
            .overlay(
                RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)
                    .stroke(
                        isSelected ? .clear : (isUnlocked ? style.color.opacity(0.4) : .clear),
                        lineWidth: 1,
                    ),
            )
            .keywordShineBorder(
                keywords: isSelected ? referencedKeywords(for: node) : nil,
                cornerRadius: TrinketDesign.Corners.card,
                lineWidth: 2,
            )
            .shadow(
                color: isSelected ? style.glowColor.opacity(0.4) : .clear,
                radius: 8,
            )
            .saturation(isRowLocked ? 0.35 : 1.0)
            .opacity(isRowLocked ? 0.65 : 1.0)
        }
        .trinketQuietTapButtonStyle()
        .accessibilityIdentifier(nodeAccessibilityIdentifier(node.id))
    }

    private func referencedKeywords(for node: TalentNode) -> [Keyword] {
        var keywords = [node.keyword]
        for referenced in Keyword.referenced(in: node.description) where !keywords.contains(referenced) {
            keywords.append(referenced)
        }
        return keywords
    }

    private var inspectorContent: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            if let selectedNode {
                let isUnlocked = unlockedTalents.contains(selectedNode.id)
                let canUnlock = allowsEditing && tree.canUnlock(
                    node: selectedNode,
                    unlockedNodeIDs: unlockedTalents,
                    availablePoints: availablePoints,
                )
                let style = selectedNode.keyword.visualStyle
                let symbolName = selectedNode.symbolName ?? style.symbolName

                HStack(spacing: TrinketDesign.Spacing.small) {
                    Image(systemName: symbolName)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(style.color)
                        .accessibilityHidden(true)

                    Text(balanced: selectedNode.name)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(style.color)
                        .trinketFittedText()
                }

                KeywordDescriptionText(text: selectedNode.description)
                    .trinketTypography(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                unlockButton(
                    for: selectedNode,
                    isUnlocked: isUnlocked,
                    canUnlock: canUnlock,
                )
            }
        }
    }

    @ViewBuilder
    private func unlockButton(for node: TalentNode, isUnlocked: Bool, canUnlock: Bool) -> some View {
        let title = buttonLabel(for: node, isUnlocked: isUnlocked, canUnlock: canUnlock)
        if canUnlock {
            Button(title) {
                onUnlockTalent(node, tree)
            }
            .frame(maxWidth: .infinity)
            .trinketPrimaryActionButton(
                accessibilityIdentifier: unlockAccessibilityIdentifier,
            )
        } else {
            Button(title) {}
                .frame(maxWidth: .infinity)
                .trinketSecondaryActionButton(
                    accessibilityIdentifier: unlockAccessibilityIdentifier,
                )
                .disabled(true)
        }
    }

    private func buttonLabel(for node: TalentNode, isUnlocked: Bool, canUnlock: Bool) -> String {
        if isUnlocked {
            return "Unlocked"
        }
        if !allowsEditing {
            return "Locked"
        }
        if canUnlock {
            return "Unlock Talent"
        }
        if node.row > 1, !tree.isRowComplete(node.row - 1, unlockedNodeIDs: unlockedTalents) {
            return "Complete Row \(node.row - 1) to Unlock"
        }
        if availablePoints == 0 {
            return "No Points Available"
        }
        return "Locked"
    }
}
