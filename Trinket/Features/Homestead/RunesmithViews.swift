import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct RunesmithInventoryView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            let items = playerSave.inventory.items.filter(ItemInscriptionPlan.isEligible)
            if items.isEmpty {
                Text(L10n.homestead_no_inscription_items)
            }
            ForEach(items) { item in
                NavigationLink {
                    RunesmithEditorView(itemID: item.id)
                } label: {
                    HStack {
                        ItemArtwork(item: item, variant: .thumbnail).frame(width: 48, height: 64).clipped().accessibilityHidden(true)
                        ItemCardLabel(item: item, showsAffixCount: true)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Homestead.inscriptionItem(item.id))
            }
        }
        .navigationTitle(String(localized: L10n.homestead_inscribe))
    }
}

private struct RunesmithEditorView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    let itemID: String
    @State private var chosenIndex: Int?
    @State private var selectedAffixID: String?
    @State private var isPending = false
    @State private var result: InventoryItem?
    @State private var successCount = 0
    @State private var isVisible = false

    private var item: InventoryItem? {
        playerSave.inventory.items.first { $0.id == itemID }
    }

    var body: some View {
        Group {
            if let item, ItemInscriptionPlan.isEligible(item) {
                editor(item)
            } else {
                Text(L10n.homestead_no_inscription_items)
            }
        }
        .navigationTitle(String(localized: L10n.homestead_inscribe))
        .navigationBarTitleDisplayMode(.inline)
        .trinketSensoryFeedback(.success, trigger: successCount, enabled: options.hapticsEnabled)
        .onAppear {
            isVisible = true
            if selectedAffixID == nil, let item, let index = item.inscribedAffixIndex {
                selectedAffixID = item.affixes[index].id
            }
        }
        .onDisappear { isVisible = false }
        .onChange(of: selectedAffixID) { _, _ in result = nil }
    }

    private func editor(_ item: InventoryItem) -> some View {
        let index = item.inscribedAffixIndex ?? chosenIndex
        let choices = index.map { ItemInscriptionPlan.choices(for: item, index: $0) } ?? []
        let selected = choices.first { $0.id == selectedAffixID }
        return Form {
            itemSelection(item)
            if let index, item.displayedAffixes.indices.contains(index) {
                Section {
                    GameLabel(item.displayedAffixes[index].description)
                } header: { Text(L10n.homestead_current_affix) }
                Section {
                    Picker(selection: $selectedAffixID) {
                        ForEach(choices) { definition in
                            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                                GameLabel(definition.title)
                                GameLabel(definition.power(for: item.rarity).scaled(by: item.baseType.affixPowerMultiplier).description)
                                    .foregroundStyle(.secondary)
                            }.tag(Optional(definition.id))
                        }
                    } label: { Text(L10n.homestead_new_affix) }
                        .pickerStyle(.navigationLink)
                        .accessibilityIdentifier(AccessibilityID.Homestead.inscribe + " Choice")
                }
                if let selected {
                    bounds(selected, item: item)
                    materialCost(item, index: index, affixID: selected.id)
                }
            }
        }
        .disabled(isPending)
        .safeAreaInset(edge: .bottom) {
            if let result, let position = result.inscribedAffixIndex {
                VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                    Text(L10n.homestead_affix_replaced).trinketTypography(.rowTitle)
                    GameLabel(result.displayedAffixes[position].description)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TrinketDesign.Layout.contentMargin)
                .trinketScreenBackground()
            }
        }
    }

    private func itemSelection(_ item: InventoryItem) -> some View {
        Section {
            Text(item.localizedDisplayName(locale: locale)).trinketTypography(.rowTitle)
            if item.inscribedAffixIndex == nil {
                Text(L10n.homestead_choose_affix)
                Text(L10n.homestead_affix_lock_help).foregroundStyle(.secondary)
                ForEach(Array(item.displayedAffixes.enumerated()), id: \.element.id) { offset, affix in
                    Button {
                        chosenIndex = offset
                        selectedAffixID = affix.id
                        result = nil
                    } label: {
                        HStack {
                            GameLabel(affix.description)
                            Spacer()
                            if chosenIndex == offset {
                                Image(systemName: "checkmark").accessibilityHidden(true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func materialCost(_ item: InventoryItem, index: Int, affixID: String) -> some View {
        Section {
            ForEach(ItemInscriptionPlan.cost(for: item)) { amount in
                HomesteadMaterialValue(
                    resource: amount.resource,
                    value: amount.quantity.formatted(),
                    isInsufficient: playerSave.homestead.balance(
                        for: amount.resource,
                        gold: playerSave.roster.gold,
                    ) < amount.quantity,
                )
            }
            Button { inscribe(index: index, affixID: affixID) } label: {
                HStack {
                    if isPending {
                        ProgressView()
                    }
                    Text(L10n.homestead_inscribe)
                }.frame(maxWidth: .infinity)
            }
            .disabled(isPending || !playerSave.homestead.canAfford(
                cost: ItemInscriptionPlan.cost(for: item),
                gold: playerSave.roster.gold,
            ))
            .accessibilityIdentifier(AccessibilityID.Homestead.inscribe)
        } header: { Text(L10n.homestead_material_cost) }
    }

    private func bounds(_ definition: ItemAffixDefinition, item: InventoryItem) -> some View {
        let power = definition.power(for: item.rarity)
        let randomizes = power.hasRollableMagnitudes
        let low = (randomizes ? power.rolledMin() : power).scaled(by: item.baseType.affixPowerMultiplier)
        let high = (randomizes ? power.rolledMax() : power).scaled(by: item.baseType.affixPowerMultiplier)
        return Section {
            Text(L10n.homestead_roll_help).foregroundStyle(.secondary)
            if low == high {
                GameLabel(low.description)
            } else {
                Text(L10n.homestead_minimum).trinketTypography(.eyebrow)
                GameLabel(low.description)
                Text(L10n.homestead_maximum).trinketTypography(.eyebrow)
                GameLabel(high.description)
            }
        } header: { Text(L10n.homestead_new_affix) }
    }

    private func inscribe(index: Int, affixID: String) {
        guard !isPending else { return }
        isPending = true
        result = nil
        let generation = playerSave.sessionGeneration
        Task {
            let outcome = await playerSave.inscribeItem(itemID: itemID, index: index, affixID: affixID)
            isPending = false
            guard generation == playerSave.sessionGeneration, isVisible, scenePhase == .active else { return }
            if case let .success(item) = outcome {
                result = item
                successCount += 1
            }
        }
    }
}
