# MathBlocker Architecture

## Core Concept

Block selected apps on iOS until the user solves math problems to earn screen
time. Built on Apple's Screen Time APIs (FamilyControls, ManagedSettings,
DeviceActivity).

---

## Process Map

| Process | Type | Sandbox | Can Read Usage | Can Write App Group | Networking |
|---------|------|---------|----------------|---------------------|------------|
| **mathblocker** | Main app | Standard | ❌ | ✅ | ✅ |
| **dame** | DeviceActivityMonitor | Moderate | Threshold events only | ✅ | ❌ |
| **shconf** | ShieldActionDelegate | Strict | ❌ | ✅ (limited) | ❌ |
| **shconfig** | ShieldConfigurationDataSource | Strict | ❌ | ❌ | ❌ |
| **report** | DeviceActivityReportExtension | Strictest | ✅ Full | ❌ (silent fail on device) | ❌ |

The big surprise: **report extensions can read everything but write nothing**.
Apple's privacy-by-design means usage data renders inside the report
extension's view but cannot be exfiltrated — not via UserDefaults, not via
shared files, not via Core Data, not via networking. The only data path out
is rendering to the screen.

---

## Lessons Learned

### 1. iOS event limit is ~20 per schedule
`DeviceActivityCenter.startMonitoring()` accepts a dictionary of events but
silently rejects the entire schedule if you exceed ~20 events. We initially
tried 288 events (every 5 min for 24 hours) — none of them fired, including
the budget event. Test count: stay under 20.

### 2. Report extension cannot share data with main app
`DeviceActivityReport` extensions are sandboxed harder than monitor extensions.
Writing to app group UserDefaults appears to work in the simulator but
silently fails on device. Confirmed by multiple Apple Developer Forum threads.
The only data source we can rely on is the **monitor extension** writing to
the app group.

### 3. iOS 26.4's `DeviceActivityData.activityData()` is sandboxed
The new public API in iOS 26.4 lets you query usage from "anywhere" — except
the main app. Calling it from the main app fails with:
`Failed to create data access proxy: Sandbox restriction (error 159)`
The entitlement to actually use it appears reserved for Apple's own Screen
Time UI. We can't use it.

### 4. iOS resets the usage counter on every `startMonitoring` call
Calling `startMonitoring` with the same activity name **resets the internal
counter to zero**. Events fire based on usage from the restart point, not
from midnight. We work around this with an "offset" stored in the app group:
each time we restart, we record the cumulative count and add it to subsequent
event values.

### 5. Monitor extensions CAN call `startMonitoring`
Not officially documented but `DeviceActivityCenter` is available in the
extension's process. The dame extension restarts its own monitoring when it
exhausts a tracking window, giving us continuous granular tracking.

### 6. ExtensionKit extensions live in `Extensions/`, not `PlugIns/`
The report extension is an ExtensionKit extension, not the old NSExtension
type. It must be embedded in the app's `Extensions/` folder with
`dstSubfolderSpec = 16`, not `PlugIns/`. The pbxproj needs a separate copy
files build phase. Build setting:
`EXTENSIONKIT_EXTENSION_POINT_IDENTIFIER = com.apple.deviceactivityui.report-extension`

### 7. The shield extension can't open the parent app
`ShieldActionResponse` only supports `.defer`, `.close`, or `.none`. There's
no way to open the parent app from a shield button. The cleanest UX is
`.close` (kicks the user back to home screen) and trust them to open the
math app themselves.

### 8. SwiftData migrations are unforgiving
Adding a property to a `@Model` class without a migration plan crashes the
app on next launch with `loadIssueModelContainer`. During development, just
delete and reinstall. For production, write a `VersionedSchema` migration.

### 9. LaTeX rendering requires care
LaTeXSwiftUI imports MathJax (a JS engine). First render of any LaTeX view
freezes the UI for ~500ms while MathJax cold-starts. Pre-warm during splash
by placing a tiny `LaTeX("$x$")` view in the splash with `frame(width: 1, height: 1)`.
Zero-frame views are skipped by SwiftUI and don't trigger pre-warming.

### 10. Haptics need pre-warming too
`UINotificationFeedbackGenerator()` initializes the haptic engine on first
use, blocking the main thread. Create a single shared instance and call
`prepare()` during splash.

---

## Usage Tracking: Sliding Window + Offset Architecture

Apple gives us no direct way to read usage from the main app. We work around
this with a sliding window of threshold events that the dame extension manages.

### Initial state
- `monitoringOffset = 0` (in app group UserDefaults)
- `cumulativeMinutesUsed = 0` (in app group UserDefaults)
- Schedule registered with events at `[1, 5, 15, 30, 60, 90, 120]` + budget
- 8 events total — well under iOS's ~20 limit

### As user accumulates usage
- iOS fires `usage.1` after 1 minute → dame writes `cumulative = offset(0) + 1 = 1`
- iOS fires `usage.5` after 5 minutes → `cumulative = 5`
- ... continues through `usage.120`

### When dame hits the highest milestone (`usage.120`)
- Dame writes `cumulative = 120`
- Dame calls `restartMonitoringFromCurrentPoint()`:
  - Stops current monitoring (resets iOS counter to 0)
  - Saves `monitoringOffset = 120`
  - Re-registers a fresh schedule with events `[1, 5, 15, 30, 60, 90, 120]`
  - Budget event threshold = `budget - offset` (so it still fires at the right total)

### Subsequent firings
- `usage.5` fires → dame computes `offset(120) + 5 = 125`
- `usage.15` fires → `cumulative = 135`
- ... and so on

The end result: **continuous tracking with 5–30 min granularity, no gaps,
unlimited duration.** Each window costs only 8 events, so we never approach
the iOS limit.

---

## Shield Activation Flow

1. User picks apps via `FamilyActivityPicker` → stored in app group
2. User toggles monitoring on → `MonitoringManager.startMonitoring(budget)`
3. Main app reads `cumulativeMinutesUsed` from app group:
   - If `used >= budget` → apply shields immediately, no monitoring needed
   - Else → register schedule with budget event + tracking events
4. iOS monitors silently in the background
5. Budget threshold fires → dame applies shields via `ManagedSettingsStore`
6. Dame also enables `dateAndTime.requireAutomaticDateAndTime = true` to
   prevent clock-change bypasses

---

## Earn-and-Unblock Flow

1. User opens MathBlocker (Practice tab is first)
2. Solves N math problems → earns `correctAnswers * minutesPerCorrect`
3. On session complete (`ChallengeViewModel.advance()`):
   - Saves stats to SwiftData
   - `ShieldManager.removeShields()` — drops the shields
   - `MonitoringManager.startMonitoring(budgetMinutes: budget + totalEarnedToday)`
   - Dame's offset stays the same; the new budget event has a higher threshold
   - User gets exactly the earned minutes before being blocked again

---

## File Map

```
mathblocker/
├── mathblocker/                     # Main app
│   ├── mathblockerApp.swift         # Entry point, splash → onboarding → main
│   ├── Engine/
│   │   ├── QuestionBank.swift       # Loads bundled + downloaded packs
│   │   ├── RationaleBank.swift      # Loads question explanations
│   │   ├── MathQuestion.swift       # Question model
│   │   ├── PackManager.swift        # R2 download manager
│   │   └── QuestionGenerator.swift  # Procedural fallback
│   ├── Models/                       # SwiftData models
│   │   ├── UserSettings.swift       # Budget, dataset choice, etc.
│   │   ├── DailyStats.swift         # Per-day aggregates
│   │   └── QuestionAttempt.swift    # Per-question history
│   ├── ScreenTime/
│   │   ├── AppGroupConstants.swift  # Shared keys
│   │   ├── AuthorizationManager.swift  # FamilyControls auth
│   │   ├── SelectionManager.swift   # FamilyActivitySelection persistence
│   │   ├── MonitoringManager.swift  # DeviceActivityCenter wrapper
│   │   └── ShieldManager.swift      # ManagedSettingsStore wrapper
│   ├── ViewModels/
│   │   └── ChallengeViewModel.swift # Practice session logic
│   ├── Views/                        # SwiftUI screens
│   ├── Components/                   # Reusable UI
│   │   ├── ChoiceButton.swift
│   │   ├── StatCard.swift
│   │   ├── FrostedBackground.swift
│   │   ├── MathText.swift           # LaTeXSwiftUI wrapper
│   │   └── ShimmerView.swift
│   ├── Utilities/
│   │   ├── Theme.swift              # Colors, fonts, shadow tokens
│   │   └── Haptics.swift            # Pre-warmed feedback generators
│   └── Resources/
│       ├── questions.json           # Bundled hendrycks_math (1.8 MB)
│       └── rationales.json
├── dame/                             # DeviceActivityMonitor extension
│   └── DeviceActivityMonitorExtension.swift  # Threshold events + dynamic restart
├── shconf/                           # ShieldActionDelegate extension
├── shconfig/                         # ShieldConfigurationDataSource extension
└── report/                           # DeviceActivityReport extension (ExtensionKit)
    ├── UsageReportExtension.swift   # Entry point
    ├── TotalUsageScene.swift        # makeConfiguration logic
    ├── UsageReportView.swift        # The view rendered in dashboard
    └── ReportModels.swift           # Lightweight DTOs
```

---

## App Group UserDefaults Keys

| Key | Writer | Reader | Purpose |
|-----|--------|--------|---------|
| `activitySelection` | Main app | Dame, shconf, shconfig | FamilyActivitySelection JSON |
| `dailyBudgetMinutes` | Main app | Dame | Current budget |
| `isMonitoring` | Main app | (display only) | Monitoring toggle state |
| `cumulativeMinutesUsed` | Dame | Main app | Today's tracked usage |
| `usageTrackingDate` | Dame | Dame | Day rollover detection |
| `monitoringOffset` | Dame, Main app | Dame | Sliding window offset |
| `unlockRequestTimestamp` | shconf | (legacy, unused) | Shield→app navigation |
| `extensionLog` | Dame | Main app debug | Diagnostic log |
| `lastWarningTimestamp` | Dame | Dame | Notification debounce |

---

## Build Configuration Notes

- **Deployment target:** iOS 26.0 (need 26.4+ for some adjacent APIs)
- **Entitlements:** `com.apple.developer.family-controls` on main app + dame + shconf + shconfig + report
- **App group:** `group.andyjphu.mathblocker` shared by all targets
- **Custom font:** `InstrumentSerif-Regular.ttf` registered via `Info.plist UIAppFonts`
- **Package dependencies:** `LaTeXSwiftUI` (uses MathJax under the hood)
- **Asset catalog:** `clean-salad`, `dense-fern`, `olive-mountain`, `solo-fern` for backgrounds; `logo`, `logo4xbg` for branding
