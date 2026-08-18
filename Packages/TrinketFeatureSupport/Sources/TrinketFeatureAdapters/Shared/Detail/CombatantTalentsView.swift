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
    let onUnlockTalent: (TalentNode, TalentTree) -> Void
    let onResetTalents: () -> Void

    @State private var selectedNodeID: String?

    public init(
        tree: TalentTree,
        progression: CombatantProgression,
        unlockedTalents: Binding<Set<String>>,
        allowsEditing: Bool = true,
        onUnlockTalent: @escaping (TalentNode, TalentTree) -> Void,
        onResetTalents: @escaping () -> Void
    ) {
        self.tree = tree
        self.progression = progression
        _unlockedTalents = unlockedTalents
        self.allowsEditing = allowsEditing
        self.onUnlockTalent = onUnlockTalent
        self.onResetTalents = onResetTalents
        _selectedNodeID = State(initialValue: tree.nodes.first?.id)
    }

    private var availablePoints: Int {
        progression.availableTalentPoints(unlockedCount: unlockedTalents.count)
    }

    private var selectedNode: TalentNode? {
        if let selectedNodeID, let node = tree.nodes.first(where: { $0.id == selectedNodeID }) {
            return node
        }
        return tree.nodes.first
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
        }
        .onChange(of: tree.id) { _, _ in
            if let firstNodeID = tree.nodes.first?.id {
                selectedNodeID = firstNodeID
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if allowsEditing, hasTreeUnlocks {
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
            let style = tree.keyword.visualStyle
            ZStack {
                style.color.opacity(0.18)

                Image(systemName: style.symbolName)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(style.color)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    // MARK: - 2x3 Talent Grid

    private var talentGrid: some View {
        VStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            ForEach(1 ... 3, id: \.self) { row in
                let rowNodes = tree.nodes(forRow: row)
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
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(style.color)
                } else if isRowLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: style.symbolName)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(style.color.opacity(0.75))
                }

                Text(node.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isUnlocked ? .primary : (isRowLocked ? .tertiary : .secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(TrinketDesign.Colors.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? .clear : (isUnlocked ? style.color.opacity(0.4) : .clear),
                        lineWidth: 1
                    )
            )
            .keywordShineBorder(
                keywords: isSelected ? referencedKeywords(for: node) : nil,
                cornerRadius: 14,
                lineWidth: 2
            )
            .shadow(
                color: isSelected ? style.glowColor.opacity(0.4) : .clear,
                radius: 8
            )
            .saturation(isRowLocked ? 0.35 : 1.0)
            .opacity(isRowLocked ? 0.65 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.CombatantDetail.talentsNode(id: node.id))
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

                Text(selectedNode.name)
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
                accessibilityIdentifier: AccessibilityID.CombatantDetail.talentsUnlockButton
            )
        } else {
            Button(title) {}
                .frame(maxWidth: .infinity)
                .trinketSecondaryActionButton(
                    accessibilityIdentifier: AccessibilityID.CombatantDetail.talentsUnlockButton
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
