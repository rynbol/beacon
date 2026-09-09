# UI library trial — 2026-09-08

Research used X in Chrome and primary project documentation. X results are examples, not evidence of community consensus.

- Glur: https://x.com/joogps/status/1754518852719767696 — progressive blur. Interesting visual polish, but not needed for Beacon's flat reminder workspace.
- SwiftUI Markdown: https://x.com/onmyway133/status/2089438278919303555 — styled Markdown rendering. Consider only if rich reminder notes become a requirement.
- SwiftUI Introspect: https://github.com/siteline/swiftui-introspect — selected after checking its own documentation and release source, not presented as an X recommendation.

## Adopted

SwiftUI Introspect 26.0.2, exact-pinned in Package.swift and Beacon.xcodeproj. It has no transitive package dependencies or build plugins. Its MIT notice is in Resources/Licenses and copied into packaged apps by the build script.

BeaconScrollView configures the underlying NSScrollView with native overlay scrollbars and small controls on macOS 26. The old custom 900 ms timer and visibility toggling are removed. A follow-up compact-window check found that SwiftUI still reserved a legacy scrollbar gutter despite AppKit's overlay style. The wrapper now also hides SwiftUI scroll indicators and gives content the full available width, preventing a roughly 17-point shift when content overflows. Native scrolling remains available; AppKit can still expose an overlay indicator during interaction. Introspection explicitly opts into macOS 26; future major versions require checking library support. If introspection cannot find a view, the ordinary SwiftUI ScrollView remains usable.

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

## Background themes

Settings → Appearance now holds coordinated Paper, Mist, Beige, and Dark background presets, independent highlight swatches, reminder grouping, and urgency color wells. Siri and About remain available in Help. The shared palette updates the workspace, sidebar, cards, editors, and settings immediately. Native controls follow the selected light/dark scheme. Theme choice persists locally, with a separate preview preferences domain. Custom urgency colors remain untouched; Dark adapts the default accents and urgency colors.

Verification: all 128 unit tests pass, including primary/secondary text contrast against all three surfaces of every preset. Normal and sample-preview Mac builds pass. The sample preview verified theme switching, Dark native controls and reminder readability, and Beige persistence after quitting and reopening. Preview was restored to Paper and closed. This targeted theme check does not represent the broader end-to-end audit, which remains paused.

## Editing selections

BeaconChoicePicker is a Beacon component composed with the existing Swiftcn-adapted button styling and shared scrolling surface; it is not an upstream Swiftcn component or an additional package. It replaces the menu-style pickers for urgency, reminder list, repeat frequency/end condition, reminder grouping, quiet hours, and the editor's Later choices. Popovers use the current theme, selected checkmarks, optional urgency symbols/colors, and a bounded scrolling list that opens at the selected value. Native buttons retain accessibility labels and selected traits; arrow keys move focus and Return selects. Escape and outside clicks cancel without updating the binding.

Parent Save/Close shortcuts and outside dismissal are guarded while choosing and for the 250 ms native closing transition. Each picker owns a separate presentation token, so closing one cannot unlock the parent while another is open. The guard was added after reproducing quick Escape dismissing Settings along with its popover.

BeaconStepper replaces the small native spinner in snooze intervals and repeat interval/count rows with consistent minus/plus buttons. Existing bounds and model operations remain in place. Date/calendar and color-well controls remain native, as do reminder action/context menus. No new dependency was added.

Primary API references: [SwiftUI move commands](https://developer.apple.com/documentation/swiftui/view/onmovecommand(perform:)) and [modal presentation APIs](https://developer.apple.com/documentation/swiftui/modal-presentations).


## Calendar note parsing

[SwiftSoup](https://github.com/scinfu/SwiftSoup), exact version 2.9.6, parses provider HTML locally into plain text. It is a BeaconKit dependency, not a web view or UI component. No URLs are fetched by the parser. Its MIT notice is bundled in Resources/Licenses/SwiftSoup.txt. Both SwiftPM and Xcode resolution files pin the dependency.
