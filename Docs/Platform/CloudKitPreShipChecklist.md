# CloudKit release checks

Ordinary builds enable automatic iCloud progress sync. Local play continues without
an iCloud account or network connection. Test and reset launches remain isolated;
use `--cloud-sync NO` on the TestFlight deployment command for a local-only rollback.
The [storage contract](../AgentContext/persistence-storage.md#cloudkit-preparation)
owns save, merge, account, reset, and recovery behavior.

## Setup baseline

- Bundle ID: `com.ryanmcintire.Trinket`.
- Private container: `iCloud.com.ryanmcintire.Trinket`.
- App Store Connect app: `6811284921`.
- Debug uses Development CloudKit; Release and TestFlight use Production.
- `CLOUDKIT_SYNC_ENABLED` defaults to `YES` in `project.yml` and is passed into
  `TrinketCloudSyncEnabled`. Release export verifies the effective value and
  Production iCloud and push entitlements.

## Required readiness gates

Before a release, check changes that affect sync against the storage contract and
existing verification. Reuse applicable results; a new build number alone does not
invalidate them. Test changed or unverified behavior at the appropriate level, and
keep isolated tests distinct from live device evidence. Focus on preservation of
populated saves, two-device import and merge, account changes, offline recovery,
reset, Homestead transactions, and rollback when the relevant behavior changes.

Check Production schema and signing when they change. Reconcile support, privacy,
and App Privacy disclosures with the distributed build. Use deliberate test saves
for destructive scenarios, preserving existing progress. StoreKit purchase readiness
is separate; see [Purchases](Purchases.md).

## Prepared TestFlight activation

The normal [TestFlight deployment](Release.md#local-testflight-deployment) inherits
cloud sync from `project.yml`. It uses Production and assigns the configured internal
beta group. The deployment validates the exported sync setting, signature and
entitlements before upload. An explicit `--cloud-sync NO` creates a local-only build
without deleting local saves or cloud records; use a higher build number for rollback.

[Player coverage](PlayerCoverage.md) describes automated checks; live device checks
establish behavior that isolated tests cannot. Recheck the relevant scenarios when
sync, schema, account, or persistence behavior changes.

## Apple references

- [Schema deployment](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)
- [Development and TestFlight testing](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/TestingYourApp/TestingYourApp.html)
