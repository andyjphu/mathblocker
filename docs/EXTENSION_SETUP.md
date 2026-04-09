# Extension Setup Guide

The source code for all 3 extensions is written. You need to create the targets in Xcode and configure them.

## Step 1: Create Extension Targets

For each of the 3 extensions, go to **File > New > Target** in Xcode:

### 1. MathBlockerMonitor
- Template: **Device Activity Monitor Extension**
- Product Name: `MathBlockerMonitor`
- Bundle ID: `andyjphu.mathblocker.MathBlockerMonitor`
- Replace the generated Swift file with: `MathBlockerMonitor/MathBlockerMonitor.swift`

### 2. MathBlockerShieldConfig
- Template: **Shield Configuration Extension**
- Product Name: `MathBlockerShieldConfig`
- Bundle ID: `andyjphu.mathblocker.MathBlockerShieldConfig`
- Replace the generated Swift file with: `MathBlockerShieldConfig/ShieldConfigExtension.swift`

### 3. MathBlockerShieldAction
- Template: **Shield Action Extension**
- Product Name: `MathBlockerShieldAction`
- Bundle ID: `andyjphu.mathblocker.MathBlockerShieldAction`
- Replace the generated Swift file with: `MathBlockerShieldAction/ShieldActionExtension.swift`

## Step 2: Add Capabilities to ALL 4 Targets

For each target (main app + 3 extensions):

1. Select the target in Xcode
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **Family Controls**
5. Add **App Groups** → add `group.andyjphu.mathblocker`

## Step 3: Verify Entitlements

Each target should have an `.entitlements` file with:

```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.andyjphu.mathblocker</string>
</array>
```

## Step 4: URL Scheme

In the main app target:
1. Go to **Info** tab
2. Under **URL Types**, add:
   - Identifier: `com.andyjphu.mathblocker`
   - URL Schemes: `mathblocker`

## Step 5: Build & Test

- Extensions cannot be tested on simulator — use a physical device
- Quick test: In Settings, toggle monitoring ON with apps selected
- Use the selected apps until the time budget is hit
- The shield should appear, and tapping "Solve to Unlock" should open the math challenge
