import Foundation

public struct StageMapMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String
    public let fullGameOffer: FullGameOfferOrigin?

    public init(id: UUID = UUID(), title: String, message: String, fullGameOffer: FullGameOfferOrigin? = nil) {
        self.id = id
        self.title = title
        self.message = message
        self.fullGameOffer = fullGameOffer
    }

    public static func fullGameRequired(_ origin: FullGameOfferOrigin) -> Self {
        Self(title: "Full Game", message: "This content is included with Full Game.", fullGameOffer: origin)
    }
}
