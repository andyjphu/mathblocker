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
- [ ] **Screen Time passcode prompt** — guide user through setting an iOS Screen Time passcode in onboarding so they can't disable Family Controls authorization. Need to detect if passcode is set and link to Settings app since we can't set it programmatically.

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
- [ ] Pack download progress indicator (show MB downloaded)
- [ ] Rationales per-pack (currently cleared after bundle slim)
- [ ] Difficulty calibration across datasets
- [ ] Filter out non-English or poorly-worded questions from AQUA-RAT

## LaTeX Rendering — Known Issues (verified via LaTeXTestView)

**Working (verified on device):**
- `$..$` inline math, `\[..\]` and `$$..$$` display math
- `\frac`, subscripts/superscripts (including braced `x_{1}^{2}`) — fixed 2026-04-10
- `\sqrt`, `\cdot`, `\times`, `\pm`, `\le`, `\ge`, `\equiv`
- Greek letters (`\alpha`, `\beta`, `\pi`, ...)
- Spacing `\,`, `\;`, `\quad`, `\qquad`
- Delimiters `\left`, `\right`, `\lceil`, `\rceil`, `\lfloor`, `\rfloor`
- `\overline`, `\triangle`, `\angle`, `\text`, `\textbf`
- `\binom`, `\log`, `\sin`/`\cos`/`\tan`, `\sum`, `\prod`
- Environments `aligned`, `cases`, `matrix`, `pmatrix`, `bmatrix`

**Rewritten by `MathText.rewriteForSwiftMath`:**
- `\dfrac`, `\tfrac`, `\cfrac` → `\frac`
- `\pmod{n}` → ` (\text{mod } n)`
- `\begin{array}{col-spec}` → `\begin{matrix}` (drops column spec, lossy but renders)
- `\S` → `\text{§}` (renders as a gap, glyph missing in math font — 1 question affected)

**Filtered out at load time (`QuestionBank.unsupportedMarkers`):**
- `[asy]` (418) — Asymptote vector graphics
- `\begin{align*}` (39) — display env, not supported by SwiftMath
- `\begin{tabular}` (21) — table layouts, too complex
- `\hspace` / `\vspace` (4) — bespoke spacing
- `\stackrel` (2) — stacked symbols
- `\begin{eqnarray*}` (1), `\renewcommand` (1), `\newcommand` (0), `\includegraphics` (0), `\begin{align}` (0)
- **Total dropped: 486 of 5136 bundled. Remaining usable: 4650 (~90.5%)**

**Still to evaluate:**
- [ ] `\operatorname` (2) and `\mbox` (8) — could be rewritten to `\mathrm` and `\text` respectively

### Root cause: zero-width MathLabel bug (fixed 2026-04-10)

`MTMathUILabel` inherits `UIView.sizeThatFits(_:)` unchanged — the default UIKit
implementation returns `bounds.size` (zero for a freshly-created view). SwiftMath's
real sizing is exposed via `intrinsicContentSize` (which calls the library's internal
`_sizeThatFits(CGSizeZero)` with the parsed math list). Our SwiftUI wrapper in
`MathText.swift` was calling `uiView.sizeThatFits(...)` and reporting zero width to
SwiftUI, so every math label rendered at 0pt wide even when the LaTeX parsed fine.

Fix: in `MathLabel.sizeThatFits(_:uiView:context:)`, read `intrinsicContentSize`
directly and call `invalidateIntrinsicContentSize()` in `updateUIView` so the new
size is picked up when the latex string changes in place.

### Inline math flow (fixed 2026-04-10)

Mixed prose + inline math was being rendered in a `VStack`, so a question like
"If $f(x) = 4-3x$ and $g(x) = x^2+1$, find $f(g(\sqrt{2}))$." came out with every
segment on its own line. `MathText.body` now rasterizes each inline math segment
to a `.alwaysTemplate`-mode `UIImage` via `renderInlineMathImage(latex:)` and
concatenates text + image runs into a single `Text`, which SwiftUI wraps and
aligns naturally. Display math (`\[..\]`, `$$..$$`) still uses `MathLabel` on
its own row via `blockLayout`.

Two gotchas worth knowing:
1. `MTMathUILabel` sets `layer.isGeometryFlipped = true`, so
   `layer.render(in:)` produces an upside-down image. Fixed by flipping the
   CG context before rendering (translate by height, scale Y by -1).
2. Latin Modern Math has smaller x-height than SF Pro at the same point size,
   so we render at `fontSize × 1.3` to visually match surrounding body text.

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
