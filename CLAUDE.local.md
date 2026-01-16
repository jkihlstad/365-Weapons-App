# 365Weapons iOS Admin - Local Configuration

## TestFlight Deployment

- **Current Version**: 1.5
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

## SwiftUI Theming Best Practices

### Color Assets
- All theme colors are in `Assets.xcassets` with "Any Appearance" and "Dark Appearance" variants
- Color tokens: AppBackground, AppSurface, AppSurface2, AppTextPrimary, AppTextSecondary, AppBorder, AppAccent, AppAccentBackground, AppDanger, AppSuccess, AppWarning
- Access via `Color.appBackground`, `Color.appSurface`, etc. (defined in `Utils/ThemeColors.swift`)

### Theme Rules
1. **NO hardcoded colors** - Never use `Color.white`, `Color.black`, or hex colors in views
2. **Root-only preferredColorScheme** - Apply `.themeRoot()` only at WindowGroup level in App
3. **Every screen needs background** - Use `.themedBackground()` on every screen root
4. **Lists need special handling** - Use `.themedList()` modifier (scrollContentBackground + background)
5. **No animations on theme change** - Use `.transaction { $0.animation = nil }` at root

### UIKit Appearance
- Navigation bar appearance configured in `AppearanceManager.updateUIKitAppearance()`
- Set opaque backgrounds to prevent transparency issues
- UITableView.appearance().backgroundColor = .clear to let SwiftUI control

### Theme Mode Selection
- AppearanceMode enum: `.system`, `.light`, `.dark`
- Stored in UserDefaults key "appearanceMode"
- Default is `.system` to follow iOS settings

### Preventing White Flash
- Launch screen should use system background color
- All initial views must have proper backgrounds applied
