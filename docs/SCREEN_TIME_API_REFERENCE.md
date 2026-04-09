# Screen Time API Reference

Quick reference for the Screen Time frameworks used by MathBlocker.

---

## Authorization (FamilyControls)

```swift
import FamilyControls

// Request authorization (individual self-restriction, iOS 16+)
try await AuthorizationCenter.shared.requestAuthorization(for: .individual)

// Check status
let status = AuthorizationCenter.shared.authorizationStatus
// .approved, .denied, .notDetermined
```

- Prompts system alert + Face ID/Touch ID/passcode on first call
- Silently succeeds if already authorized
- User can revoke in Settings > Screen Time > Apps with Screen Time Access

---

## App Selection (FamilyActivityPicker)

```swift
import FamilyControls

@State private var selection = FamilyActivitySelection()
@State private var showingPicker = false

// Present picker
.familyActivityPicker(isPresented: $showingPicker, selection: $selection)

// Access tokens (opaque — cannot inspect which app they represent)
selection.applicationTokens    // Set<ApplicationToken>
selection.categoryTokens       // Set<ActivityCategoryToken>
selection.webDomainTokens      // Set<WebDomainToken>

// Persist to App Group (FamilyActivitySelection is Codable)
let data = try JSONEncoder().encode(selection)
UserDefaults(suiteName: "group.andyjphu.mathblocker")?.set(data, forKey: "activitySelection")
```

---

## Applying Shields (ManagedSettings)

```swift
import ManagedSettings

// Named store (persists across app launches and reboots)
let store = ManagedSettingsStore(named: .init("mathblocker.session"))

// Block specific apps
store.shield.applications = selection.applicationTokens

// Block app categories
store.shield.applicationCategories = .specific(selection.categoryTokens)

// Block web domains
store.shield.webDomains = selection.webDomainTokens

// Remove all shields
store.clearAllSettings()

// Remove specific shields
store.shield.applications = nil
```

- Shields persist even if app is killed or device restarts
- Max 50 named stores
- Set-and-forget: iOS enforces automatically

---

## Usage Monitoring (DeviceActivity)

### Scheduling from Main App

```swift
import DeviceActivity

let center = DeviceActivityCenter()
let activityName = DeviceActivityName("mathblocker.daily")
let eventName = DeviceActivityEvent.Name("mathblocker.threshold")

let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd: DateComponents(hour: 23, minute: 59),
    repeats: true,
    warningTime: DateComponents(minute: 5)
)

let event = DeviceActivityEvent(
    applications: selection.applicationTokens,
    categories: selection.categoryTokens,
    threshold: DateComponents(minute: 30) // 30 min daily budget
)

try center.startMonitoring(activityName, during: schedule, events: [eventName: event])

// Stop all monitoring
center.stopMonitoring()
```

### DeviceActivityMonitor Extension

```swift
import DeviceActivity
import ManagedSettings

class MathBlockerMonitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore(named: .init("mathblocker.session"))

    override func intervalDidStart(for activity: DeviceActivityName) {
        // Monitoring period started (e.g., start of day)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        // Monitoring period ended — reset shields
        store.clearAllSettings()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                          activity: DeviceActivityName) {
        // Usage budget exhausted — apply shields
        let selection = loadSelectionFromAppGroup()
        store.shield.applications = selection.applicationTokens
    }
}
```

- Extension runs in a separate sandboxed process
- No network access, no UI, ~100MB RAM
- Communicate with main app only via App Group shared storage

---

## Shield Customization (ManagedSettingsUI)

### ShieldConfigurationDataSource Extension

```swift
import ManagedSettingsUI

class ShieldConfig: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            icon: UIImage(systemName: "brain.head.profile"),
            title: .init(text: "Time's Up", color: .label),
            subtitle: .init(text: "Solve a math problem to earn more time", color: .secondaryLabel),
            primaryButtonLabel: .init(text: "Solve to Unlock", color: .white),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: .init(text: "Stay Focused", color: .systemBlue)
        )
    }
}
```

- Static labels and colors only — no custom SwiftUI views
- Separate overrides for `application`, `applicationCategory`, `webDomain`

### ShieldActionDelegate Extension

```swift
import ManagedSettings

class ShieldAction: ShieldActionDelegate {
    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Signal main app to open, then defer
            completionHandler(.defer)
        case .secondaryButtonPressed:
            completionHandler(.none) // Keep shield up
        @unknown default:
            completionHandler(.none)
        }
    }
}
```

- `.defer` temporarily removes shield
- `.none` keeps shield up
- Cannot open URLs directly; use notification or App Group signal as bridge

---

## App Group Setup

All targets must share: `group.andyjphu.mathblocker`

```swift
// Write (main app)
let defaults = UserDefaults(suiteName: "group.andyjphu.mathblocker")
defaults?.set(data, forKey: "activitySelection")

// Read (any extension)
let defaults = UserDefaults(suiteName: "group.andyjphu.mathblocker")
let data = defaults?.data(forKey: "activitySelection")
```

---

## Entitlements Checklist

Each target needs:
- [x] `com.apple.developer.family-controls` (request from Apple)
- [x] App Group: `group.andyjphu.mathblocker`

Main app additionally needs:
- [x] `com.apple.security.application-groups` → `group.andyjphu.mathblocker`

---

## Testing Notes

- **Simulator**: DeviceActivity events NEVER fire. Must use physical device.
- **Development signing**: Entitlement must be in the provisioning profile or API calls silently fail.
- **Quick test**: Apply shields directly via `ManagedSettingsStore` in the main app first (no extensions needed) to verify the entitlement works.
