import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct CombatantDetailPane: View {
    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState
    let allowsEditing: Bool
    var battleHealth: Int?
    var activeEffectSummaries: [EffectSummary] = []
    var hidesNavigationBar = false

    /// Sub-picker navigation state — owned here at the pane level so the
    /// navigationDestination modifiers are at the root of whatever NavigationStack
    /// is presenting this view. No nested UISheetPresentationControllers.
    @State private var selectedItemSlot: ItemSlot?
    @State private var selectedAbilityTier: AbilityTier?
    @State private var headerBaseHeight: CGFloat = 300
    @State private var heroOverscroll: CGFloat = 0
    @State private var titleOpacity: CGFloat = 0

    private var combatBuild: CombatBuild {
        CombatBuildResolver.build(
            combatant: combatant,
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryState.items
        )
    }

    private var heroOrPetTrait: CombatantTraitDefinition? {
        GameContent.trait(forCombatantID: combatant.id)
    }

    private var enemyTraits: [CombatantTraitDefinition] {
        guard combatant.role == .enemy,
              let enemy = GameContent.enemy(matching: combatant.id)
        else { return [] }
        return GameContent.traits(for: enemy)
    }

    private var effectiveCombatant: Combatant {
        combatBuild.combatant
    }

    var body: some View {
        navigationBarConfigured {
            ScrollView {
                VStack(spacing: 0) {
                    CombatantHeroHeader(
                        combatant: combatant,
                        progression: progression,
                        baseHeight: headerBaseHeight,
                        overscroll: heroOverscroll
                    )
                    .accessibilityIdentifier("\(combatant.name) detail hero header")

                    VStack(alignment: .leading, spacing: 0) {
                        section("Stats", sectionID: AccessibilityID.CombatantDetail.statsSection) {
                            statRow(
                                "Health",
                                value: "\(currentHealth)/\(combatBuild.effectiveMaxHealth)",
                                accessibilityIdentifier: AccessibilityID.CombatantDetail.healthStat
                            )
                            if combatBuild.effectiveMaxMana > 0 {
                                statRow("Mana", value: "\(combatBuild.effectiveMaxMana) MP")
                            }
                            statRow("Strength", value: "\(effectiveCombatant.primaryStats.strength)")
                            statRow("Agility", value: "\(effectiveCombatant.primaryStats.agility)")
                            statRow("Toughness", value: "\(effectiveCombatant.primaryStats.toughness)")
                            statRow("Intellect", value: "\(effectiveCombatant.primaryStats.intellect)")
                            statRow("Wisdom", value: "\(effectiveCombatant.primaryStats.wisdom)")
                        }

                        if let heroOrPetTrait {
                            traitSection(
                                title: "Trait",
                                traits: [heroOrPetTrait],
                                sectionID: AccessibilityID.CombatantDetail.traitSection,
                                descriptionID: AccessibilityID.CombatantDetail.traitDescription
                            )
                        }

                        if !enemyTraits.isEmpty {
                            traitSection(
                                title: "Traits",
                                traits: enemyTraits,
                                sectionID: AccessibilityID.CombatantDetail.enemyTraitsSection,
                                descriptionID: AccessibilityID.CombatantDetail.enemyTraitDescription
                            )
                        }

                        if !activeEffectSummaries.isEmpty {
                            section("Active Effects") {
                                ForEach(activeEffectSummaries) { summary in
                                    KeywordDescriptionText(text: summary.text)
                                        .font(.subheadline)
                                        .accessibilityElement(children: .combine)
                                }
                            }
                        }

                        section("Abilities") {
                            AbilitySummaryGrid(
                                combatant: combatant,
                                progression: progression,
                                loadout: $loadout,
                                allowsEditing: allowsEditing,
                                onSelectTier: allowsEditing ? { selectedAbilityTier = $0 } : nil
                            )
                            .padding(.vertical, 4)
                        }

                        section("Items") {
                            EquipmentSlotSummaryGrid(
                                role: combatant.role,
                                equipmentLoadout: equipmentLoadout,
                                inventoryState: inventoryState,
                                onSelect: allowsEditing ? { selectedItemSlot = $0 } : nil
                            )
                            .padding(.vertical, 4)
                        }
                    }
                    .trinketScreenBackground(.collection)
                }
            }
            .ignoresSafeArea(edges: .top)
            .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
                let topInset = geometry.contentInsets.top
                return ScrollMetrics(
                    containerWidth: geometry.containerSize.width,
                    offsetY: geometry.contentOffset.y + topInset,
                    topInset: topInset,
                    overscroll: HeroHeaderLayout.overscroll(
                        contentOffsetY: geometry.contentOffset.y,
                        topInset: topInset
                    )
                )
            } action: { _, metrics in
                headerBaseHeight = HeroHeaderLayout.headerHeight(forWidth: metrics.containerWidth)
                heroOverscroll = metrics.overscroll
                let threshold = headerBaseHeight - metrics.topInset - 44
                titleOpacity = min(max((metrics.offsetY - threshold) / 20, 0), 1)
            }
            // Sub-picker navigation — declared here so they land at the root of whichever
            // NavigationStack contains this pane (the sheet's own stack for Collection,
            // or the tab stack for Search). This keeps all presentation at the stack root.
            .navigationDestination(item: $selectedItemSlot) { slot in
                ItemSlotPickerView(
                    slot: slot,
                    equipmentLoadout: $equipmentLoadout,
                    inventoryState: $inventoryState
                )
            }
            .navigationDestination(item: $selectedAbilityTier) { tier in
                AbilityTierPickerSheet(
                    combatant: combatant,
                    tier: tier,
                    loadout: $loadout
                )
            }
        }
    }

    @ViewBuilder
    private func navigationBarConfigured<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if hidesNavigationBar {
            content()
                .toolbar(.hidden, for: .navigationBar)
        } else {
            content()
                .navigationTitle(combatant.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.clear, for: .navigationBar)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(combatant.name)
                            .font(.headline)
                            .opacity(titleOpacity)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
        }
    }

    private func traitSection(
        title: String,
        traits: [CombatantTraitDefinition],
        sectionID: String,
        descriptionID: String
    ) -> some View {
        section(title, sectionID: sectionID) {
            ForEach(traits) { trait in
                VStack(alignment: .leading, spacing: 4) {
                    Text(trait.name)
                        .font(.body.weight(.semibold))
                    KeywordDescriptionText(text: trait.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(descriptionID)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, sectionID: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.top, TrinketDesign.Metrics.contentTopPadding)
                .accessibilityIdentifier(sectionID ?? title)

            content()
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        }
    }

    private var currentHealth: Int {
        battleHealth ?? combatBuild.effectiveMaxHealth
    }

    private func statRow(_ title: String, value: String, accessibilityIdentifier: String? = nil) -> some View {
        LabeledContent {
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        } label: {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }

    private struct ScrollMetrics: Equatable {
        var containerWidth: CGFloat
        var offsetY: CGFloat
        var topInset: CGFloat
        var overscroll: CGFloat
    }
}

extension CombatantDetailPane {
    init(
        snapshot: CombatantCardDetail,
        hidesNavigationBar: Bool = false
    ) {
        self.init(
            combatant: snapshot.combatant,
            progression: snapshot.progression,
            loadout: .constant(snapshot.combatant.abilityLoadout),
            equipmentLoadout: .constant(snapshot.equipmentLoadout),
            inventoryState: .constant(snapshot.inventoryState),
            allowsEditing: false,
            battleHealth: snapshot.health,
            activeEffectSummaries: snapshot.activeEffectSummaries,
            hidesNavigationBar: hidesNavigationBar
        )
    }
}
