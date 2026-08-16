import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

/// Direct talent tree view for a specific keyword affinity of a hero or companion.
public struct CombatantTalentsView: View {
    let combatant: Combatant
    let tree: TalentTree
    let progression: CombatantProgression
    @Binding var unlockedTalents: Set<String>
    let onUnlockTalent: (TalentNode, TalentTree) -> Void
    let onResetTalents: () -> Void

    @State private var selectedNodeID: String?

    public init(
        combatant: Combatant,
        tree: TalentTree,
        progression: CombatantProgression,
        unlockedTalents: Binding<Set<String>>,
        onUnlockTalent: @escaping (TalentNode, TalentTree) -> Void,
        onResetTalents: @escaping () -> Void
    ) {
        self.combatant = combatant
        self.tree = tree
        self.progression = progression
        _unlockedTalents = unlockedTalents
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
        VStack(spacing: 0) {
            talentGrid
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.top, TrinketDesign.Metrics.smallSpacing)
                .padding(.bottom, TrinketDesign.Metrics.mediumSpacing)

            Spacer(minLength: 0)

            inspectorFooter
        }
        .background(TrinketDesign.Colors.canvas.ignoresSafeArea())
        .navigationTitle(tree.keyword.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if hasTreeUnlocks {
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

    // MARK: - 2x3 Talent Grid

    private var talentGrid: some View {
        VStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            ForEach(1 ... 3, id: \.self) { tier in
                let tierNodes = tree.nodes(forTier: tier)
                let isTierLocked = (tier == 2 && !tree.isTierComplete(1, unlockedNodeIDs: unlockedTalents))
                    || (tier == 3 && !tree.isTierComplete(2, unlockedNodeIDs: unlockedTalents))

                HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
                    ForEach(tierNodes) { node in
                        talentNodeCard(node: node, isTierLocked: isTierLocked)
                    }
                }
            }
        }
    }

    private func talentNodeCard(node: TalentNode, isTierLocked: Bool) -> some View {
        let isUnlocked = unlockedTalents.contains(node.id)
        let isSelected = selectedNodeID == node.id
        let style = node.keyword.visualStyle

        return Button {
            selectedNodeID = node.id
        } label: {
            VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                if isUnlocked {
                    Image(systemName: node.symbolName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(style.color)
                } else if isTierLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: node.symbolName)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(style.color.opacity(0.75))
                }

                Text(node.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isUnlocked ? .primary : (isTierLocked ? .tertiary : .secondary))
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
                        isSelected ? style.color : (isUnlocked ? style.color.opacity(0.4) : .clear),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? style.glowColor.opacity(0.4) : .clear,
                radius: 8
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.CombatantDetail.talentsNode(id: node.id))
    }

    // MARK: - Inspector Footer

    private var inspectorFooter: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
            if let selectedNode {
                let isUnlocked = unlockedTalents.contains(selectedNode.id)
                let canUnlock = tree.canUnlock(
                    node: selectedNode,
                    unlockedNodeIDs: unlockedTalents,
                    availablePoints: availablePoints
                )
                let style = selectedNode.keyword.visualStyle

                Text(selectedNode.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(style.color)

                Text(selectedNode.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    if canUnlock {
                        onUnlockTalent(selectedNode, tree)
                    }
                } label: {
                    Text(buttonLabel(for: selectedNode, isUnlocked: isUnlocked, canUnlock: canUnlock))
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(canUnlock ? TrinketDesign.Colors.accent : TrinketDesign.Colors.surface)
                        )
                        .foregroundStyle(canUnlock ? TrinketDesign.Colors.Overlay.ink : .secondary)
                }
                .disabled(!canUnlock)
                .accessibilityIdentifier(AccessibilityID.CombatantDetail.talentsUnlockButton)
            }
        }
        .padding(TrinketDesign.Metrics.contentMargin)
        .background(
            Rectangle()
                .fill(TrinketDesign.Colors.panel)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Divider()
                .background(TrinketDesign.Colors.subtleStroke),
            alignment: .top
        )
    }

    private func buttonLabel(for node: TalentNode, isUnlocked: Bool, canUnlock: Bool) -> String {
        if isUnlocked {
            return "Unlocked"
        }
        if canUnlock {
            return "Unlock Talent"
        }
        if availablePoints == 0 {
            return "No Points Available"
        }
        if node.tier == 2 {
            return "Complete Row 1 to Unlock"
        }
        if node.tier == 3 {
            return "Complete Row 2 to Unlock"
        }
        return "Locked"
    }
}
