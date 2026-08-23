import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

/// Direct talent tree view for a specific keyword affinity of a hero or companion.
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
        visibleNodeIDs: Set<String>? = nil,
        showsReset: Bool = true,
        nodeAccessibilityIdentifier: @escaping (String) -> String = AccessibilityID.CombatantDetail.talentsNode,
        unlockAccessibilityIdentifier: String = AccessibilityID.CombatantDetail.talentsUnlockButton,
        onUnlockTalent: @escaping (TalentNode, TalentTree) -> Void,
        onResetTalents: @escaping () -> Void
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
        _selectedNodeID = State(
            initialValue: tree.nodes.first(where: { visibleNodeIDs?.contains($0.id) ?? true })?.id
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
        DetailHeroScrollShell(title: tree.name, heroHeightPolicy: .cinematicLandscape) { baseHeight, overscroll in
            DetailHeroHeader(
                eyebrow: "TALENTS",
                title: tree.name,
                baseHeight: baseHeight,
                overscroll: overscroll
            ) {
                talentArtwork
            }
        } bodyContent: {
            talentGrid
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.top, TrinketDesign.Metrics.mediumSpacing)
                .padding(.bottom, TrinketDesign.Metrics.largeSpacing)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inspectorContent
                .padding(TrinketDesign.Metrics.contentMargin)
                .frame(maxWidth: .infinity, alignment: .leading)
                .trinketMaterial(.bottomBar)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.bottom, TrinketDesign.Metrics.mediumSpacing)
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
                    .font(.footnote.weight(.semibold))
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
                relativeTo: .largeTitle
            )
        }
    }

    // MARK: - 2x3 Talent Grid

    private var talentGrid: some View {
        VStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            ForEach(1 ... 3, id: \.self) { row in
                let rowNodes = displayedNodes.filter { $0.row == row }
                if !rowNodes.isEmpty {
                    let isRowLocked = (row == 2 && !tree.isRowComplete(1, unlockedNodeIDs: unlockedTalents))
                        || (row == 3 && !tree.isRowComplete(2, unlockedNodeIDs: unlockedTalents))

                    HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
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

        return Button {
            selectedNodeID = node.id
        } label: {
            VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                if isUnlocked {
                    Image(systemName: style.symbolName)
                        .trinketTypography(.screenTitle)
                        .foregroundStyle(style.color)
                } else if isRowLocked {
                    Image(systemName: "lock.fill")
                        .trinketTypography(.sectionTitle)
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: style.symbolName)
                        .trinketTypography(.screenTitle)
                        .foregroundStyle(style.color.opacity(0.75))
                }

                Text(node.name)
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(isUnlocked ? .primary : (isRowLocked ? .tertiary : .secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .background(
                RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)
                    .fill(TrinketDesign.Colors.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)
                    .stroke(
                        isSelected ? .clear : (isUnlocked ? style.color.opacity(0.4) : .clear),
                        lineWidth: 1
                    )
            )
            .keywordShineBorder(
                keywords: isSelected ? referencedKeywords(for: node) : nil,
                cornerRadius: TrinketDesign.Corners.card,
                lineWidth: 2
            )
            .shadow(
                color: isSelected ? style.glowColor.opacity(0.4) : .clear,
                radius: 8
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

    // MARK: - Inspector Content

    private var inspectorContent: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
            if let selectedNode {
                let isUnlocked = unlockedTalents.contains(selectedNode.id)
                let canUnlock = allowsEditing && tree.canUnlock(
                    node: selectedNode,
                    unlockedNodeIDs: unlockedTalents,
                    availablePoints: availablePoints
                )
                let style = selectedNode.keyword.visualStyle

                Text(balanced: selectedNode.name)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(style.color)

                KeywordDescriptionText(text: selectedNode.description)
                    .trinketTypography(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                unlockButton(
                    for: selectedNode,
                    isUnlocked: isUnlocked,
                    canUnlock: canUnlock
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
                accessibilityIdentifier: unlockAccessibilityIdentifier
            )
        } else {
            Button(title) {}
                .frame(maxWidth: .infinity)
                .trinketSecondaryActionButton(
                    accessibilityIdentifier: unlockAccessibilityIdentifier
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
        if node.row == 2, !tree.isRowComplete(1, unlockedNodeIDs: unlockedTalents) {
            return "Complete Row 1 to Unlock"
        }
        if node.row == 3, !tree.isRowComplete(2, unlockedNodeIDs: unlockedTalents) {
            return "Complete Row 2 to Unlock"
        }
        if availablePoints == 0 {
            return "No Points Available"
        }
        return "Locked"
    }
}
