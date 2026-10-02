/// A readied bonus and the creating card/action that cannot spend it.
/// Absence represents an unarmed talent; consuming it clears value and provenance together.
struct PreparedTalentBonus<Value: Hashable & Sendable>: Hashable, Sendable {
    let value: Value
    let cardSerial: Int?
    let actionID: Int?

    init(value: Value, cardSerial: Int? = nil, actionID: Int? = nil) {
        self.value = value
        self.cardSerial = cardSerial
        self.actionID = actionID
    }

    func availableValue(cardSerial currentCardSerial: Int?, actionID currentActionID: Int?) -> Value? {
        guard cardSerial == nil || cardSerial != currentCardSerial,
              actionID == nil || actionID != currentActionID else { return nil }
        return value
    }
}
