import TrinketContent

struct ManaPayment {
    let payerID: String
    let balanceBefore: Int
    let balanceAfter: Int

    init(payer: Combatant, balanceBefore: Int, balanceAfter: Int) {
        payerID = payer.id
        self.balanceBefore = balanceBefore
        self.balanceAfter = balanceAfter
    }

    var amountSpent: Int {
        balanceBefore - balanceAfter
    }

    var spentLastMana: Bool {
        amountSpent > 0 && balanceAfter == 0
    }
}
