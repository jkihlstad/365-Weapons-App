# Build Instructions for TestFlight

## Prerequisites

1. **Apple Developer Account** (paid $99/year)
2. **Xcode 15+** installed
3. **Valid signing certificate** and provisioning profile
4. **App ID created** in Apple Developer portal with:
   - Bundle ID: `com.weapons365.admin`
   - Associated Domains capability enabled

## Step 1: Configure Signing

1. Open `365WeaponsAdmin.xcodeproj` in Xcode
2. Select the project in navigator
3. Select "365WeaponsAdmin" target
4. Go to "Signing & Capabilities" tab
5. Check "Automatically manage signing"
6. Select your Team
7. Ensure Bundle Identifier is `com.weapons365.admin`

## Step 2: Update Version & Build Numbers

1. Select project > General tab
2. Update **Version** (e.g., 1.0.0)
3. Update **Build** (increment for each upload, e.g., 1, 2, 3...)

## Step 3: Create Archive

1. Select **Any iOS Device (arm64)** as build target (not a simulator)
2. Menu: **Product > Archive**
3. Wait for archive to complete
4. Organizer window will open automatically

## Step 4: Validate Archive

1. In Organizer, select the new archive
2. Click **Validate App**
3. Select distribution options:
   - App Store Connect
   - Upload
4. Select your team
5. Let Xcode manage signing
6. Click **Validate**
7. Fix any issues if validation fails

## Step 5: Upload to App Store Connect

1. In Organizer, click **Distribute App**
2. Select **App Store Connect**
3. Select **Upload**
4. Select your team
5. Let Xcode manage signing
6. Review and click **Upload**
7. Wait for upload to complete

## Step 6: Configure in App Store Connect

1. Go to https://appstoreconnect.apple.com
2. My Apps > 365 Weapons Admin
3. Select the build from TestFlight section
4. Add Export Compliance info (see EXPORT_COMPLIANCE.md)
5. Add Test Information for reviewers

## Step 7: Submit for TestFlight Review

1. In App Store Connect > TestFlight
2. Select the build
3. Click "Submit for Beta App Review" (if required)
4. Wait for approval (usually 24-48 hours)

## Step 8: Invite Testers

### Internal Testers (up to 100):
- Add via App Store Connect
- No review required
- Immediate access after build processing

### External Testers (up to 10,000):
- Requires Beta App Review
- Can create public link
- Or invite via email

## Troubleshooting

### "No accounts with App Store Connect access"
- Ensure your Apple ID has App Store Connect access
- Accept any pending agreements at developer.apple.com

### "No matching provisioning profile"
- Enable "Automatically manage signing"
- Or manually create profile in developer portal

### "App ID not found"
- Create App ID in developer portal first
- Use exact bundle ID: `com.weapons365.admin`

### Build stuck processing
- Usually takes 15-30 minutes
- Can take up to 24 hours for first build
- Check App Store Connect status page

## Command Line Alternative

```bash
# Clean build
xcodebuild clean -scheme 365WeaponsAdmin

# Archive
xcodebuild archive \
  -scheme 365WeaponsAdmin \
  -archivePath ./build/365WeaponsAdmin.xcarchive

# Export for App Store
xcodebuild -exportArchive \
  -archivePath ./build/365WeaponsAdmin.xcarchive \
  -exportPath ./build/AppStore \
  -exportOptionsPlist ExportOptions.plist
```
