import SwiftData

func reconcileModels<Model: PersistentModel, Value, Key: Hashable>(
    existing: [Model],
    values: [Value],
    existingKey: (Model) -> Key,
    valueKey: (Value) -> Key,
    make: (Value) -> Model,
    update: (Model, Value) -> Void,
    link: ((Model) -> Void)? = nil,
    context: ModelContext?,
) -> [Model] {
    var modelsByKey = [Key: Model](minimumCapacity: existing.count)
    for model in existing {
        let key = existingKey(model)
        if modelsByKey[key] == nil {
            modelsByKey[key] = model
        } else {
            context?.delete(model)
        }
    }

    var reconciled: [Model] = []
    reconciled.reserveCapacity(values.count)
    for value in values {
        if let model = modelsByKey.removeValue(forKey: valueKey(value)) {
            update(model, value)
            reconciled.append(model)
        } else {
            let model = make(value)
            update(model, value)
            link?(model)
            reconciled.append(model)
        }
    }
    for removed in modelsByKey.values {
        context?.delete(removed)
    }
    return reconciled
}
