# FreeTimeAnalyzer

FreeTimeAnalyzer is a small macOS SwiftUI app that analyzes calendar events and computes "free time" within a chosen work window. It supports selecting calendars, simulating events, and visualizing free slots and fetched events.

## Quick summary
- Language: Swift / SwiftUI
- Frameworks: EventKit
- Pattern: MVVM-like (Views + ViewModels)
- Target: macOS (run from Xcode)

## Project layout
- `ContentView.swift` — Main UI (split view).
- `Views/` — Reusable SwiftUI views (FreeTimePanel, EventsList, etc.).
- `ViewModels/CalendarViewModel.swift` — EventKit wrapper, fetch + compute logic.
- `Models/Item.swift` — Small data model moved to `Models/` (if used later for persistence).
- `Info.plist` — contains `NSCalendarsUsageDescription` (required for Calendar permission).
- `FreeTimeAnalyzer.entitlements` — entitlements file added to allow Calendar access under App Sandbox.
- `FreeTimeAnalyzer.xcodeproj` — Xcode project (build settings updated to reference the entitlements and Info.plist).

## How to run
1. Open the Xcode project: `FreeTimeAnalyzer/FreeTimeAnalyzer.xcodeproj`.
2. Choose the `FreeTimeAnalyzer` scheme and ensure the correct target is selected.
3. Product → Clean Build Folder (optional).
4. Run the app from Xcode (this is important — running from Xcode triggers the system permission prompt which associates the permission with the running bundle).

## Calendar permissions & troubleshooting
If calendar events do not appear or the app does not request permission, try the following steps in order:

1. Confirm the app includes a usage description
   - `Info.plist` includes `NSCalendarsUsageDescription` with a user-facing message. This repository already contains that key.

2. Reset the Calendar permission and restart the TCC daemon
   - Run in Terminal (replace the bundle identifier if different):

```zsh
# reset Calendar permission for this app
# (bundle id in this project: uk.me.soft.FreeTimeAnalyzer)

tccutil reset Calendar uk.me.soft.FreeTimeAnalyzer
# restart tccd
killall tccd
```

3. Run the app from Xcode again and choose "Allow" when the system dialog appears.

4. If the app still does not appear in System Settings → Privacy & Security → Calendars:
   - Make sure you ran the app from Xcode. The system links permission with the running process/bundle.
   - Open the Calendars privacy pane directly:

```zsh
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
```

5. Entitlements and sandboxing
   - The project currently has App Sandbox enabled. An entitlements file (`FreeTimeAnalyzer/FreeTimeAnalyzer/FreeTimeAnalyzer.entitlements`) has been added and wired into the Xcode project. It contains:
     - `com.apple.security.app-sandbox` = true
     - `com.apple.security.personal-information.calendars` = true
   - If you change the bundle identifier or the entitlements file location, update the `CODE_SIGN_ENTITLEMENTS` build setting in the target.

6. Debugging output
   - Use the in-app "Print Calendars (debug)" button (sidebar) and check Xcode's console. The app prints EventKit's visible calendars and any NSError we observe while requesting access.

## How to use the app (UI)
- Left sidebar: date picker, calendar picker (All / specific calendar), work start/end steppers.
- Buttons: "Calculate" (compute free slots), "Simulate" (create a simulated event), "Refresh" and "Print Calendars (debug)".
- Main area: shows computed free slots and the events list for the selected calendar/date.

## Known issues & notes
- If you previously denied permission, macOS won't prompt again until you reset it via `tccutil` or enable the permission in System Settings.
- Running from Finder / double-clicking the built app may behave differently than running from Xcode due to how the system associates the permission with the binary.
- CLI builds on some machines may fail due to non-standard PATH/toolchain (e.g., an unexpected ld on PATH). Building from Xcode avoids this.

## Future plans
- Improve free-time calculation:
  - Merge overlapping events and handle all-day events and recurring events more robustly.
  - Provide multi-day/window analysis and time zone handling.
- Persistence & simulation:
  - Add optional persistence (SwiftData / CoreData) for saved simulated events and presets.
- Calendar selection improvements:
  - Allow filtering by calendar source (Google / Exchange / iCloud) and color-coded UI per calendar.
- Permissions & sandboxing:
  - Provide clearer UI for permission status and in-app quick actions to open System Settings.
- Export & sharing:
  - Export free-time windows as iCal or CSV; add a share sheet.
- Tests & CI:
  - Add unit tests for the free-time algorithm and UI snapshot tests; configure CI to run linters and tests.

## Contributing
- Create a branch, make small, focused commits, and open a PR describing the change and its motivation.

## Contact
- For more help, run the app from Xcode and paste console logs if you hit permission failures — I can help interpret them and propose the next steps.

---
README generated and added to repository by the development assistant.
