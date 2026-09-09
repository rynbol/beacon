# Beacon V2 design study

Separate worktree: `beacon-v2`, branch `codex/beacon-v2`, based on `d368e92`. V2 was initially developed separately and then approved to replace the main Mac version. The iPhone worktree remains separate.

## Research — X, viewed in Chrome on 2026-09-08

[Om Patel's discussion](https://x.com/om_patel5/status/2030310771326861336) argues that repeatedly using the same icon, font, and component defaults makes products look interchangeable. It suggests choosing a coherent alternative icon language. The post includes promotional claims and duplicated text; treat it as opinion, not evidence of design quality.

Replies offer useful qualifications: [Mingta Kaivo](https://x.com/MingtaKaivo/status/2030323167856562442) describes combining icon changes with a limited palette; [Pinkesh](https://x.com/pinkeshdpatel/status/2031022345096425657) suggests custom icons; [Smik](https://x.com/smik_0/status/2030329055846052140) says switching libraries produces only a small difference. This is a small discussion sample, not a survey or proof that an interface can be identified as AI-generated.

## Applied decisions

- Preserve the warm paper palette, sidebar structure, calendar behavior, and reminder interactions.
- Draw six navigation glyphs and a lighthouse mark on a shared 24-point grid with consistent strokes and rounded joins. Keep native SF Symbols for conventional controls such as search, microphone, settings, and close.
- Use a compact serif wordmark with clearer system-font page headings. Do not introduce downloaded font or icon dependencies.
- Remove the sparkle and motivational sidebar card. Replace it with a useful shortcut hint.
- Let task groups share the page surface, separated by rules, instead of framing every group as a rounded card. Keep large click targets and visible Snooze actions.
- Reduce date-chip corner radius and replace vague filler copy with concrete descriptions. Preserve the user-requested Calendar subtitle, “Everything u have”.

## Compare safely

Run `BEACON_PREVIEW=1 ./Scripts/build-mac-app.sh` and open `build/BeaconV2Preview.app`. It has a separate preview bundle identity and preferences and uses sample data; writes are disabled. This isolated preview uses sample data. Build without `BEACON_PREVIEW=1` for the regular `build/Beacon.app` with the existing app identity and saved preferences.

## Main layout refinement — 2026-09-08

The sidebar remains unchanged. A single compact header replaces separate date and page-title rows; Today places the date beneath its title and All reminders omits its redundant subtitle. Quick entry is shorter, with its plus opening the full editor; Cmd-N retains view-specific due defaults. Calendar retains a header plus for creating reminders.

Today uses one scrolling column: reminders first, then up to three calendar events with a See all action. An empty connected calendar becomes one navigable status row. The duplicate Today grouping title is suppressed for time grouping; list grouping retains useful list headings. Permission and refresh errors remain visible. No background-theme changes are included.

Sample preview checked populated and empty-calendar Today layouts, restored the test calendar toggle, and verified Cmd-N still defaults to Now in Today. Preview closed afterward.
