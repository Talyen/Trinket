import TrinketCore

extension UniqueCatalog {
    static func unique(
        id: String,
        name: String,
        base: String,
        keywords: Set<Keyword>,
        description: String,
        triggers: CombatTraitTriggers,
        supports: [String],
        pinned: Set<String> = [],
    ) -> UniqueItemDefinition {
        guard let baseType = GameContent.itemBaseType(matching: base) else {
            preconditionFailure("Missing Unique item base: \(base)")
        }
        let power = ItemAffixPower(description: description, modifiers: [], triggers: triggers)
        let signature = ItemAffixDefinition(
            id: id,
            title: name,
            slot: baseType.slot,
            keywords: keywords,
            weight: 0,
            basic: power,
            astral: power,
        )
        let supporting: [UniqueAffixSource] = supports.map { supportID in
            guard pinned.contains(supportID) else { return .catalog(id: supportID) }
            guard let definition = ItemAffixCatalog.definitions.first(where: { $0.id == supportID }) else {
                preconditionFailure("Missing Unique supporting affix: \(supportID)")
            }
            return .bespoke(ItemAffixDefinition(
                id: "\(id)_\(supportID)_pinned",
                title: definition.title,
                slot: baseType.slot,
                keywords: supportID == "manabound" ? [.mana] : definition.keywords,
                weight: 0,
                basic: definition.astral,
                astral: definition.astral,
            ))
        }
        return UniqueItemDefinition(
            id: id,
            displayName: name,
            baseTypeID: base,
            affixes: [.bespoke(signature)] + supporting,
        )
    }
}
