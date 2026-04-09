# MathBlocker - Project Overview

## App Concept

MathBlocker is a self-restriction iOS app that blocks distracting apps (social media, games, etc.) and requires the user to solve ACT-level math questions to earn screen time back.

### Core Loop

1. User picks which apps to restrict and sets a daily time budget (e.g., 30 min/day for social media)
2. iOS monitors usage in the background via DeviceActivity
3. When the budget is exhausted, a shield overlay blocks the selected apps
4. User taps the shield -> MathBlocker opens with a math challenge
5. Each correctly solved question earns back unlock time (e.g., 2 min per correct answer)
6. Once time expires, the shield re-engages

### Refined Proposal (vs. original "5 questions per 5 min Instagram")

The original idea of "5 ACT questions per 5 minutes of Instagram" would require continuous re-shielding every 5 minutes, which the Screen Time API handles poorly (the DeviceActivityMonitor extension can't do rapid cycles reliably). Instead:

| Aspect | Original | Proposed |
|--------|----------|----------|
| Target apps | Instagram only | User-selected (any apps/categories) |
| Trigger | Every 5 min of use | After daily time budget is exhausted |
| Unlock | Solve 5 questions | Solve N questions, each earns X minutes |
| Re-lock | After 5 more minutes | When earned time expires or next day |

This is more reliable with Apple's APIs and has broader App Store appeal.

---

## Project State

- **Template**: Fresh Xcode SwiftUI + SwiftData project (created 2026-04-09)
- **Bundle ID**: `andyjphu.mathblocker`
- **Team**: Q6YN8K63U3
- **Deployment Target**: iOS 26.4
- **Swift**: 5.0 with Approachable Concurrency (MainActor default isolation)
- **Xcode**: 26.4 (build 17E192)
- **Current files**: Only the default template files (mathblockerApp.swift, ContentView.swift, Item.swift, test stubs)

---

## Architecture

### Targets Required

```
mathblocker (Main App)
├── Authorization & onboarding
├── FamilyActivityPicker (app selection)
├── Math question engine
├── Settings (time budgets, difficulty)
├── Progress/stats dashboard
└── Shield unlock flow

MathBlockerMonitor (Device Activity Monitor Extension)
├── intervalDidStart → optionally apply shields
├── eventDidReachThreshold → apply shields when budget used
└── intervalDidEnd → reset for next day

MathBlockerShieldConfig (Shield Configuration Extension)
├── Custom shield appearance (title, subtitle, buttons)
└── Branded look matching main app

MathBlockerShieldAction (Shield Action Extension)
├── Primary button → .defer, trigger app open via URL scheme
└── Secondary button → .none (stay focused)
```

### Shared Infrastructure

All targets share an **App Group** (`group.andyjphu.mathblocker`) for:
- `FamilyActivitySelection` (which apps are restricted)
- User settings (time budgets, question count)
- Session state (remaining earned time, questions answered today)

### Data Flow

```
Main App                          Extensions
────────                          ──────────
Write settings ──→ App Group ←── Read settings
Write selection ─→ App Group ←── Read selection
Clear shields ───→ ManagedSettingsStore
                                  Apply shields ──→ ManagedSettingsStore
                                  Custom UI ──────→ ShieldConfiguration
                                  Handle taps ────→ ShieldAction (.defer)
```

---

## Frameworks

| Framework | Purpose |
|-----------|---------|
| **FamilyControls** | Authorization, FamilyActivityPicker, opaque app tokens |
| **DeviceActivity** | Usage monitoring, threshold callbacks |
| **ManagedSettings** | Apply/remove app shields |
| **ManagedSettingsUI** | Customize shield overlay appearance |
| **SwiftUI** | All UI |
| **SwiftData** | Persist question history, stats, streaks |

---

## Key Constraints

### Entitlement Required FIRST
- Must request `com.apple.developer.family-controls` from Apple (Account Holder)
- Every target (app + 3 extensions) needs its own entitlement + provisioning profile
- **Cannot test on simulator** - DeviceActivity only fires on physical devices
- Without the entitlement, all API calls silently fail

### Extension Sandbox Limits
- DeviceActivityMonitor extension: no network, no UI, ~100MB RAM limit
- ShieldConfiguration extension: static labels/colors only, no custom SwiftUI views
- ShieldAction extension: cannot open URLs directly; must use `.defer` + notification/URL scheme bridge
- All extensions communicate with the main app only through App Group shared storage

### Known iOS Bugs (as of April 2026)
- `eventDidReachThreshold` can fire immediately without usage on iOS 26+
- `DeviceActivityMonitor` extension sometimes never wakes on iOS 26.3.1
- `FamilyActivityPicker` crashes when searching
- Token rotation: shield extensions may receive tokens that don't match stored ones
- Device restart creates 30-60 second window where shields don't enforce

### Self-Restriction Bypass
- Users can disable the app in Settings > Screen Time > Apps with Screen Time Access
- On iOS 26.4+: if user has a Screen Time Passcode, disabling requires that passcode
- Onboarding should strongly encourage setting a Screen Time Passcode

---

## Screen Flow (MVP)

```
┌─────────────────┐
│   Onboarding    │
│  1. Welcome     │
│  2. Authorize   │──→ FamilyControls .individual auth
│  3. Pick Apps   │──→ FamilyActivityPicker
│  4. Set Budget  │──→ Daily time limit (e.g., 30 min)
│  5. Screen Time │──→ Prompt to set Screen Time Passcode
│     Passcode    │
└────────┬────────┘
         │
┌────────▼────────┐
│   Dashboard     │
│  - Time used    │
│  - Time left    │
│  - Questions    │
│    solved today │
│  - Streak       │
└────────┬────────┘
         │
    [Budget hit]
         │
┌────────▼────────┐
│  Shield Screen  │──→ "Solve to Unlock" / "Stay Focused"
│  (system overlay│
│   via extension)│
└────────┬────────┘
         │ [Solve to Unlock tapped]
         │
┌────────▼────────┐
│  Math Challenge │
│  - ACT question │
│  - Multiple     │
│    choice       │
│  - Timer        │
│  - Progress bar │
└────────┬────────┘
         │ [All correct]
         │
┌────────▼────────┐
│  Unlock!        │
│  +10 min earned │──→ Shield removed, monitoring restarts
│  Celebration    │
└─────────────────┘
```

---

## Math Question Engine

### ACT Math Topics (by difficulty tier)

**Tier 1 - Pre-Algebra (Easy)**
- Basic arithmetic, fractions, decimals, percentages
- Ratios and proportions
- Absolute value, exponents

**Tier 2 - Elementary Algebra (Medium)**
- Linear equations, inequalities
- Systems of equations
- Quadratic factoring

**Tier 3 - Intermediate Algebra (Hard)**
- Quadratic formula, complex numbers
- Logarithms, sequences
- Polynomial operations

**Tier 4 - Coordinate Geometry**
- Distance, midpoint, slope
- Graphing lines and parabolas
- Circle equations

**Tier 5 - Trigonometry**
- SOH-CAH-TOA
- Unit circle values
- Trig identities

### Question Format
- Multiple choice (4 options, matching ACT format)
- Procedurally generated where possible (infinite supply)
- Static curated bank for complex word problems
- Adaptive difficulty based on user performance

---

## Implementation Order

### Phase 0: Prerequisites
- [ ] Request Family Controls entitlement from Apple
- [ ] Set up App Group capability on all targets
- [ ] Create the 3 extension targets in Xcode

### Phase 1: Core Blocking (MVP)
- [ ] Authorization flow (FamilyControls .individual)
- [ ] FamilyActivityPicker for app selection
- [ ] ManagedSettingsStore shield apply/remove
- [ ] DeviceActivityMonitor extension with threshold
- [ ] ShieldConfiguration extension (branded overlay)
- [ ] ShieldAction extension (bridge to main app)

### Phase 2: Math Engine
- [ ] Question data model (SwiftData)
- [ ] Procedural question generator (Tier 1-2)
- [ ] Challenge UI (question, choices, timer)
- [ ] Answer validation and time earning logic

### Phase 3: Polish
- [ ] Onboarding flow
- [ ] Dashboard with usage stats
- [ ] Streak tracking
- [ ] Haptic feedback and animations
- [ ] App icon and branding
- [ ] Dark mode

### Phase 4: Advanced
- [ ] Curated question bank (Tier 3-5)
- [ ] Adaptive difficulty
- [ ] Daily/weekly reports
- [ ] Widget showing time remaining
- [ ] Shortcuts integration
