# Identity

Trinket has no in-app account. Locked identity decisions are PD-008–PD-011 in
[Decisions.md](Decisions.md); this guide owns their player-facing consequences.
Persistence mechanics belong to [persistence context](../AgentContext/persistence.md).

## Current behavior

Ordinary builds default to local-only progress. Explicitly enabled internal beta
builds use iCloud as described below. Players begin without login or identity
prompts. Identity and sync errors must not gate local play.
Do not add Sign in with Apple, Google, hosted accounts, or Game Center integration.

Options → **Reset Game Progress** requires confirmation and resets progress on
this device. When linked to iCloud, the reset propagates to synced devices, but
progress from an offline device can return when it reconnects under
[PD-031](Decisions.md). Its copy must describe the applicable scope. Do not add a separate
Delete Account action when no Trinket account exists. Reset never removes Full Game
ownership; purchase access and restoration follow [Monetization.md](Monetization.md)
and remain independent of save synchronization.

## iCloud-enabled builds

In an enabled build, the device's iCloud account supplies private CloudKit storage
for automatic complete-save synchronization; SwiftData remains the on-device store. Devices using the same iCloud
account share progress silently. Offline or signed-out players retain local play;
there is no login splash, save-progress prompt, or manual sync funnel. A quiet
Options status may be added only if useful.

Reset must replace synced progress so the reset propagates to other devices;
reconnecting offline progress is reconciled conservatively and may restore earlier
progress. Update reset, support, and privacy copy when that behavior ships. Players
can also manage iCloud data through Apple's system settings.

The [CloudKit pre-ship checklist](../Platform/CloudKitPreShipChecklist.md) owns
enablement: provisioning, entitlements, schema, reset propagation, per-domain
conflict outcomes, passive Homestead claim authority, and device/release checks.
Keep that gate in place until its requirements are met; enrollment alone does not
establish readiness. Tests and CI remain deterministic without Apple ID credentials
or live CloudKit I/O.

## Apple references

Apple owns its current review and data-management requirements. Recheck these
during release work rather than treating repository summaries as guarantees:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Offering account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app)
- [Managing data stored in iCloud](https://developer.apple.com/icloud/allowing-users-to-manage-data/)
