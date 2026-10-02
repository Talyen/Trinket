import BattleEngine

public struct BalanceBattleRecord: Equatable, Codable, Sendable {
    public var tier: SimulationPowerTier
    public var heroID: String
    public var companionID: String
    public var enemyID: String
    public var isBoss: Bool
    public var heroAbilityIDs: [String]
    public var companionAbilityIDs: [String]
    public var enemyAbilityIDs: [String]
    public var enemyTraitIDs: [String]
    public var affixIDs: [String]
    public var heroAffixIDs: [String]
    public var companionAffixIDs: [String]
    public var heroItemBaseIDs: [String]
    public var companionItemBaseIDs: [String]
    public var heroTalentIDs: [String]
    public var companionTalentIDs: [String]
    public var seed: UInt64
    public var policyID: String
    public var result: BattleSimResult

    public init(
        tier: SimulationPowerTier,
        heroID: String,
        companionID: String,
        enemyID: String,
        isBoss: Bool,
        heroAbilityIDs: [String],
        companionAbilityIDs: [String],
        enemyAbilityIDs: [String],
        enemyTraitIDs: [String],
        affixIDs: [String],
        heroAffixIDs: [String] = [],
        companionAffixIDs: [String] = [],
        heroItemBaseIDs: [String] = [],
        companionItemBaseIDs: [String] = [],
        heroTalentIDs: [String],
        companionTalentIDs: [String],
        seed: UInt64,
        policyID: String,
        result: BattleSimResult,
    ) {
        self.tier = tier
        self.heroID = heroID
        self.companionID = companionID
        self.enemyID = enemyID
        self.isBoss = isBoss
        self.heroAbilityIDs = heroAbilityIDs
        self.companionAbilityIDs = companionAbilityIDs
        self.enemyAbilityIDs = enemyAbilityIDs
        self.enemyTraitIDs = enemyTraitIDs
        self.affixIDs = affixIDs
        self.heroAffixIDs = heroAffixIDs
        self.companionAffixIDs = companionAffixIDs
        self.heroItemBaseIDs = heroItemBaseIDs
        self.companionItemBaseIDs = companionItemBaseIDs
        self.heroTalentIDs = heroTalentIDs
        self.companionTalentIDs = companionTalentIDs
        self.seed = seed
        self.policyID = policyID
        self.result = result
    }

    private enum CodingKeys: String, CodingKey {
        case tier
        case heroID
        case companionID
        case enemyID
        case isBoss
        case heroAbilityIDs
        case companionAbilityIDs
        case enemyAbilityIDs
        case enemyTraitIDs
        case affixIDs
        case heroAffixIDs
        case companionAffixIDs
        case heroItemBaseIDs
        case companionItemBaseIDs
        case heroTalentIDs
        case companionTalentIDs
        case seed
        case policyID
        case result
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case enemyTraitID
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tier = try values.decode(SimulationPowerTier.self, forKey: .tier)
        heroID = try values.decode(String.self, forKey: .heroID)
        companionID = try values.decode(String.self, forKey: .companionID)
        enemyID = try values.decode(String.self, forKey: .enemyID)
        isBoss = try values.decode(Bool.self, forKey: .isBoss)
        heroAbilityIDs = try values.decode([String].self, forKey: .heroAbilityIDs)
        companionAbilityIDs = try values.decode([String].self, forKey: .companionAbilityIDs)
        enemyAbilityIDs = try values.decode([String].self, forKey: .enemyAbilityIDs)
        if let ids = try values.decodeIfPresent([String].self, forKey: .enemyTraitIDs) {
            enemyTraitIDs = ids
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let id = try legacy.decode(String.self, forKey: .enemyTraitID)
            enemyTraitIDs = id.isEmpty ? [] : [id]
        }
        affixIDs = try values.decode([String].self, forKey: .affixIDs)
        heroAffixIDs = try values.decode([String].self, forKey: .heroAffixIDs)
        companionAffixIDs = try values.decode([String].self, forKey: .companionAffixIDs)
        heroItemBaseIDs = try values.decode([String].self, forKey: .heroItemBaseIDs)
        companionItemBaseIDs = try values.decode([String].self, forKey: .companionItemBaseIDs)
        heroTalentIDs = try values.decode([String].self, forKey: .heroTalentIDs)
        companionTalentIDs = try values.decode([String].self, forKey: .companionTalentIDs)
        seed = try values.decode(UInt64.self, forKey: .seed)
        policyID = try values.decode(String.self, forKey: .policyID)
        result = try values.decode(BattleSimResult.self, forKey: .result)
    }
}
