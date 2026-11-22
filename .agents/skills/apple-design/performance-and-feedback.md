# Performance and feedback

Follow [Design principles](../../../Docs/Product/DesignPrinciples.md) (PD-032)
for UI/UX and gameplay interaction feedback; existing perceptible responses
count.

Distinguish press acknowledgment from committed outcome feedback, and tie
visual, sound, and haptic outcome feedback to the same resolved event through
the existing audio and feedback owners so they stay in sync and don't double-fire.

Keep system haptic meanings consistent—selection for a changed choice, impact
for a physical event, notification for an outcome—without duplicating a native
control's built-in haptic. Match intensity to the event, avoid fatiguing
repetition, and make sure the outcome is clear with sound and haptics off.

For responsiveness issues, trace the delayed action first (view invalidation,
unstable identity, or work on the input path) before tweaking animations. Use
[the performance playbook](../../../Docs/Platform/PerformanceInvestigationPlaybook.md)
when measurement is needed, and preserve the artwork working-set policy.
Simulator runs can help locate issues, but real timing, audio output, and
physical haptics require a physical device.

When changing playback or audio-session behavior, follow the
[audio owner](../../../Docs/AgentContext/audio.md): preserve Trinket's
ambient/mixing policy and Options settings (without adjusting system volume),
trace existing lifecycle handling before adding observers, and check silent
mode, other-app audio, interruptions, and headphone changes on device.

Apple references: [Playing audio](https://developer.apple.com/design/human-interface-guidelines/playing-audio)
and [Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics).
