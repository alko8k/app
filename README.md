# Recovrd

A daily recovery score for iPhone. Recovrd reads sleep, steps and workouts from Apple Health, adds a few daily check-ins (water, stretching, late coffee…), and turns them into one score with a plain-English breakdown and a single tip for tomorrow.

All health data stays on the device. There is no backend and no account.

## Features

- **Onboarding**: goals, sleep rhythm, training days and check-in picks, with a live score preview
- **Today**: score ring, per-pillar breakdown and one-tap check-ins
- **Trends**: weekly history and what is moving your sleep
- **Reminders**: morning and evening notifications, plus a reminder before the trial ends
- **Subscription**: monthly plan with a 7-day free trial, through Apple IAP and RevenueCat

## Tech stack

| | |
|---|---|
| UI | SwiftUI, iOS 17+ |
| Storage | SwiftData (on-device) |
| Health | HealthKit (read-only in release builds, background delivery) |
| Purchases | [RevenueCat](https://www.revenuecat.com) |
| Analytics | [PostHog](https://posthog.com) (no health data is ever sent) |
| Project | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`) |

## Getting started

```sh
brew install xcodegen
xcodegen generate
open Recovrd.xcodeproj
```

Run the **Recovrd** scheme. Debug builds use `Recovrd/Recovrd.storekit`, so you can test purchases in the simulator without App Store Connect.

### Configuration

Set these in `project.yml` under `targets.Recovrd.settings.base`, then run `xcodegen generate` again:

| Setting | Purpose |
|---|---|
| `DEVELOPMENT_TEAM` | Apple Developer Team ID, needed to sign for device or TestFlight |
| `REVENUECAT_API_KEY` | Public RevenueCat iOS key. If it's empty, purchases are disabled |
| `POSTHOG_API_KEY` | Public PostHog project key. If it's empty, analytics are off |

RevenueCat expects an entitlement called `premium` and a **current** offering with a **monthly** package for `com.egeatar.recovrd.monthly`.

### Debug launch arguments

Add these in *Scheme → Run → Arguments*:

| Argument | Effect |
|---|---|
| `-resetOnboarding` | Wipes the profile and records |
| `-onboardingDone` | Skips onboarding |
| `-skipPaywall` | Treats the user as subscribed |
| `-fakeRecords` | Inserts 3 weeks of sample days (for screenshots) |
| `-tab <n>` | Opens on tab 0 (Today), 1 (Trends) or 2 (Settings) |

Settings also has a **Debug** section that can seed sample Apple Health data in the simulator.

## Tests

```sh
xcodebuild test -project Recovrd.xcodeproj -scheme Recovrd \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

The tests cover the scoring engine, explanations and sleep-interval merging.

## Project layout

```
Recovrd/
  App/           entry point, routing, analytics, notifications
  Onboarding/    onboarding steps
  Today/         home screen and breakdown
  Trends/        history charts
  Settings/      settings screen
  Paywall/       paywall and RevenueCat wrapper
  Scoring/       scoring engine and explanations (pure Swift, unit tested)
  Health/        HealthKit queries and the SwiftData sync layer
  Models/        SwiftData models
  DesignSystem/  theme, score ring, haptics
RecovrdTests/    unit tests
```

## Privacy

See [PRIVACY.md](PRIVACY.md).
