# MathBlocker, Privacy Policy Reference

This document captures everything a privacy policy writer needs to know about how MathBlocker collects, uses, and stores data. Use this as the source of truth when drafting the policy.

## App Concept

MathBlocker is an iOS app that helps users limit their use of distracting apps (Instagram, TikTok, etc.) by blocking those apps once a daily time budget is exceeded. To unblock the apps, users solve math problems. Each correct answer earns a configurable amount of additional screen time.

## Apple Frameworks Used

MathBlocker is built on Apple's Screen Time technology stack:

1. **FamilyControls**, asks the user for permission to monitor and shield apps
2. **ManagedSettings**, applies the actual app/category/web shields
3. **DeviceActivity**, schedules monitoring intervals and listens for usage threshold events
4. **DeviceActivityReportExtension**, renders a usage chart on the dashboard

These APIs require Apple's `com.apple.developer.family-controls` entitlement, which Apple grants only after manual review. The app cannot use them without that approval.

## Data the App Collects

### Stored locally on the device only

- User settings (daily budget, minutes per right answer, questions per session, selected question pack)
- A history of question attempts (the question text, the user's answer, whether it was right, time spent)
- Daily aggregate stats (questions attempted, questions correct, minutes earned)
- The user's app/category selection from `FamilyActivityPicker`, stored as opaque tokens that cannot be used to identify specific apps outside of the Screen Time framework
- A small log file used by the monitoring extension for debugging

All of this is stored in SwiftData (the device's local database) or an App Group container shared between the main app and its extensions. Nothing is uploaded to a server.

### What Apple lets us see

Apple's Screen Time framework is intentionally privacy-restrictive. Even with the Family Controls entitlement granted, the main app process cannot directly read which apps the user opens, when they open them, or for how long. The framework only exposes:

- Opaque application/category/web tokens (which cannot be reversed into app names from the main app)
- Threshold events ("the user has now used the selected apps for X minutes today")
- Usage data inside a sandboxed `DeviceActivityReportExtension`, which renders a SwiftUI view but cannot pass that data back to the main app

### Network requests

The app makes a single type of network request: downloading question packs from `https://cdn.recursn.com/`. These are static JSON files containing math questions. No user identifiers, device identifiers, IP-based identifiers, or analytics are sent with these requests beyond standard HTTP headers. We do not log who downloads what.

## How the Dashboard Reports Usage

This part is important and should be reflected in the privacy policy:

The dashboard has two different views of usage data:

### The hero card (top)

The big numbers at the top of the dashboard ("minutes earned today", "remaining", etc.) are based on data we track ourselves:

- The daily budget is what the user sets in Settings
- The minutes earned come from completed math sessions, recorded locally in SwiftData
- The "remaining" calculation is derived from these two values

**We do not, and cannot, know exactly how many minutes the user has spent on any specific app.** Apple's Screen Time framework hides that data from the main app process. What we do is set up monitoring with usage thresholds, and Apple notifies us when each threshold is crossed. We track those threshold events in the background and use them to estimate when shields should activate. We re-poll and re-register monitoring intelligently as the user's budget or earned time changes, but the exact minute-by-minute usage is never visible to us.

### The usage chart (bottom)

The bar chart and "X hours Y minutes on blocked apps today" line at the bottom of the dashboard is rendered by a separate Apple component called a `DeviceActivityReportExtension`. This extension runs in its own sandboxed process and is the only place where actual minute-accurate usage data is accessible. The extension reads usage data from the system, formats it into a view, and displays it inside the main app. The exact numbers are visible to the user, but the underlying data never leaves the extension's sandbox. The main app process cannot read those numbers either, only the user can see them on screen.

In short: the user sees their accurate usage in the bottom chart, but the app itself does not have access to those numbers.

## Notifications

If the user opts in during onboarding, the app sends a single type of notification: a "five minutes left" warning before their app blocking activates. No other notifications are sent. No notification content includes personal information or specific app names.

## Question Packs and Server Hosting

Question packs are JSON files hosted on Cloudflare R2 at `cdn.recursn.com`. These files contain math questions sourced from publicly available academic datasets (Hendrycks MATH, MMLU, AQUA-RAT, MMLU-Pro, AGIEval). Users can browse and download packs from inside the app. Downloads are anonymous and we do not track which packs each user installs.

## What We Do Not Do

- We do not collect user accounts, emails, names, or any personally identifying information
- We do not use analytics SDKs, crash reporters, or telemetry of any kind
- We do not share data with any third parties
- We do not sell, rent, or transmit user data
- We do not access the camera, microphone, contacts, photos, location, or any other sensor or library
- We do not use advertising identifiers or tracking technologies
- We do not store anything on a server about individual users
- We cannot, even if we wanted to, see which specific apps a user opens or for how long, outside of what the user themselves can see on the dashboard chart

## What the User Controls

- The user picks which apps and categories get blocked using Apple's `FamilyActivityPicker`. We never see the names or icons of those apps in our app code. We only get back opaque tokens that the system uses internally.
- The user can revoke Screen Time authorization at any time from iOS Settings, which will immediately stop all monitoring and blocking.
- The user can delete the app to remove all stored data. SwiftData and the App Group container are wiped on uninstall.
- The user can wipe their stats history from the Settings screen.

## Third Parties

The only third party involved is Cloudflare R2, which hosts our static question pack files at `cdn.recursn.com`. Cloudflare may log standard HTTP request metadata (timestamp, IP address, user agent) per their own privacy policy. We do not access, store, or use any of that data.

## Children and Family Sharing

The app is intended for teenagers and young adults. Family Controls authorization works on individual accounts, not just child accounts in Family Sharing.

## Contact

The app is published by Andy Phu (developer team ID Q6YN8K63U3). Questions about privacy can be directed to the contact information listed in the App Store listing.
