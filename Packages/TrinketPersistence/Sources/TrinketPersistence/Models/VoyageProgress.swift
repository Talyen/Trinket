import Foundation
import TrinketContent
import TrinketCore

public struct VoyageRun: Codable, Equatable, Sendable, Identifiable {
    public var id: String {
        offer.id
    }

    public let offer: VoyageOffer
    public var nodes: [VoyageNode]
    public var earnedGold = 0
    public var earnedMaterials: [HomesteadResource: Int] = [:]
    public var isComplete: Bool {
        nodes.allSatisfy(\.isCleared)
    }

    public var nextNode: VoyageNode? {
        nodes.first { !$0.isCleared }
    }

    public init(offer: VoyageOffer, nodes: [VoyageNode]) {
        self.offer = offer
        self.nodes = nodes
    }

    public func node(id: String) -> VoyageNode? {
        nodes.first { $0.id == id }
    }

    public mutating func updateNode(id: String, _ update: (inout VoyageNode) -> Void) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        update(&nodes[index])
    }
}

public struct PlayerVoyageState: Codable, Equatable, Sendable {
    public static let freshStart = Self()
    public private(set) var version = 1
    public private(set) var offers: [VoyageOffer] = []
    public var activeRun: VoyageRun?
    // Optional so existing version-one payloads decode without rewriting their route.
    var completedRunIDs: Set<String>?
    var abandonedRunIDs: Set<String>?
    public private(set) var unreadablePayload: Data?
    public var isUnreadable: Bool {
        unreadablePayload != nil
    }

    public init() {}

    public mutating func ensureBoard(access: ContentAccessPolicy, eligibleModifiers: [RewardModifier] = RewardModifier.allCases) {
        guard !isUnreadable, activeRun == nil else { return }
        var rng = SystemRandomNumberGenerator()
        offers = VoyageBoard.preparedOffers(
            offers, excluding: (completedRunIDs ?? []).union(abandonedRunIDs ?? []),
            access: access, eligibleModifiers: eligibleModifiers, using: &rng,
        )
    }

    public mutating func refresh(access: ContentAccessPolicy, eligibleModifiers: [RewardModifier] = RewardModifier.allCases) {
        guard !isUnreadable, activeRun == nil else { return }
        var rng = SystemRandomNumberGenerator()
        offers = VoyageBoard.refreshedOffers(access: access, eligibleModifiers: eligibleModifiers, using: &rng)
    }

    @discardableResult
    public mutating func embark(
        offerID: String, eligibleRecruitEventIDs: [String], access: ContentAccessPolicy,
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> Bool {
        guard !isUnreadable, activeRun == nil,
              completedRunIDs?.contains(offerID) != true, abandonedRunIDs?.contains(offerID) != true,
              let offer = offers.first(where: { $0.id == offerID }),
              VoyageBoard.chapterIDs(access: access).contains(offer.chapterID) else { return false }
        activeRun = VoyageRun(
            offer: offer,
            nodes: VoyageGenerator.nodes(for: offer, eligibleRecruitEventIDs: eligibleRecruitEventIDs, eligibleRewards: eligibleRewards),
        )
        return true
    }

    public mutating func replaceOffer(
        runID: String, access: ContentAccessPolicy, eligibleModifiers: [RewardModifier] = RewardModifier.allCases,
    ) {
        var rng = SystemRandomNumberGenerator()
        offers = VoyageBoard.replacingOffer(runID, in: offers, access: access, eligibleModifiers: eligibleModifiers, using: &rng)
    }

    @discardableResult
    public mutating func abandon(
        runID: String, access: ContentAccessPolicy, eligibleModifiers: [RewardModifier] = RewardModifier.allCases,
    ) -> Bool {
        guard !isUnreadable, let run = activeRun, run.id == runID, !run.isComplete else { return false }
        abandonedRunIDs = (abandonedRunIDs ?? []).union([runID])
        replaceOffer(runID: runID, access: access, eligibleModifiers: eligibleModifiers)
        activeRun = nil
        return true
    }

    public mutating func dismissCompleted() {
        guard let run = activeRun, run.isComplete else { return }
        completedRunIDs = (completedRunIDs ?? []).union([run.id])
        activeRun = nil
    }

    public func node(runID: String, nodeID: String) -> VoyageNode? {
        guard !isUnreadable, activeRun?.id == runID else { return nil }
        return activeRun?.node(id: nodeID)
    }

    public mutating func updateNode(runID: String, nodeID: String, _ update: (inout VoyageNode) -> Void) {
        guard !isUnreadable, activeRun?.id == runID else { return }
        activeRun?.updateNode(id: nodeID, update)
    }

    public func isPlayable(runID: String, nodeID: String) -> Bool {
        !isUnreadable && activeRun?.id == runID && activeRun?.nextNode?.id == nodeID
    }

    public var encodedPayload: Data {
        if let unreadablePayload {
            return unreadablePayload
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        // An unencodable state must never crash saving; callers treat empty
        // data as unreadable and preserve it rather than wiping progress.
        do { return try encoder.encode(self) } catch { return Data() }
    }

    public static func decodePayload(_ data: Data?) -> Self {
        guard let data else { return .freshStart }
        do {
            var state = try JSONDecoder().decode(Self.self, from: data)
            if state.isValid {
                state.dismissRetiredRun()
                state.dismissCompleted()
                return state
            }
        } catch {
            // Preserve unknown or damaged bytes instead of replacing progress.
        }
        var state = Self()
        state.unreadablePayload = data
        return state
    }

    func sanitized() -> Self {
        guard !isUnreadable else { return self }
        if isValid {
            var state = self
            state.dismissRetiredRun()
            return state
        }
        var preserved = Self()
        preserved.unreadablePayload = encodedPayload
        return preserved
    }

    private mutating func dismissRetiredRun() {
        if let runID = activeRun?.id,
           completedRunIDs?.contains(runID) == true || abandonedRunIDs?.contains(runID) == true {
            activeRun = nil
        }
    }

    private var isValid: Bool {
        guard version == 1, offers.isEmpty || (offers.count == 3 && Set(offers.map(\.id)).count == 3
            && Set(offers.map(\.difficulty)).count == 3 && Set(offers.map(\.chapterID)).count == 3),
            offers.allSatisfy({ !$0.id.isEmpty && VoyageCatalog.bossID(chapterID: $0.chapterID) != nil }) else { return false }
        guard let run = activeRun else { return true }
        guard !run.id.isEmpty, run.nodes.count == run.offer.difficulty.nodeCount, Set(run.nodes.map(\.id)).count == run.nodes.count,
              run.nodes.first?.type == .battle, run.nodes.last?.type == .boss,
              !run.nodes.dropLast().contains(where: { $0.type == .boss }),
              run.earnedGold >= 0, run.earnedMaterials.values.allSatisfy({ $0 >= 0 }),
              run.nodes.drop(while: \.isCleared).allSatisfy({ !$0.isCleared }),
              VoyageCatalog.bossID(chapterID: run.offer.chapterID) != nil else { return false }
        return run.nodes.allSatisfy { node in
            node.type != .entrance && !node.id.isEmpty
                && (!node.type.isCombat || node.enemyID.flatMap { GameContent.enemy(matching: $0) }?.isBoss == (node.type == .boss))
                && node.modifierIDs.allSatisfy { NodeModifierCatalog.modifier(id: $0) != nil }
        }
    }
}
