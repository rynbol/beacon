# Layout refresh · September 2026

This implements the Calendar and Settings layout study proposed on September 12.
The aim is a readable, compact workspace that keeps Beacon's sidebar, warm
surfaces, and restrained accent colors.

## Layout rules

- The workspace is bounded to 960 points including its 32-point side gutters.
  Headers, capture, lists, Calendar, and status share that alignment. Narrow
  windows use the available space; wide windows no longer stretch each row's
  actions away from its text.
- Reminder titles use 14-point type, supporting text 12, and section headings
  13 semibold. Smaller gaps replace excess space without shrinking all text.
- Search rests as a toolbar icon. Clicking it or pressing Cmd-F opens the field;
  a nonempty query remains visible. The sidebar's New reminder action is now
  clickable as well as available through Cmd-N.
- Calendar has a compact toolbar, a quiet date strip, and one agenda heading.
  Collapsed events are simple rows; an expanded event gets a stronger surface.
  Long notes and the associated actions have a 660-point reading measure.
- Personal note has one heading in empty, saved, and editing states. Text and
  media sit beneath it. The dashed media control, top-left removal button,
  local-only storage, and meeting/follow-up actions remain available.
- Settings uses shared groups and aligned label/control rows. Calendar sources
  precede the Next 7 days rules and manual additions. The reminder editor uses
  the same spacing and type hierarchy.

All background presets, highlight colors, urgency settings, filter semantics,
Apple Reminders persistence, and calendar synchronization behavior are retained.
Motion implementation and validation are documented in [MOTION.md](MOTION.md).

## References

The design study compared [Linear's interface refresh](https://linear.app/now/behind-the-latest-design-refresh),
[Raycast Settings before/after](https://x.com/peduarte/status/2054996462262435940),
and [Things' task and note surfaces](https://culturedcode.com/things/features/).
The useful patterns are predictable header placement, coherent settings groups,
and keeping optional detail secondary. The existing Swiftcn adaptations and
native SwiftUI controls implement those principles; this is not an imported
component kit or a change of application framework.

## Build identity

The current sample app is `build/BeaconPreview.app` with bundle identifier
`dev.dylan.beacon.preview`. It has a separate identity from older V2 worktree
previews. Packaged apps record their source checkout and revision in Info.plist.
Sample reminder edits are memory-only and reset on restart. The normal
`build/Beacon.app` keeps its existing identity and real data.
