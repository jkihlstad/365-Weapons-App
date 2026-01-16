# 365Weapons iOS Admin - Local Configuration

## TestFlight Deployment

- **Current Version**: 1.2
- When pushing a new version to TestFlight, increment the version by 0.1 (e.g., 1.2 → 1.3 → 1.4)
- Always increment the build number as well (use `agvtool new-version -all <number>`)

## Simulator Testing

- The iOS simulator does NOT hot-reload - must relaunch after every code change
- Steps to test changes:
  1. Build: `xcodebuild -project 365WeaponsAdmin.xcodeproj -scheme 365WeaponsAdmin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' build`
  2. Terminate: `xcrun simctl terminate booted com.weapons365.admin`
  3. Install: `xcrun simctl install booted <path-to-app>`
  4. Launch: `xcrun simctl launch booted com.weapons365.admin`

## Bundle ID

- Bundle ID: `com.weapons365.admin`
- Team ID: `D33FTL28LK`

## CLI Only

- Do NOT use Xcode GUI - only use CLI commands for building, testing, and deploying
