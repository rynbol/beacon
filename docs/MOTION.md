# Beacon motion — 2026-09-12

Beacon uses short motion to make selection, disclosure, capture, and dismissal understandable. The implementation uses native Mac controls within the layout refresh documented in `LAYOUT-REFRESH.md`. It does not add a React/Motion dependency, animate text blur, or use decorative looping effects.

This pass replaces the Calendar animation paths that were previously rolled back after repeated text-rendering reports. Earlier entries in `CALENDAR.md` record those experiments; the architecture below describes their replacement.

## Research and adaptation

The following X posts were inspected in Chrome on September 12, 2026. Counts are observations from that session and will change. Bookmarks divided by likes is a signal of interest in revisiting a post, not a quality ranking, usability test, or controlled comparison. Different audiences, post ages, visibility, and presentation affect both counts.

| Reference | Likes | Bookmarks | Bookmarks / likes | Relevance to Beacon |
| --- | ---: | ---: | ---: | --- |
| [Emil Kowalski — pressed feedback](https://x.com/emilkowalski/status/1952354760637505541) | 3,934 | 2,730 | 69.4% | Give a click immediate, restrained feedback. |
| [Emil Kowalski — frequently repeated hover interactions](https://x.com/emilkowalski/status/1959952049627365474) | 1,886 | 661 | 35.0% | Frequent interactions should stay quick and unobtrusive. |
| [Emil Kowalski — chips](https://x.com/emilkowalski/status/2010728482528182425) | 1,809 | 1,020 | 56.4% | Let remaining items reflow as a removed item leaves. |
| [Emil Kowalski — click and dismissal](https://x.com/emilkowalski/status/2008539047463878768) | 791 | 305 | 38.6% | Use a restrained ease for click dismissal; demo inspected. |
| [Jakub Krehel — icon-state comparison](https://x.com/jakubkrehel/status/1955311846337954166) | 3,104 | 2,174 | 70.0% | Small state feedback can carry meaning without moving surrounding text; demo inspected. |
| [Jakub Krehel — quiet exits](https://x.com/jakubkrehel/status/1975951055633719687) | 438 | 253 | 57.8% | Keep exits less prominent than the action that brought content in; search text reviewed. |

These are examples used to form an implementation direction, not evidence that every technique belongs in Beacon. The existing user preferences—minimal UI, fast keyboard use, small attachment controls, and stable text—take precedence over copying a demo.

[Great Animations](https://emilkowal.ski/ui/great-animations) provides the broader principles used here: fast response, purposeful motion, interruption support, accessibility, and attention to how often an effect repeats. Its browser rendering advice is not a performance guarantee for SwiftUI. Beacon adapts the intent through native view/layout APIs and must be checked in the Mac app.

## Motion roles

`BeaconMotion` in `Sources/BeaconApp/Design.swift` defines the production timing values:

| Role | Animation | Use |
| --- | --- | --- |
| `feedback` | Ease-out, 0.12 seconds | Button press opacity and input focus treatment. |
| `selection` | Smooth spring, 0.20 seconds, no extra bounce | Selection backgrounds, tab underlines, disclosure chevrons. |
| `navigation` | Ease-out, 0.20 seconds | Main sections, Settings sections, Calendar dates and weeks. |
| `disclosure` | Smooth spring, 0.30 seconds, no extra bounce | Event details, full notes, Meeting details, personal-note mode, and other expandable controls. |
| `presentation` | Ease-out, 0.22 seconds | Settings, reminder editor, and snooze chooser entry. |
| `removal` | Ease-out, 0.18 seconds | Modal dismissal and removal treatments. |
| `list` | Smooth spring, 0.24 seconds, no extra bounce | Persisted reminder additions/completions and attachment changes. |

Durations are not delays before an action takes effect. State updates and permitted actions happen immediately; visual changes follow. No animation-completion sleep or interaction lock is added. Existing guards for open choice popovers and persistence remain separate behavior.

## Scope the effect, preserve the content

Button styles animate opacity with SwiftUI's scoped `animation(_:body:)` form. Input focus animates the border; selection animates the background or underline. These effects do not apply an animation to every descendant property. Apple's [scoped animation documentation](https://developer.apple.com/documentation/swiftui/view/animation%28_%3Abody%3A%29) and [WWDC23 explanation](https://developer.apple.com/videos/play/wwdc2023/10156/) describe why broad animation transactions can otherwise pick up unrelated child changes.

`BeaconSectionMotion` keeps view identity and applies a short visual entrance: 10 points horizontally or 8 points vertically. Its trigger is the selected destination, Settings section, Calendar tab, date, or week—not refreshed data. Calendar replaces its content in a nonanimated transaction, and the motion wrapper owns the visual movement. Search edits and feed refreshes do not replay section entrances.

Shared wrappers use `geometryGroup()` to keep child geometry together when their parent moves. Apple documents this as a barrier to geometry changes being independently applied at descendant drawing views. It complements stable layout proposals; it is not a substitute for them or proof that rendering is correct. [Apple geometry groups](https://developer.apple.com/documentation/swiftui/view/geometrygroup%28%29)

## Calendar disclosure geometry

The previous implementation measured content with `onGeometryChange`, wrote a height into `@State`, then used that height in an animated frame. Event details, Meeting details, and personal-note editing nested this pattern. A child could report a height after its parent's animation had already begun, creating another corrective layout change. Broad list animation could also animate these updates.

The replacement is `BeaconRevealLayout`, a synchronous custom SwiftUI `Layout`:

1. Measure the content for the available width with unrestricted height.
2. Optionally measure a second, hidden child to obtain the collapsed height.
3. Report a viewport height interpolated between the collapsed and full values.
4. Always place each child at its own full natural height, even when only part of the viewport is visible.

Clipping changes what is visible; it does not offer the text an intermediate, shrinking layout height. The same layout supports completely collapsed content and a shortened notes preview. This uses the measurement and placement responsibilities in Apple's [Layout protocol](https://developer.apple.com/documentation/swiftui/layout).

`BeaconDisclosure` applies this layout to event cards and Meeting details. It clips its visible region, disables closed content's hit testing, and hides it from accessibility. At the content boundary it clears inherited animation, while allowing nested controls to opt into their own scoped effects. `CalendarAgendaMotion` coordinates sibling placement on event selection changes across Day, Next 7 days, and Today. Each card has a geometry group outside its nonanimated content boundary, so row movement shares the disclosure curve without interpolating text metrics. A no-bounce spring retains velocity when an interaction reverses midway.

Full notes now keeps one unlimited visible `Text`. A hidden five-line version provides the collapsed size. The visible text's line limit never changes during expansion. The remaining geometry observations only decide whether to show the disclosure button; they do not set a visible frame.

Personal-note read/edit modes use a separate synchronous two-child layout. Both receive their final natural geometry, including the editor's fixed 96-point height. The native editor is allocated after the event's first edit and remains mounted afterward. When inactive, it loses focus and keyboard submission handling. Read/edit text visibility switches without a crossfade, avoiding two differently inset copies of the same text appearing together. The container and following media row still move smoothly. Local autosave, Return to finish, Shift-Return for a newline, attachment storage, and retry handling are preserved.

## Accessibility and interruption

Reduce Motion disables button/selection interpolation, disclosure height motion, list movement, and section displacement. Modal surfaces use an opacity transition without positional movement; their backdrop also fades. Content remains usable in either mode.

New input retargets state directly; there are no timed queues for rapid event, date, or disclosure changes. Inactive editors and closed detail regions cannot retain interactive focus. Follow-up, meeting links, and local media behavior remain the same. No new EventKit writes or calendar synchronization behavior are introduced by this motion pass.

## Verification status

- The completed automated run recorded during implementation has **158 passing tests**, including three new `RevealLayoutTests` that use SwiftUI's real layout engine offscreen.
- Geometry tests cover closed/partial/full reveal progress, narrow and wide text, shortened-note measurement, and nested Meeting details. They inspect actual child placement bounds to verify that text retains its natural height while the viewport changes.
- These tests do not establish frame-by-frame animation smoothness, native text-editor behavior, or end-to-end app usability.
- Normal and isolated-preview builds succeeded. Sample walkthroughs covered search and editor initial focus, reminder creation/completion, event selection, full notes, Meeting details, personal-note Return/Shift-Return, date/week changes, filters, themes, and modal dismissal. The calendar color popover was checked: Escape closes the picker while Settings stays open.
- Slowed intermediate frames were inspected for modal entry/exit and calendar disclosures. After the reported event-switch roughness, sibling placement was explicitly coordinated; intermediate screenshots showed the closing and opening cards and their following row aligned, with intact text. These observations are targeted visual checks, not a measured frame-rate guarantee.
- A subsequent nested-notes capture was interrupted by ScreenCaptureKit error -3811. The earlier nested notes checks and geometry tests passed; that final capture attempt is not counted as a pass. Media importing and OS Reduce Motion were not rerun in this pass. Minimum-width native dragging was unavailable; narrow geometry is covered offscreen.
- Diagnostic timing is temporary and is restored to the production constants above before final builds.
- No claim is made here about notification delivery, Siri, iPhone behavior, or remote Google/iCloud propagation; those are outside this UI change.

The final app walkthrough should cover rapid event switching, full notes inside Meeting details, first note edit, Done/Return/Shift-Return, switching away while editing, date/week reversals, width changes, media actions, modal dismissal, and the Reduce Motion path. Use isolated sample data for write interactions.
