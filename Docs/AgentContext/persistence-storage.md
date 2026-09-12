# Persistence storage contract

Use with [persistence ownership](persistence.md) for schemas, graph reconciliation, sanitization and recovery.

Reads use an in-memory observed projection; load/repair sanitizes `root.toPlayerSave()` from the SwiftData graph. `PlayerSave.currentSchemaVersion` versions the value-layer payload and its sanitizer/mapping migrations independently of the SwiftData migration version declared by `PlayerSaveSchema`; bumping one does not imply bumping the other. Slice writes expand through `PlayerSaveSlice.sanitizeTargets`: inventory also sanitizes roster (equipped items must exist), and labyrinth also sanitizes roster (recruit eligibility feeds map healing). Labyrinth sanitize runs on labyrinth mutations and full load, not on every inventory or roster write; recruit eligibility is applied when a map is generated.

Roster sanitization accepts current catalog IDs and applies [Core talent repair](../../Packages/TrinketCore/README.md).

Distributed TestFlight builds have local player saves that must be preserved or
migrated when schemas or serialized identifiers change. Production CloudKit remains
gated by the [release checklist](../Platform/CloudKitPreShipChecklist.md).
Historical development-save migrations and retired identifier aliases were removed
before that distribution; their retirement is not permission to remove support for
current saves. The current value schema identifier is unchanged. Unsupported value
schemas are rejected without rewriting their progress. Unsupported Labyrinth map payloads use
the existing unreadable-map recovery path, without translating historical floor
progress. Current-data validation, relationship repair, and corruption recovery
remain required.

Labyrinth's map is a JSON blob (`LabyrinthProgressModel.mapPayload`) while roster/inventory/homestead are normalized child tables — intentional trade-off for spatial graph queries; don't normalize the labyrinth without measuring encode cost.

Failed writes restore the pre-mutation value snapshot into the affected graph slices
and observed projection. This compensation stays unsaved until a later successful
write; recovery does not call `ModelContext.rollback()` because restoring deleted
relationship rows can crash SwiftData on the iOS 27 simulator. An immediate failure
preserves earlier deferred changes, while a failed deferred flush restores its
last persisted snapshot. Full resets compensate the complete graph. Reload tests
must also prove that a subsequent successful write preserves the recovered values.
