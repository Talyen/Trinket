import Foundation
import TrinketCore

public extension CombatantTraitDefinition {
    var nameResource: LocalizedStringResource {
        ContentCopy.traitNameResource(id) ?? ContentCopy.resource(name)
    }
}

public extension TalentNode {
    var nameResource: LocalizedStringResource {
        ContentCopy.talentNameResource(id) ?? ContentCopy.resource(name)
    }
}
