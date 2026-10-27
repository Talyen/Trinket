import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

public struct CombatantTalentsView: View {
    @Environment(\.locale) private var locale
    let tree: TalentTree
    let progression: CombatantProgression
    let unlockedTalents: Set<String>
    let allowsEditing: Bool
    let visibleNodeIDs: Set<String>?
    let showsReset: Bool
    let nodeAccessibilityIdentifier: (String) -> String
    let unlockAccessibilityIdentifier: String
    let hapticsEnabled: Bool
    let onUnlockTalent: (TalentNode, TalentTree) -> RosterEditResult
    let onResetTalents: (() -> Bool)?

    @State private var selectedNodeID: String?
    @State private var selectionFeedbackTrigger = 0
    @State private var unlockSuccessTrigger = 0
    @State private var confirmedNodeID: String?

    public init(
        tree: TalentTree,
        progression: CombatantProgression,
        unlockedTalents: Set<String>,
        allowsEditing: Bool = true,
        initialSelectedNodeID: String? = nil,
        visibleNodeIDs: Set<String>? = nil,
        showsReset: Bool = true,
        nodeAccessibilityIdentifier: @escaping (String) -> String = AccessibilityID.CombatantDetail.talentsNode,
        unlockAccessibilityIdentifier: String = AccessibilityID.CombatantDetail.talentsUnlockButton,
        hapticsEnabled: Bool = false,
        onUnlockTalent: @escaping (TalentNode, TalentTree) -> RosterEditResult,
        onResetTalents: (() -> Bool)? = nil,
    ) {
        self.tree = tree
        self.progression = progression
        self.unlockedTalents = unlockedTalents
        self.allowsEditing = allowsEditing
        self.visibleNodeIDs = visibleNodeIDs
        self.showsReset = showsReset
        self.nodeAccessibilityIdentifier = nodeAccessibilityIdentifier
        self.unlockAccessibilityIdentifier = unlockAccessibilityIdentifier
        self.hapticsEnabled = hapticsEnabled
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
        guard let visibleNodeIDs else { return tree.nodes }
        return tree.nodes.filter { visibleNodeIDs.contains($0.id) }
    }

    public var body: some View {
        GeometryReader { geometry in
            DetailHeroScrollShell(title: tree.name, heroHeightPolicy: .talentTree) { baseHeight in
                DetailHeroHeader(
                    eyebrow: String(localized: L10n.ui_combatanttalentsview_talents_39430),
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
                inspector(maxDetailsHeight: geometry.size.height * 0.4)
            }
        }
        .onChange(of: tree.id) { _, _ in
            selectedNodeID = displayedNodes.first?.id
        }
        .onChange(of: visibleNodeIDs) { _, _ in
            if !displayedNodes.contains(where: { $0.id == selectedNodeID }) {
                selectedNodeID = displayedNodes.first?.id
            }
        }
        .animation(TrinketMotion.Interaction.selection, value: selectedNodeID)
        .animation(TrinketMotion.Interaction.selection, value: unlockedTalents)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: hapticsEnabled,
        )
        .trinketSensoryFeedback(
            .success,
            trigger: unlockSuccessTrigger,
            enabled: hapticsEnabled,
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if showsReset, allowsEditing, hasTreeUnlocks, let onResetTalents {
                    Button {
                        _ = onResetTalents()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .trinketTypography(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(TrinketDesign.Colors.accent)
                    .accessibilityLabel(Text(L10n.ui_combatanttalentsview_reset_all_talents_25b6b))
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
            GeometryReader { geometry in
                let container = geometry.size
                let sourceAspect = max(CGFloat(artReference.sourceAspectRatio), 0.001)
                let scale = max(container.width / sourceAspect, container.height)
                let renderedWidth = sourceAspect * scale
                let renderedHeight = scale
                let overflowX = max(renderedWidth - container.width, 0)
                let overflowY = max(renderedHeight - container.height, 0)
                let offsetX = (0.5 - artReference.focalPoint.x) * overflowX
                let offsetY = (0.5 - artReference.focalPoint.y) * overflowY

                PreparedArtworkImage(artReference, displaySize: .full)
                    .scaledToFill()
                    .frame(width: container.width, height: container.height)
                    .offset(x: offsetX, y: offsetY)
                    .decorativePreparedArtwork()
            }
            .clipped()
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

    private func canUnlock(_ node: TalentNode) -> Bool {
        allowsEditing && tree.canUnlock(
            node: node,
            unlockedNodeIDs: unlockedTalents,
            availablePoints: availablePoints,
        )
    }

    private func nextUnlockableNodeID(after nodeID: String) -> String? {
        guard allowsEditing else { return nil }
        guard let currentIndex = displayedNodes.firstIndex(where: { $0.id == nodeID }) else { return nil }
        // The parent-driven unlockedTalents is still stale at tap time, so assume
        // the just-unlocked node when scoring later candidates and row gates.
        let updatedUnlocks = unlockedTalents.union([nodeID])
        let remainingPoints = progression.availableTalentPoints(unlockedCount: updatedUnlocks.count)
        guard remainingPoints > 0 else { return nil }
        let downstream = displayedNodes.dropFirst(currentIndex + 1)
        if let next = downstream.first(where: {
            tree.canUnlock(node: $0, unlockedNodeIDs: updatedUnlocks, availablePoints: remainingPoints)
        }) {
            return next.id
        }
        let upstream = displayedNodes.prefix(currentIndex)
        return upstream.first(where: {
            tree.canUnlock(node: $0, unlockedNodeIDs: updatedUnlocks, availablePoints: remainingPoints)
        })?.id
    }

    private func talentNodeCard(node: TalentNode, isRowLocked: Bool) -> some View {
        let isUnlocked = unlockedTalents.contains(node.id)
        let isSelected = selectedNodeID == node.id
        let outlineOpacity = canUnlock(node) ? 0.6 : (isUnlocked ? 0.4 : 0)
        let style = node.keyword.visualStyle
        var name = node.nameResource
        name.locale = locale
        return Button {
            guard selectedNodeID != node.id else { return }
            selectedNodeID = node.id
            selectionFeedbackTrigger &+= 1
        } label: {
            VStack(spacing: TrinketDesign.Spacing.small) {
                TalentNodeIcon(node: node, isUnlocked: isUnlocked, isRowLocked: isRowLocked)

                GameLabel(name, balanced: true)
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
                        isSelected ? .clear : style.color.opacity(outlineOpacity),
                        lineWidth: 1,
                    ),
            )
            .shineBorder(
                isSelected ? .keywords(referencedKeywords(for: node)) : .none,
                cornerRadius: TrinketDesign.Corners.card,
                lineWidth: 2,
            )
            .shadow(
                color: isSelected ? style.glowColor.opacity(0.4) : .clear,
                radius: 8,
            )
            .overlay { unlockAccent(for: node) }
        }
        .trinketArtworkCardButtonStyle(pressedScale: TrinketMotion.Interaction.choiceCardPressedScale)
        .accessibilityIdentifier(nodeAccessibilityIdentifier(node.id))
        .accessibilityLabel(isRowLocked
            ? Text(L10n.ui_combatanttalentsview_1_locked_1871c(name))
            : Text(name))
    }

    private func unlockAccent(for node: TalentNode) -> some View {
        TrinketDesign.cardShape
            .strokeBorder(node.keyword.visualStyle.color, lineWidth: 2)
            .keyframeAnimator(initialValue: 0.0, trigger: unlockSuccessTrigger) { content, opacity in
                content.opacity(confirmedNodeID == node.id ? opacity : 0)
            } keyframes: { _ in
                LinearKeyframe(0.9, duration: 0.08)
                CubicKeyframe(0, duration: TrinketMotion.Interaction.confirmationDuration)
            }
    }

    private func referencedKeywords(for node: TalentNode) -> [Keyword] {
        var keywords = [node.keyword]
        for referenced in Keyword.referenced(in: node.description) where !keywords.contains(referenced) {
            keywords.append(referenced)
        }
        return keywords
    }

    @ViewBuilder
    private func unlockButton(for node: TalentNode, isUnlocked: Bool, canUnlock: Bool) -> some View {
        let title = buttonLabel(for: node, isUnlocked: isUnlocked, canUnlock: canUnlock)
        if canUnlock {
            Button(title) {
                let result = onUnlockTalent(node, tree)
                switch result {
                case .committed:
                    confirmedNodeID = node.id
                    unlockSuccessTrigger &+= 1
                    if let nextID = nextUnlockableNodeID(after: node.id) {
                        selectedNodeID = nextID
                        selectionFeedbackTrigger &+= 1
                    }
                case .persistenceFailed:
                    break
                case .unavailable:
                    break
                }
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
            return String(localized: L10n.ui_combatanttalentsview_unlocked_531c7)
        }
        if !allowsEditing {
            return String(localized: L10n.ui_combatanttalentsview_locked_a424e)
        }
        if canUnlock {
            return String(localized: L10n.ui_combatanttalentsview_unlock_talent_55a83)
        }
        if node.row > 1, !tree.isRowComplete(node.row - 1, unlockedNodeIDs: unlockedTalents) {
            return String(localized: L10n.ui_combatanttalentsview_complete_row_1_to_unlock_ab66a("\(node.row - 1)"))
        }
        if availablePoints == 0 {
            return String(localized: L10n.ui_combatanttalentsview_no_points_available_9bf52)
        }
        return String(localized: L10n.ui_combatanttalentsview_locked_a424e)
    }
}

private extension CombatantTalentsView {
    func inspector(maxDetailsHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            ViewThatFits(in: .vertical) {
                inspectorDetails
                    .fixedSize(horizontal: false, vertical: true)
                ScrollView {
                    inspectorDetails
                }
                .scrollBounceBehavior(.basedOnSize)
                .id(selectedNodeID)
            }
            .frame(maxHeight: maxDetailsHeight)
            .fixedSize(horizontal: false, vertical: true)

            if let selectedNode {
                unlockButton(
                    for: selectedNode,
                    isUnlocked: unlockedTalents.contains(selectedNode.id),
                    canUnlock: canUnlock(selectedNode),
                )
                .trinketSheetChromeIgnoresDismissDrag()
            }
        }
        .padding(TrinketDesign.Layout.contentMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .trinketMaterial(.bottomBar)
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.bottom, TrinketDesign.Spacing.medium)
    }

    var inspectorDetails: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            if let selectedNode {
                let style = selectedNode.keyword.visualStyle
                let icon = selectedNode.iconID.map(GameIcon.init(id:)) ?? style.icon

                HStack(spacing: TrinketDesign.Spacing.small) {
                    GameIconImage(icon)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(style.color)
                        .accessibilityHidden(true)

                    GameLabel(selectedNode.nameResource, balanced: true)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(style.color)
                        .trinketFittedText()
                }
                .id(selectedNode.id)
                .transition(.opacity)

                KeywordDescriptionText(text: selectedNode.description)
                    .trinketTypography(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(selectedNode.id)
                    .transition(.opacity)
            }
        }
    }
}

private struct TalentNodeIcon: View {
    let node: TalentNode
    let isUnlocked: Bool
    let isRowLocked: Bool

    var body: some View {
        let style = node.keyword.visualStyle
        let icon = node.iconID.map(GameIcon.init(id:)) ?? style.icon
        if isUnlocked {
            GameIconImage(icon)
                .trinketTypography(.screenTitle)
                .foregroundStyle(style.color)
                .accessibilityHidden(true)
        } else if isRowLocked {
            Image(systemName: "lock.fill")
                .trinketTypography(.sectionTitle)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        } else {
            GameIconImage(icon)
                .trinketTypography(.screenTitle)
                .foregroundStyle(style.color.opacity(0.75))
                .accessibilityHidden(true)
        }
    }
}
