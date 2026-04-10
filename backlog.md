# MathBlocker Backlog

## Unused Screen Time API Features

### High Priority
- [ ] `dateAndTime.requireAutomaticDateAndTime` — prevent users changing clock to bypass monitoring
- [ ] `eventWillReachThresholdWarning` — "5 minutes left" notification before blocking kicks in
- [ ] `denyAppRemoval` — prevent deleting MathBlocker to bypass it

### Medium Priority
- [ ] `webContent.blockedByFilter` — block Safari browsing too, not just apps
- [ ] `intervalWillStartWarning`/`intervalWillEndWarning` — notify at day reset boundaries

### Low Priority / Situational
- [ ] `application.denyAppInstallation` — prevent installing alternative apps
- [ ] `account.lockAccounts` — prevent signing out to bypass
- [ ] `passcode.lockPasscode` — prevent changing device passcode
- [ ] `siri.denySiri` — prevent Siri workarounds
- [ ] `gameCenter.denyMultiplayerGaming` — restrict game features

## Other Backlog
- [ ] More question datasets (SAT/ACT-style, better English)
- [ ] LaTeX rendering for questions that need it (LaTeXSwiftUI integrated, needs more LaTeX-formatted packs)
- [ ] Pack download progress indicator (show MB downloaded)
- [ ] Rationales per-pack (currently cleared after bundle slim)
- [ ] Difficulty calibration across datasets
