# UI library trial — 2026-09-08

Research used X in Chrome and primary project documentation. X results are examples, not evidence of community consensus.

- Glur: https://x.com/joogps/status/1754518852719767696 — progressive blur. Interesting visual polish, but not needed for Beacon's flat reminder workspace.
- SwiftUI Markdown: https://x.com/onmyway133/status/2089438278919303555 — styled Markdown rendering. Consider only if rich reminder notes become a requirement.
- SwiftUI Introspect: https://github.com/siteline/swiftui-introspect — selected after checking its own documentation and release source, not presented as an X recommendation.

## Adopted

SwiftUI Introspect 26.0.2, exact-pinned in Package.swift and Beacon.xcodeproj. It has no transitive package dependencies or build plugins. Its MIT notice is in Resources/Licenses and copied into packaged apps by the build script.

BeaconScrollView configures the underlying NSScrollView with native overlay scrollbars and small controls on macOS 26. AppKit owns interaction and visibility; the old custom 900 ms timer and visibility toggling are removed. Overlay bars do not reserve content width. Introspection explicitly opts into macOS 26; future major versions require checking library support. If introspection cannot find a view, the ordinary SwiftUI ScrollView remains usable.

The sample-data preview verified an uncluttered idle list, thin overlay during scrolling, and stable content alignment. No live reminder/calendar writes were used. Preview and X research tab were closed afterward.

## Native editing controls

Extended Introspect to TextEditor and ColorPicker on macOS 26. Notes now use NSTextView-backed plain-text editing with native undo, inset text, bounded scrolling, and the same overlay scroller style. The placeholder cannot intercept clicks. Urgency colors use AppKit's minimal color-well style with its native palette popover. Other buttons, menus, and date controls already use SwiftUI; no extra introspection is added where ordinary modifiers suffice.

Sample preview verified existing notes load, newline entry, Cmd-Z restoration, and color palette opening. The draft was dismissed without saving. No live user data changed.

## Visual component kit: Swiftcn

Found through the creator's X announcement: https://x.com/0xSuman/status/1705823334586593381 (2023-09-23). Source: https://github.com/Mobilecn-UI/swiftcn-ui, revision `515a26e0861f28fdaa1808e22789573d46f8c60e`. This is a small copy-in kit, not a claim of current community consensus or a comprehensive production framework. The similarly named gillesdm/SwiftCN repository was inspected but not adopted.

`Sources/BeaconApp/SwiftcnComponents.swift` adapts Swiftcn's CustomButton, CustomCard, CustomTabs, and InputBoxModifier treatments. MIT attribution is retained in Resources/Licenses/Swiftcn.txt and bundled by the Mac build script. Adaptations replace upstream tap gestures with native Buttons, add disabled/pressed/selected states, size tab underlines to their labels, accept generic content, and use Beacon's palette and compact sizing instead of iOS-only colors or larger default spacing.

Applied across:
- Reminder date presets, repeat/grouping/accent chips, Save and keyword Add/Filters actions.
- Shared cards throughout Settings, reminders, and repeat controls.
- Search, quick capture, reminder title and notes, and Calendar keyword input surfaces.
- Settings sections and Calendar Day / Next 7 days tabs.

The sidebar, main arrangement, completion control, urgency semantics, and background theme are unchanged. Native menus, date pickers, toggles, and scrollbars are retained where replacing behavior would add risk without a visual benefit. No new remote dependency, script, or runtime network access is introduced by the copy-in kit.

Sample-data preview checked editor appearance, disabled Save, selecting Tomorrow (9 AM), Settings tab switching and keyword fields, and Calendar Day / Next 7 days navigation. All previews and X research tabs were closed afterward; no live reminders were modified.
