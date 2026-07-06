import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadNodeDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var buildActions = HomesteadBuildActions()

    let definition: HomesteadNodeDefinition

    private var homestead: PlayerHomesteadState { appState.homestead.current }
    private var roster: PlayerRosterState { appState.roster.current }

    private var status: HomesteadProjectStatus {
        HomesteadProjectStatus(definition: definition, homestead: homestead, roster: roster)
    }

    var body: some View {
        @Bindable var buildActions = buildActions

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HomesteadDetailHeader(definition: definition, status: status)

                if !status.isUnlocked {
                    HomesteadPrerequisiteSection(definition: definition, homestead: homestead)
                }

                HomesteadBonusSection(
                    title: "Current Effect",
                    bonus: currentBonus
                )

                if let nextTier = status.nextTier {
                    HomesteadBonusSection(
                        title: nextTier.tier == 1 ? "Build Effect" : "Next Upgrade",
                        bonus: nextTier.bonus
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Requirements")
                            .font(.headline)
                        HomesteadRequirementList(
                            cost: nextTier.cost,
                            status: status
                        )
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .trinketScreenBackground(.homestead)
        .navigationTitle(definition.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                HomesteadProjectActionFooter(
                    status: status,
                    isBuilding: buildActions.isBuilding,
                    buildButtonAccessibilityID: status.detailBuildButtonAccessibilityID,
                    onBuild: buildOrUpgrade
                )
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .trinketMaterial(.bottomBar, cornerRadius: 0)
        }
        .accessibilityIdentifier(AccessibilityID.Homestead.nodeDetail(title: definition.title))
        .sensoryFeedback(.success, trigger: buildActions.upgradeEventCount)
        .homesteadBuildErrorAlert(error: $buildActions.error)
    }

    private var currentBonus: HomesteadBonus {
        if let tier = definition.tier(status.currentTier) {
            return tier.bonus
        }
        return HomesteadBonus(
            title: "No Active Effect",
            description: "Build this project to enable its first effect."
        )
    }

    private func buildOrUpgrade() {
        buildActions.perform(
            definition,
            homestead: appState.homestead,
            roster: appState.roster
        )
    }
}

struct HomesteadDetailHeader: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HomesteadBuildingArtwork(definition: definition)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .homesteadLockedArtworkStyle(
                    isUnlocked: status.isUnlocked,
                    lockedSaturation: 0.14,
                    lockedOpacity: 0.62
                )
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.58)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }

            VStack(alignment: .leading, spacing: 10) {
                HomesteadStatusBadge(status: status)

                Text(definition.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HomesteadTierSummary(
                    currentTier: status.currentTier,
                    maxTier: definition.maxTier,
                    tint: definition.tint,
                    isUnlocked: status.isUnlocked,
                    labelColor: .white.opacity(0.82)
                )
            }
            .padding(16)
        }
        .trinketCardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(definition.title), tier \(status.currentTier) of \(definition.maxTier), \(status.statusTitle)")
    }
}

struct HomesteadPrerequisiteSection: View {
    let definition: HomesteadNodeDefinition
    let homestead: PlayerHomesteadState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Path")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(definition.prerequisites, id: \.nodeID) { requirement in
                    HStack(spacing: 10) {
                        Image(systemName: isMet(requirement) ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundStyle(isMet(requirement) ? TrinketDesign.Colors.success : .secondary)
                            .frame(width: 22)
                        Text(title(for: requirement.nodeID))
                            .font(.subheadline)
                        Spacer()
                        Text("\(homestead.tier(for: requirement.nodeID)) / \(requirement.minimumTier)")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(isMet(requirement) ? TrinketDesign.Colors.success : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(title(for: requirement.nodeID)), \(homestead.tier(for: requirement.nodeID)) of \(requirement.minimumTier)")
                }
            }
            .trinketSurface(.secondary)
        }
    }

    private func isMet(_ requirement: HomesteadNodeRequirement) -> Bool {
        homestead.tier(for: requirement.nodeID) >= requirement.minimumTier
    }

    private func title(for id: HomesteadNodeID) -> String {
        GameContent.homesteadNode(matching: id)?.title ?? id.rawValue
    }
}

struct HomesteadBonusSection: View {
    let title: String
    let bonus: HomesteadBonus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            HomesteadBonusCopy(bonus: bonus)
                .frame(maxWidth: .infinity, alignment: .leading)
                .trinketSurface(.secondary)
        }
    }
}

struct HomesteadRequirementList: View {
    let cost: [ResourceAmount]
    let status: HomesteadProjectStatus

    var body: some View {
        VStack(spacing: 8) {
            ForEach(cost) { amount in
                let balance = status.balance(for: amount)
                HStack(spacing: 10) {
                    Image(systemName: amount.resource.symbolName)
                        .foregroundStyle(amount.resource.tint)
                        .frame(width: 22)
                    Text(amount.resource.displayName)
                        .font(.subheadline)
                    Spacer()
                    HomesteadRequirementCountText(
                        balance: balance,
                        required: amount.quantity,
                        font: .subheadline.monospacedDigit().weight(.semibold)
                    )
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(amount.resource.displayName), \(balance) available, \(amount.quantity) required")
            }
        }
    }
}

struct HomesteadBuildingArtwork: View {
    let definition: HomesteadNodeDefinition

    var body: some View {
        ZStack {
            if let art = ArtCatalog.backgroundArtByID[definition.id.rawValue] {
                Image(art.imageName)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(art.accessibilityLabel)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                definition.tint.opacity(0.18),
                                Color(.secondarySystemBackground)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: definition.symbolName)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(definition.tint)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("\(definition.title) artwork")
    }
}
