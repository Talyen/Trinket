import SwiftData

func reconcileModels<Model: PersistentModel, Value, Key: Hashable>(
    existing: [Model],
    values: some Collection<Value>,
    existingKey: (Model) -> Key,
    valueKey: (Value) -> Key,
    make: () -> Model,
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
        let retained = modelsByKey.removeValue(forKey: valueKey(value))
        let model = retained ?? make()
        update(model, value)
        if retained == nil {
            link?(model)
        }
        reconciled.append(model)
    }
    for removed in modelsByKey.values {
        context?.delete(removed)
    }
    return reconciled
}
