# Beacon on your own iPhone: build and installation plan

## Product decision

Keep the sidebar/workspace interface on Mac (`beacon`). Adapt the minimal one-list interface (`beacon-unforgetful`) into a native iPhone app. Share the reminder engine, data model, parser, and App Intents, while allowing each platform to have its own interface.

This is a plan for a native iOS build, not web hosting. No server or monthly hosting bill is needed. Both apps use Apple Reminders; iCloud sync remains Apple's responsibility.

## Where the project is today

- The Mac app builds and uses EventKit to read and write Apple Reminders.
- The minimal app is still a **Mac app**. Its Swift package declares iOS compatibility for shared code, but that does not create an iPhone application.
- Xcode 26.6 is installed on this Mac. No available simulator devices appeared in the local simulator inventory during this check; an iOS runtime/device will need to be installed or created for simulator testing.
- `Beacon.xcodeproj` currently contains the **BeaconMac** scheme. It also generates and packages the App Intents metadata required for Siri/Shortcuts.
- There is no `BeaconIOS` scheme or installable `.ipa` yet. Do not try to copy the Mac `.app` to your phone.
- Apple Account membership and the iPhone model/iOS version still need confirmation before selecting deployment settings.

## 1. Choose how to sign and install

| Route | Cost | Renewal and friction | Appropriate use |
|---|---|---|---|
| Xcode Personal Team | Free Apple Account | Profiles expire after 7 days; rebuild and reinstall. Up to 3 apps per device, 3 devices per platform, and 10 App IDs under Apple's stated limits. | First working install and trying the app before paying |
| Paid developer membership + direct Xcode install | US $99/year, or local price | Longer-lived signing; inspect the actual provisioning profile's expiration date and re-sign before it expires. No App Store listing or review needed for your own development device. | Regular personal use if you already have membership or accept its cost |
| TestFlight | Paid membership | Each uploaded build lasts up to 90 days; upload replacements. Requires App Store Connect setup. | Easier distribution to multiple people/devices; unnecessary overhead for the first personal install |

Recommendation: prove the app on a free Personal Team first. If you already have paid membership, use it for direct installation. Paying $99/year solely for this personal app costs more than the original reference app's advertised annual subscription at launch; choose it for development flexibility, not presumed cost savings.

Sources: [Apple account limits](https://developer.apple.com/help/account/basics/about-your-developer-account), [membership](https://developer.apple.com/programs/enroll/), [registered-device distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices), [TestFlight lifetime](https://testflight.apple.com/).

## 2. Build the iPhone target

Add a native iOS application target and shared `BeaconIOS` scheme to the Xcode project. Keep the current Mac scheme intact. Start with iOS 26 to match the package's current minimum; lowering this should be a separate compatibility decision based on your actual phone.

The target needs:

- A unique, stable iOS bundle identifier, for example `dev.dylan.beacon.ios`, with automatic signing and your selected Team.
- A dependency on `BeaconKit`, not the Mac executable target.
- An iOS entry point and notification delegate, initialized before notification actions arrive.
- The minimal interface adapted for safe areas, a phone-sized keyboard, Dynamic Type, touch targets, and compact sheets. Remove fixed Mac window sizes, AppKit calls, and Mac-only menu styles.
- Date sections in one list, bottom capture, completion and snooze actions, notes, recurrence, a settings sheet, and a clear permission/notification status.
- `NSRemindersFullAccessUsageDescription`, an app icon, and launch/scene configuration.
- Time Sensitive notification capability if we retain that interruption level, subject to the signing team's supported capabilities. No Critical Alerts entitlement is needed for the planned first version.

Definition of done: it compiles for iPhone, launches in the simulator, lays out correctly at the smallest supported phone size, and the shared tests pass.

## 3. Voice and Siri on iPhone

There are two complementary routes:

1. **Existing Siri-to-Reminders flow:** say “Siri, remind me to water the plants tomorrow at 9.” Siri creates an Apple Reminder; Beacon reads it. **No date → Someday, without alerts. Explicit today/tomorrow/time → that scheduled date.** The built-in command remains Apple’s; Beacon interprets the resulting data rather than overriding Siri. Both devices must use the relevant Reminders account/list, and iCloud Reminders must be enabled for cross-device sync.
2. **Explicit Beacon App Shortcuts:** “Add a reminder in Beacon” prompts for reminder text; “Show my reminders in Beacon” opens and refreshes the app. The Mac implementation is now in source. Include the same intents in the iOS app target, with a shared platform-appropriate model/service.

The first iOS dictation option should use Apple's keyboard microphone inside the capture field. The custom Mac `startDictation:` responder action is not an iOS API. If a separate in-app iPhone mic button must start capture directly, implement it with supported iOS Speech/audio APIs, visible recording state, cancel/stop behavior, and the microphone/speech permission descriptions. Do not assume the Mac fix ports unchanged.

Siri and Shortcuts availability can depend on language, app indexing, and permission state. Validate actual spoken phrases on the phone, not just the presence of source code.

Sources: [App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts), [Siri reminders](https://support.apple.com/en-us/102484).

## 4. Prove notification behavior before relying on it

The phone cannot run the Mac's once-per-minute refresh loop while suspended. iOS background execution is discretionary. A notification being delivered also does not mean arbitrary app code runs.

Use local system notifications, preplan a bounded schedule, refresh on foreground/notification response, and treat background refresh as a best-effort improvement. Be explicit about what can become stale while the app isn't running. The existing 36-hour one-shot window and daily fallback are a starting point, not a promise of full Unforgetful parity.

Test with a dedicated scratch list:

- Create, edit, complete, and snooze a reminder; confirm each result in Apple Reminders.
- Create an undated reminder through Siri; confirm it appears in Someday without a made-up due date or alert. Then give it a date and confirm it becomes scheduled.
- Lock the phone and wait for a short test reminder.
- Dismiss an alert and confirm another arrives without changing the due date.
- Use Snooze and Complete from notifications, including when the app must start.
- Test recurrence, multiple missed occurrences, quiet hours, time-zone changes, and a denied permission.
- Test app termination, reboot, and a day without opening it. Record observed results separately from intended behavior.

Choose one primary alerting device initially: iPhone alerts on, Mac alerts off. Task data syncs via Reminders, but Beacon's mute/snooze sidecar is currently device-local. Do not imply recurring-task snoozes or mute state sync across devices until that is implemented. Non-recurring snoozes update the Reminder due date and can sync through Reminders.

Source: [Apple local notification behavior](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html).

## 5. First installation through Xcode

After `BeaconIOS` exists and passes build checks:

1. Open `Beacon.xcodeproj` in Xcode.
2. In Xcode Settings → Accounts, sign in with your Apple Account. Keep credentials in Xcode/Keychain; do not put them in project files or scripts.
3. Select the iOS target → Signing & Capabilities → Automatically manage signing → select your Personal Team or paid Team.
4. Connect the unlocked iPhone by cable. Accept the phone's trust prompt and pair it with Xcode.
5. Enable Developer Mode on the phone under Settings → Privacy & Security when prompted, restart, and confirm. These device security confirmations are yours to perform.
6. Select the actual iPhone as the run destination and run the `BeaconIOS` scheme. Xcode registers/provisions the device as needed.
7. On the phone, allow Reminders access and notifications, then review Time Sensitive/Focus settings as appropriate.
8. Confirm a test reminder round-trips and a real notification arrives before treating installation as complete.

If Xcode reports unsupported iOS, install a compatible Xcode/SDK. If Developer Mode is missing, pair through Xcode first and follow the device setup prompts. If signing fails, fix the team/bundle identifier/device registration; do not delete existing reminders or reset broad system permissions.

Sources: [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device), [device registration and automatic signing](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices).

## 6. Repeatable self-deployment

After the first Xcode install is proven, add an `install-iphone.sh` script. It should:

1. Check Xcode, `BeaconIOS`, device pairing, Developer Mode, and team configuration.
2. Build the iOS app into a known DerivedData directory for the connected phone.
3. Let Xcode manage provisioning with the selected Apple Account and team.
4. Install the produced iOS `.app` with `xcrun devicectl device install app` and launch it.
5. Report the actual bundle version, build result, and provisioning expiration.
6. Preserve the same bundle ID so subsequent installations upgrade the app instead of creating a different app.

This script cannot skip the initial Apple sign-in, device trust, Developer Mode, account agreements, or permission dialogs. Wireless deployment is an optional convenience after initial pairing. It also cannot turn seven-day free signing into a permanent installation.

Do not set up automatic weekly jobs yet. First make one complete install/reinstall cycle work, then choose whether you want a reminder or an authorized scheduled deployment. A free account still needs periodic rebuilding/reprovisioning.

## 7. Ongoing maintenance and rollback

- Check the provisioning expiration and re-sign before expiry. Free signing means a weekly rebuild cycle; TestFlight means replacing builds within its 90-day window.
- Keep a tagged source checkpoint before each phone release, plus a changelog of reminder-engine changes.
- Keep shared engine changes tested on both platforms. Treat notification and recurrence changes as requiring phone checks.
- Avoid uninstall/reinstall as the default upgrade path: it can discard local preferences and snooze/mute state. Apple Reminders remain the durable task store.
- If Beacon misbehaves, disable its alerts and use Apple Reminders while diagnosing. Keep the previous source checkpoint buildable.
- Recheck notification permissions and behavior after major iOS upgrades.

Suggested delivery order: iOS target → compact interface → permissions and Reminders writes → Siri and keyboard dictation → locked-phone notification tests → first free/paid Xcode install → repeatable deployment script → optional background enhancements and advanced feature parity.
