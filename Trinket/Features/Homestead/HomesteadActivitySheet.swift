import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct TransmutationSelection {
    var source: HomesteadResource = .wood
    var destination: HomesteadResource = .stone
    var quantity = 1
}

struct HomesteadActivitySheet: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss
    let buildingID: HomesteadNodeID
    @Binding var transmutation: TransmutationSelection

    var body: some View {
        NavigationStack {
            Group {
                switch buildingID {
                case .transmutationCrucible: CrucibleTransmuteView(selection: $transmutation)
                case .runesmithWorkshop: RunesmithInventoryView()
                case .wishingWell: WishingWellView()
                default: EmptyView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(TrinketDesign.Colors.accent)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .trinketSheetSurface()
        .onChange(of: playerSave.sessionGeneration) { _, _ in dismiss() }
    }
}

struct CrucibleTransmuteView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Binding var selection: TransmutationSelection
    @State private var isPending = false
    @State private var received: ResourceAmount?
    @State private var successCount = 0
    @State private var isVisible = false

    private var canApply: Bool {
        ResourceTransmutation.canApply(
            from: selection.source,
            to: selection.destination,
            quantity: selection.quantity,
            homestead: playerSave.homestead,
            gold: playerSave.roster.gold,
        )
    }

    var body: some View {
        Form {
            Section {
                Text(L10n.homestead_transmute_help)
            }
            Section {
                Picker(selection: $selection.source) {
                    ForEach(HomesteadResource.allCases) { resource in
                        GameLabel(resource.displayName).tag(resource)
                    }
                } label: { Text(L10n.homestead_from) }
                Picker(selection: $selection.destination) {
                    ForEach(HomesteadResource.allCases.filter { $0 != selection.source }) { resource in
                        GameLabel(resource.displayName).tag(resource)
                    }
                } label: { Text(L10n.homestead_to) }
                Text(L10n.homestead_amount)
                Picker(selection: $selection.quantity) {
                    Text("1").tag(1)
                    Text("10").tag(10)
                } label: { Text(L10n.homestead_amount) }
                    .pickerStyle(.segmented)
            }
            Section {
                HomesteadMaterialValue(
                    resource: selection.source,
                    value: selection.quantity.formatted(),
                    isInsufficient: playerSave.homestead
                        .balance(for: selection.source, gold: playerSave.roster.gold) < selection.quantity,
                )
            } header: { Text(L10n.homestead_spend) }
            Section {
                HomesteadMaterialValue(resource: selection.destination, value: selection.quantity.formatted())
            } header: { Text(L10n.homestead_receive) }
            Section {
                Button(action: transmute) {
                    HStack {
                        if isPending {
                            ProgressView()
                        }
                        Text(L10n.homestead_transmute)
                    }.frame(maxWidth: .infinity)
                }
                .disabled(!canApply || isPending)
                .accessibilityIdentifier(AccessibilityID.Homestead.transmute)
                if let received {
                    let name = LocalizedGameText(ContentCopy.resource(received.resource.displayName), locale: locale).text
                    Text(L10n.homestead_received(received.quantity, name))
                }
            }
        }
        .navigationTitle(String(localized: L10n.homestead_transmute))
        .disabled(isPending)
        .onChange(of: selection.source) { _, source in
            if selection.destination == source {
                selection.destination = HomesteadResource.allCases.first { $0 != source } ?? .stone
            }
            received = nil
        }
        .onChange(of: selection.destination) { _, _ in received = nil }
        .onChange(of: selection.quantity) { _, _ in received = nil }
        .trinketSensoryFeedback(.success, trigger: successCount, enabled: options.hapticsEnabled)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private func transmute() {
        guard !isPending, canApply else { return }
        isPending = true
        received = nil
        let intent = selection
        let generation = playerSave.sessionGeneration
        Task {
            let result = await playerSave.transmuteResource(from: intent.source, to: intent.destination, quantity: intent.quantity)
            isPending = false
            guard generation == playerSave.sessionGeneration, isVisible, scenePhase == .active else { return }
            if case let .success(amount) = result {
                received = amount
                successCount += 1
            }
        }
    }
}

struct HomesteadActivityEntry: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    let nodeID: HomesteadNodeID
    let isBuilt: Bool
    let onOpen: () -> Void

    private var activityIconName: String {
        switch nodeID {
        case .transmutationCrucible: "arrow.left.arrow.right"
        case .runesmithWorkshop: "wand.and.stars"
        default: "water.waves"
        }
    }

    private var activityTitle: LocalizedStringResource {
        switch nodeID {
        case .transmutationCrucible:
            L10n.homestead_transmute
        case .runesmithWorkshop:
            L10n.homestead_inscribe
        default:
            playerSave.homestead.wishedTemplateID == nil ? L10n.homestead_make_wish : L10n.homestead_change_wish
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            Button(action: onOpen) {
                HStack {
                    Image(systemName: activityIconName)
                        .frame(width: 36, height: 36).accessibilityHidden(true)
                    Text(activityTitle)
                    Spacer()
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .trinketTypography(.rowTitle)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isBuilt)
            .accessibilityIdentifier(AccessibilityID.Homestead.activity(nodeID.rawValue))
        }
        .padding(TrinketDesign.Spacing.large)
        .trinketMaterial(.frostedPanel, cornerRadius: TrinketDesign.Corners.card)
    }
}
