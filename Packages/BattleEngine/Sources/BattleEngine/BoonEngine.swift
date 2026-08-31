import TrinketContent
import TrinketCore

public enum BoonEngine {
    private static let seedSalt: UInt64 = 0xB00A_75C0_50D2_25E1
    static let maxRecursionDepth = 8

    static func makeRNG(seed: UInt64) -> SeededRandomNumberGenerator {
        SeededRandomNumberGenerator(seed: seed ^ seedSalt)
    }

    static func makeRNG(forking rng: SeededRandomNumberGenerator) -> SeededRandomNumberGenerator {
        var copy = rng
        let forkSeed = copy.next()
        return SeededRandomNumberGenerator(seed: forkSeed ^ seedSalt ^ 0x9E37_79B9_7F4A_7C15)
    }

    static func isEligible(_ boon: BoonDefinition, affinities: Set<Keyword>) -> Bool {
        Set(boon.category.keywords).isSubset(of: affinities)
    }

    static func makeOffer(in context: inout BattleState) -> BoonOffer? {
        let affinities = partyAffinities(in: context)
        let selected = Set(context.activeBoons.map(\.id))
        let unselected = BoonCatalog.all.filter { !selected.contains($0.id) }
        let strictEligible = unselected.filter { Set($0.category.keywords).isSubset(of: affinities) }
        let relaxedEligible = unselected.filter { !Set($0.category.keywords).isDisjoint(with: affinities) }
        var eligible: [BoonDefinition]
        if strictEligible.count >= 3 {
            eligible = strictEligible
        } else if relaxedEligible.count >= 3 {
            eligible = relaxedEligible
        } else if unselected.count >= 3 {
            eligible = unselected
        } else {
            return nil
        }

        eligible.shuffle(using: &context.boonRNG)
        var picked: [BoonDefinition] = []
        while picked.count < 3, !eligible.isEmpty {
            guard let next = eligible.first(where: { candidate in
                !picked.contains(where: { $0.category.id == candidate.category.id })
            }) ?? eligible.first else { break }
            picked.append(next)
            eligible.removeAll(where: { $0.id == next.id })
        }

        guard picked.count == 3 else { return nil }

        var unavailableArtwork = context.usedBoonArtworkNames
        var choices: [BoonChoice] = []
        for boon in picked {
            let ch = choice(for: boon, unavailableArtwork: unavailableArtwork, in: &context)
            if let artworkName = ch.artworkName {
                unavailableArtwork.insert(artworkName)
            }
            choices.append(ch)
        }
        context.usedBoonArtworkNames.formUnion(choices.compactMap(\.artworkName))
        return BoonOffer(choices: choices)
    }

    static func select(_ boonID: String, in context: inout BattleState) -> Bool {
        guard let offer = context.pendingBoonOffer,
              let choice = offer.choices.first(where: { $0.id == boonID })
        else { return false }
        context.activeBoons.append(ActiveBoon(boon: choice.boon))
        context.pendingBoonOffer = nil
        return true
    }

    static func partyAffinities(in context: BattleState) -> Set<Keyword> {
        Set((context.hero.abilityLoadout.abilities + context.companion.abilityLoadout.abilities).flatMap(\.keywords))
    }

    public static func autoSelectedChoiceID(for offer: BoonOffer, in context: BattleState) -> String? {
        let affinityCounts = Dictionary(
            grouping: (context.hero.abilityLoadout.abilities + context.companion.abilityLoadout.abilities).flatMap(\.keywords),
            by: { $0 },
        ).mapValues(\.count)
        return offer.choices.max { lhs, rhs in
            let left = lhs.boon.category.keywords.reduce(0) { $0 + affinityCounts[$1, default: 0] }
            let right = rhs.boon.category.keywords.reduce(0) { $0 + affinityCounts[$1, default: 0] }
            if left != right {
                return left < right
            }
            return lhs.id > rhs.id
        }?.id
    }

    private static let artworkByKeywordOverlap: [(name: String, keywords: Set<Keyword>)] = {
        var seen = Set<String>()
        var list: [(name: String, keywords: Set<Keyword>)] = []
        for ability in AbilityCatalog.all.sorted(by: { ($0.artReference?.imageName ?? "") < ($1.artReference?.imageName ?? "") }) {
            guard let name = ability.artReference?.imageName, seen.insert(name).inserted else { continue }
            list.append((name, Set(ability.keywords)))
        }
        return list
    }()

    private static func choice(
        for boon: BoonDefinition,
        unavailableArtwork: Set<String>,
        in context: inout BattleState,
    ) -> BoonChoice {
        let categoryKeywords = Set(boon.category.keywords)
        var candidates: [(name: String, overlap: Int)] = artworkByKeywordOverlap.compactMap { entry in
            let overlap = categoryKeywords.intersection(entry.keywords).count
            guard overlap > 0 else { return nil }
            return (entry.name, overlap)
        }
        if candidates.isEmpty {
            candidates = artworkByKeywordOverlap.map { ($0.name, 0) }
        }
        let available = candidates.filter { !unavailableArtwork.contains($0.name) }
        let source = available.isEmpty ? candidates : available
        let bestOverlap = source.map(\.overlap).max() ?? 0
        var best = source.filter { $0.overlap == bestOverlap }.map(\.name).sorted()
        let artworkName: String?
        if best.isEmpty {
            artworkName = nil
        } else {
            best.shuffle(using: &context.boonRNG)
            artworkName = best.first
        }
        return BoonChoice(boon: boon, artworkName: artworkName)
    }
}

public extension BattleState {
    var hasPendingBoonOffer: Bool {
        pendingBoonOffer != nil
    }

    @discardableResult
    mutating func selectBoon(id: String) -> Bool {
        let selected = BoonEngine.select(id, in: &self)
        guard selected else { return false }
        finishBoonSelection()
        return true
    }

    private mutating func finishBoonSelection() {
        if tracksLog {
            syncLog()
        }
    }
}
