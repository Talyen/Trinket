import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

/// Expanded detail embedded in the active Campaign stage row.
struct CurrentStageCard: View {
    @Environment(AppState.self) private var appState

    let stage: Stage
    let namespace: Namespace.ID
    let onEnemyTap: () -> Void
    let onPrimaryAction: () -> Void

    @State private var actionFeedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            identity

            if stage.rewards.hasRewards {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rewards")
                        .trinketTypography(.sectionDisplay)

                    StageRewardsView(stage: stage)
                        .accessibilityIdentifier(AccessibilityID.Play.stageRewards)
                }
            }

            if stage.encounter.battleEnemyID != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Party")
                        .trinketTypography(.sectionDisplay)

                    BattlePartyInlinePicker(accentColor: stage.encounter.mapTint)
                }
            }

            Button {
                actionFeedbackTrigger += 1
                onPrimaryAction()
            } label: {
                Label(stage.encounter.primaryActionTitle, systemImage: stage.encounter.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton()
            .tint(stage.encounter.mapTint)
            .accessibilityIdentifier(StageMapID.stageNode(for: stage))
            .accessibilityLabel("\(stage.mapLabel), \(stage.encounter.primaryActionTitle)")
            .trinketSensoryFeedback(
                .selection,
                trigger: actionFeedbackTrigger,
                enabled: appState.options.hapticsEnabled
            )
        }
        .padding(14)
        .trinketSurface(.card)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .strokeBorder(stage.encounter.mapTint.opacity(0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Play.activeStageDetail)
    }

    private var identity: some View {
        HStack(alignment: .top, spacing: 12) {
            activeArtwork
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.compact, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(stage.encounterSubjectName)
                    .trinketTypography(.sectionDisplay)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .matchedGeometryEffect(id: "\(stage.id)-title", in: namespace)

                HStack(spacing: 5) {
                    Text(stage.mapLabel)
                    Text("·")
                    Text(stage.encounterTypeTitle)
                        .foregroundStyle(stage.encounter.mapTint)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

                Text(stage.flavorText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var activeArtwork: some View {
        Group {
            if stage.encounter.battleEnemyID != nil {
                Button(action: onEnemyTap) {
                    EncounterArtwork(stage: stage)
                }
                // UIStyleCheck: allow - Encounter artwork is the enemy-detail affordance.
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(stage.mapLabel) Enemy Art")
                .accessibilityLabel("\(stage.mapLabel), \(stage.encounterSubjectName) details")
            } else {
                EncounterArtwork(stage: stage)
                    .accessibilityIdentifier(
                        stage.recruitCombatant == nil
                            ? "\(stage.mapLabel) Encounter Art"
                            : "\(stage.mapLabel) Recruit Art"
                    )
            }
        }
        .matchedGeometryEffect(id: "\(stage.id)-art", in: namespace)
    }
}

private struct StageRewardsView: View {
    let stage: Stage

    private var entries: [StageRewardEntry] {
        var result: [StageRewardEntry] = []

        if stage.rewards.gold > 0 {
            result.append(.resource(.gold, quantity: stage.rewards.gold))
        }

        result += stage.rewards.itemTemplateIDs.map { templateID in
            let item = GameContent.itemTemplate(matching: templateID)
            return StageRewardEntry(
                id: "item-\(templateID)",
                imageName: item?.artReference?.imageName,
                fallbackSymbol: item?.baseType.slot.symbolName ?? "shippingbox.fill",
                tint: .secondary,
                value: "1",
                accessibilityLabel: item?.displayName ?? "Item"
            )
        }

        result += stage.rewards.materialRewards.map {
            .resource($0.resource, quantity: $0.quantity)
        }

        return result
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 68, maximum: 96), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            rewardChips
        }
        .accessibilityElement(children: .contain)
    }

    private var rewardChips: some View {
        ForEach(entries) { entry in
            HStack(spacing: 6) {
                if let imageName = entry.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: entry.fallbackSymbol)
                        .foregroundStyle(entry.tint)
                        .accessibilityHidden(true)
                }

                Text(entry.value)
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .trinketGlassChip(.compact)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.accessibilityLabel), \(entry.value)")
        }
    }
}

private struct StageRewardEntry: Identifiable {
    let id: String
    let imageName: String?
    let fallbackSymbol: String
    let tint: Color
    let value: String
    let accessibilityLabel: String

    static func resource(_ resource: HomesteadResource, quantity: Int) -> StageRewardEntry {
        let art = ArtCatalog.resourceArtByID[resource.rawValue]
        return StageRewardEntry(
            id: "resource-\(resource.rawValue)",
            imageName: art?.imageName,
            fallbackSymbol: resource.symbolName,
            tint: resource.tint,
            value: quantity.formatted(),
            accessibilityLabel: resource.displayName
        )
    }
}
