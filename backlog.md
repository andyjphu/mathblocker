# MathBlocker Backlog

## Live Activities (TOP PRIORITY)
Persistent lock screen + Dynamic Island widget showing time remaining.
Users see their countdown without opening the app. Biggest differentiator.

- [ ] ActivityKit extension target
- [ ] Lock screen widget: "42 min remaining" with live countdown via `timerInterval`
- [ ] Dynamic Island compact/expanded views
- [ ] Start Live Activity when monitoring begins, end when shields go up
- [ ] Update on session complete (earned minutes change the countdown)
- [ ] "Solve to earn more" CTA in expanded view

**Why this matters:** No competitor does this well. It's the single most visible
feature Apple offers for this kind of app. Users see their time ticking down
on every glance at their phone.

## Platform Features

### High Priority
- [x] `dateAndTime.requireAutomaticDateAndTime` — prevents clock-change bypass (added)
- [x] `eventWillReachThresholdWarning` — "5 minutes left" notification (added)
- [ ] **App Intents + Siri** — "Hey Siri, how much screen time do I have left?" / "Start math challenge"
- [ ] **Control Center widget** — one-tap "Block Now" or "Start Challenge" (ControlWidgetButton)
- [ ] **Home screen widget** — time remaining, streak, questions solved (WidgetKit)
- [ ] **Focus Filters** — auto-enable blocking when "Study" Focus turns on (FocusFilterIntent)
- [ ] `denyAppRemoval` — prevent deleting MathBlocker to bypass it

### Medium Priority
- [ ] `webContent.blockedByFilter` — block Safari browsing too, not just apps
- [ ] `intervalWillStartWarning`/`intervalWillEndWarning` — notify at day reset boundaries
- [ ] **BGTaskScheduler** — periodic background check if budget expired while backgrounded

### Low Priority / Situational
- [ ] `application.denyAppInstallation` — prevent installing alternative apps
- [ ] `account.lockAccounts` — prevent signing out to bypass
- [ ] `passcode.lockPasscode` — prevent changing device passcode
- [ ] `siri.denySiri` — prevent Siri workarounds
- [ ] `gameCenter.denyMultiplayerGaming` — restrict game features

## Content & Questions
- [ ] More question datasets (SAT/ACT-style, better English)
- [ ] LaTeX rendering improvements (LaTeXSwiftUI integrated, needs more LaTeX-formatted packs)
- [ ] Pack download progress indicator (show MB downloaded)
- [ ] Rationales per-pack (currently cleared after bundle slim)
- [ ] Difficulty calibration across datasets
- [ ] Filter out non-English or poorly-worded questions from AQUA-RAT

## Competitive Intel
- **ScreenZen** — escalating delays + math problems. Direct competitor.
- **one sec** — uses Shortcuts automations (not Screen Time API) to intercept app launches.
- **Opal** — Focus Filters + Shortcuts. Uses local push notifications for shield→app navigation.
- **1Question / Quiz Screen** — same concept: block apps until educational questions answered.

## Known iOS 26 Bugs
- `eventDidReachThreshold` sometimes fires immediately (FB14082790)
- Corrupted usage data (FB14237883)
- Random token generation in ShieldConfigurationDataSource (FB18794535)
- Users can revoke Family Controls in Settings with no passcode protection
