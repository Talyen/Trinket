# Identity

Trinket has no in-app account. Locked identity decisions are PD-008–PD-011 in
[Decisions.md](Decisions.md); this guide owns their player-facing consequences.
Persistence mechanics belong to [persistence context](../AgentContext/persistence.md).

## Current behavior

Progress is local-only; live CloudKit remains gated. Players begin without login,
iCloud, or identity prompts. Identity and sync errors must not gate local play.
Do not add Sign in with Apple, Google, hosted accounts, or Game Center integration.

Options → **Reset Game Progress** requires confirmation and clears progress on
this device. Its copy must describe that device-local scope. Do not add a separate
Delete Account action when no Trinket account exists. Reset never removes Full Game
ownership; purchase access and restoration follow [Monetization.md](Monetization.md)
and remain independent of save synchronization.

## Future iCloud synchronization

After enablement, the device's iCloud account supplies private CloudKit storage
for automatic SwiftData progress synchronization. Devices using the same iCloud
account share progress silently. Offline or signed-out players retain local play;
there is no login splash, save-progress prompt, or manual sync funnel. A quiet
Options status may be added only if useful.

Reset must remove or replace synced progress so the wipe propagates to other
devices. Update reset, support, and privacy copy when that behavior ships. Players
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
