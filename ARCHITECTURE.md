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
| **dame** | DeviceActivityMonitor | Moderate | Threshold/interval events only | ✅ | ❌ |
| **shconf** | ShieldActionDelegate | Strict | ❌ | ✅ (limited) | ❌ |
| **shconfig** | ShieldConfigurationDataSource | Strict | ❌ | ❌ | ❌ |
| **report** | DeviceActivityReportExtension | Strictest | ✅ Full | ❌ (silent fail on device) | ❌ |

The big surprise: **report extensions can read everything but write nothing**.
Apple's privacy-by-design means usage data renders inside the report
extension's view but cannot be exfiltrated, not via UserDefaults, not via
shared files, not via Core Data, not via networking. The only data path out
is rendering to the screen.

---

## Lessons Learned (and why we ditched usage tracking)

### 1. iOS event limit is ~20 per schedule
`DeviceActivityCenter.startMonitoring()` accepts a dictionary of events but
silently rejects the entire schedule if you exceed ~20 events. We initially
tried 288 events (every 5 min for 24 hours), none of them fired.

### 2. Report extension cannot share data with main app
`DeviceActivityReport` extensions are sandboxed harder than monitor extensions.
Writing to app group UserDefaults appears to work in the simulator but
silently fails on device.

### 3. iOS 26.4's `DeviceActivityData.activityData()` is sandboxed
The new public API in iOS 26.4 lets you query usage from "anywhere" except
the main app. Calling it from the main app fails with sandbox restriction
error 159.

### 4. iOS resets the usage counter on every `startMonitoring` call
Calling `startMonitoring` with the same activity name resets the internal
counter to zero. Events fire based on usage from the restart point, not
from midnight. This made any restart-based tracking lose data.

### 5. Sliding window tracking lost data on every app launch
We initially built a sliding window with offset re-registration in the dame
extension. It worked in theory but each restart of monitoring (from app
launch, settings stepper, etc.) created a 1-4 minute blind spot where iOS
hadn't fired the next milestone yet. Cumulative undercounts of 9+ minutes
were common.

### 6. The DeviceActivityReport view IS accurate
The report extension renders accurate usage data on the dashboard. We can
display it but cannot extract the underlying numbers. So instead of trying
to mirror the data, we now treat the report card as the source of truth
for usage display.

### 7. ExtensionKit extensions live in `Extensions/`, not `PlugIns/`
The report extension is an ExtensionKit extension. Build setting:
`EXTENSIONKIT_EXTENSION_POINT_IDENTIFIER = com.apple.deviceactivityui.report-extension`
Embed phase needs `dstSubfolderSpec = 16` and `dstPath = $(EXTENSIONS_FOLDER_PATH)`.

### 8. The shield extension can't open the parent app
`ShieldActionResponse` only supports `.defer`, `.close`, or `.none`. The
cleanest UX is `.close` plus a notification telling the user to open
MathBlocker themselves.

### 9. SwiftData migrations are unforgiving
Adding a property to a `@Model` class without a migration plan crashes the
app on next launch with `loadIssueModelContainer`. Delete and reinstall
during development.

### 10. LaTeX rendering: SwiftMath, not LaTeXSwiftUI
We migrated off LaTeXSwiftUI (MathJax under the hood, heavy first-render cost,
unreliable for our subset) to SwiftMath (native CoreText renderer). SwiftMath
1.7.3 has two gotchas worth remembering:

- **`MTMathUILabel` inherits `UIView.sizeThatFits(_:)` unchanged.** The
  library's real sizing flows through `intrinsicContentSize` (which calls
  its internal `_sizeThatFits(CGSizeZero)` with the parsed math list).
  SwiftUI wrappers must read `intrinsicContentSize`, not `sizeThatFits(...)`,
  or every math label renders at 0pt wide.
- **`MTMathUILabel` sets `layer.isGeometryFlipped = true`**, so
  `layer.render(in:)` produces an upside-down bitmap. When rasterizing to
  a UIImage, translate by height and scale Y by -1 before the render call.
- SwiftMath supports a subset of LaTeX (~237 symbols, 10 environments).
  `MathText.rewriteForSwiftMath(_:)` rewrites common unsupported commands
  (`\dfrac` → `\frac`, `\pmod{n}` → `(\text{mod } n)`, `\begin{array}` →
  `\begin{matrix}`) and `QuestionBank.unsupportedMarkers` filters questions
  using features we can't rewrite (`\begin{tabular}`, `\begin{align*}`,
  `[asy]`, etc.).

### 11. Haptics need pre-warming
`UINotificationFeedbackGenerator()` initializes the haptic engine on first
use, blocking the main thread. Use a single shared instance and call
`prepare()` during splash.

### 12. `@Observable` only tracks STORED properties
`MonitoringManager.earnedTimerEnd` was originally a computed property that
read from `UserDefaults` via `AppGroupConstants.sharedDefaults`. The
`@Observable` macro only instruments stored-property access, so SwiftUI
never saw the dashboard read it — the countdown never appeared even after
`startEarnedTimer` wrote the new end time. Fix: make it a stored property,
populate in `init()` from UserDefaults (direct read, no actor hop from the
non-isolated initializer), and keep the UserDefaults write as the
cross-process source of truth for the extensions.

### 13. `simctl spawn defaults write group.X` lies
`defaults write` via `simctl spawn` writes to the device-level
`/data/Library/Preferences/` plist, not the app group container. The app
reads from `/data/Containers/Shared/AppGroup/<uuid>/Library/Preferences/`,
so the write never takes effect. To inject app group UserDefaults for
testing, write the plist directly at the app group container path. Find
the correct `<uuid>` by looking for `MCMMetadataIdentifier == "group.X"`
in `.com.apple.mobile_container_manager.metadata.plist` under each
`AppGroup/` subdir.

---

## Calendar-Time Earned Timer (current architecture)

After repeated failures with screen-time tracking workarounds, we switched
to calendar-time for earned credit. The user solves problems and gets a
fixed wall-clock window of additional access.

### Two activity schedules

1. **`mathblocker.daily`** (the daily budget)
   - One `DeviceActivityEvent` with `threshold = budgetMinutes`
   - iOS tracks actual screen time of the blocked apps
   - When the threshold fires, dame applies shields
   - Repeats daily, resets at midnight

2. **`mathblocker.earnedTimer`** (the earned timer)
   - A `DeviceActivitySchedule` with explicit start/end DateComponents
     including year, month, day, hour, minute, second
   - `intervalDidEnd` fires at exactly the end time (wall clock)
   - No events, just the schedule's lifecycle callback
   - One-time, doesn't repeat

### Earn flow

1. User solves a session, earns N minutes
2. `MonitoringManager.startEarnedTimer(minutes: N)`:
   - Reads any existing timer end from app group
   - Computes new end = max(now, existing end) + N min (stacks credit)
   - Stops the existing earned timer schedule
   - Registers a new schedule ending at the computed time
   - Removes shields immediately
   - Saves end timestamp to app group for the dashboard countdown
3. iOS holds the schedule in the background
4. At the end time, `intervalDidEnd` fires in dame
5. Dame applies shields, clears the timer end timestamp

### Dashboard countdown

`MonitoringManager.earnedTimerEnd` is a stored `@Observable` property.
`DashboardView.heroSection` reads it during body evaluation, so SwiftUI
tracks the dependency and re-renders when the timer starts, stacks, or
expires. `CountdownView` then ticks `endDate - Date.now` every second
via `Timer.publish`.

On cold start, `MonitoringManager.init()` seeds the stored property from
the app group `UserDefaults` (the cross-process source of truth written by
`startEarnedTimer`). On scene foreground, `refreshFromStorage()` re-reads
the value in case the dame extension modified it while the app was
backgrounded. A one-shot `Timer` scheduled inside `setEarnedTimerEnd(_:)`
clears the stored property automatically at the wall-clock deadline, so
the dashboard flips back to the "earned today" state without a manual
refresh.

Accuracy is exact because we know the target wall-clock time.

### What this gave us

- **Accurate displayed countdown** (no fake math)
- **Simpler code** (~200 lines deleted: cumulative tracking, milestones,
  offsets, sliding window, dame restarts, reconciliation)
- **Reliable** (intervalDidEnd is rock-solid, unlike threshold events)
- **No restart-induced data loss**

### What it cost

- Earned time is wall-clock based, not screen-time based. If the user
  earns and then puts the phone down, those minutes are wasted.
- Edge case: if the user earns time before exhausting the daily budget,
  the timer starts immediately even though they could still use their
  budget. Users learn to earn after being blocked.

---

## Shield Activation Flow

1. User picks apps via `FamilyActivityPicker` (stored in app group)
2. User toggles monitoring on, `MonitoringManager.startMonitoring(budget)` runs
3. If `budget <= 0`, shields apply immediately, no monitoring needed
4. Otherwise, register the daily budget schedule and budget event
5. iOS monitors silently in the background
6. Budget threshold fires, dame applies shields via ManagedSettingsStore
7. Dame also enables `dateAndTime.requireAutomaticDateAndTime = true` to
   prevent clock-change bypasses

---

## Earn-and-Unblock Flow

1. User opens MathBlocker (Practice tab is first)
2. Solves N math problems, earns `correctAnswers * minutesPerCorrect`
3. On session complete (`ChallengeViewModel.advance()`):
   - Saves stats to SwiftData
   - Calls `MonitoringManager.startEarnedTimer(minutes: earned)`
4. Earned timer starts immediately, shields drop
5. Countdown ticks down on the dashboard
6. After N wall-clock minutes, dame's `intervalDidEnd` re-applies shields
7. User earns more if they want to keep going

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
│   ├── ScreenTime/
│   │   ├── AppGroupConstants.swift  # Shared keys
│   │   ├── AuthorizationManager.swift  # FamilyControls auth
│   │   ├── SelectionManager.swift   # FamilyActivitySelection persistence
│   │   ├── MonitoringManager.swift  # Daily budget + earned timer
│   │   └── ShieldManager.swift      # Observable ManagedSettingsStore wrapper
│   ├── ViewModels/
│   │   └── ChallengeViewModel.swift # Practice session logic
│   ├── Views/                        # SwiftUI screens
│   ├── Components/
│   │   ├── ChoiceButton.swift
│   │   ├── StatCard.swift
│   │   ├── FrostedBackground.swift
│   │   ├── MathText.swift           # SwiftMath wrapper + inline math rasterizer
│   │   ├── ShimmerView.swift
│   │   └── CountdownView.swift      # Live countdown for earned timer
│   ├── Utilities/
│   │   ├── Theme.swift              # Colors, fonts, shadow tokens
│   │   └── Haptics.swift            # Pre-warmed feedback generators
│   └── Resources/
│       ├── questions.json           # Bundled hendrycks_math (1.8 MB)
│       └── rationales.json
├── dame/                             # DeviceActivityMonitor extension
│   └── DeviceActivityMonitorExtension.swift  # Budget event + earned timer end
├── shconf/                           # ShieldActionDelegate extension
├── shconfig/                         # ShieldConfigurationDataSource extension
└── report/                           # DeviceActivityReport extension (ExtensionKit)
    ├── UsageReportExtension.swift
    ├── TotalUsageScene.swift
    ├── UsageReportView.swift
    └── ReportModels.swift
```

---

## App Group UserDefaults Keys

| Key | Writer | Reader | Purpose |
|-----|--------|--------|---------|
| `activitySelection` | Main app | Dame, shconf, shconfig | FamilyActivitySelection JSON |
| `dailyBudgetMinutes` | Main app | Dame | Current budget |
| `isMonitoring` | Main app | (display only) | Monitoring toggle state |
| `earnedTimerEnd` | Main app | Dame, Main app | Wall-clock end of active earned timer |
| `extensionLog` | Dame | Main app debug | Diagnostic log |
| `lastWarningTimestamp` | Dame | Dame | Notification debounce |

---

## Build Configuration Notes

- **Deployment target:** iOS 26.0
- **Entitlements:** `com.apple.developer.family-controls` on main app + dame
  + shconf + shconfig + report
- **App group:** `group.andyjphu.mathblocker` shared by all targets
- **Custom font:** `InstrumentSerif-Regular.ttf` registered via
  `Info.plist UIAppFonts`
- **Package dependencies:** `SwiftMath` (native CoreText renderer; see
  Lesson #10 for caveats)
