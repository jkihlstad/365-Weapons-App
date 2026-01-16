# Complete TestFlight & App Store Submission Guide
## 365Weapons iOS Admin App

**Generated:** January 15, 2026
**Status:** Ready for action

---

## Quick Status

| Requirement | Status | Action |
|-------------|--------|--------|
| Secrets removed | DONE | DefaultKeys.swift cleared |
| App icons | **MISSING** | Must add 1024x1024 icon |
| Development team | **NOT SET** | Configure in Xcode |
| Privacy policy | CREATED | Upload to website |
| Documentation | DONE | All docs updated |

---

## Master Checklist

### Phase 1: Fix Blockers (Do First)

#### 1.1 Add App Icon (CRITICAL)

The app icon is missing. You need to add it before you can submit.

**Option A: Quick Method (Recommended)**
1. Create or obtain a 1024x1024 PNG image for your app icon
2. Open Xcode project
3. Navigate to `365WeaponsAdmin/Resources/Assets.xcassets/AppIcon.appiconset`
4. Drag your 1024x1024 image into the asset catalog
5. Xcode will auto-generate all required sizes

**Option B: Manual Method**
1. Create icons in these sizes:
   - 1024x1024 (App Store)
   - 180x180 (iPhone @3x)
   - 120x120 (iPhone @2x)
   - 167x167 (iPad Pro @2x)
   - 152x152 (iPad @2x)
2. Add each to `AppIcon.appiconset` folder
3. Update `Contents.json` with file references

**Icon Design Requirements:**
- No transparency (use solid background)
- No rounded corners (iOS adds them)
- PNG format
- sRGB color space

---

#### 1.2 Configure Development Team (CRITICAL)

1. Open `365WeaponsAdmin.xcodeproj` in Xcode
2. Select the project in the Navigator (blue icon)
3. Select target "365WeaponsAdmin"
4. Go to "Signing & Capabilities" tab
5. Check "Automatically manage signing"
6. Select your Team from the dropdown
   - If no team appears, sign in: Xcode → Settings → Accounts → Add Apple ID
7. Wait for Xcode to generate provisioning profile

---

#### 1.3 Rotate Exposed API Keys (IMPORTANT)

Since keys were previously in the code, rotate them as a precaution:

| Service | Action | URL |
|---------|--------|-----|
| OpenRouter | Generate new key | https://openrouter.ai/keys |
| OpenAI | Generate new key | https://platform.openai.com/api-keys |
| Backend Auth | Regenerate token | Your server admin panel |

After rotating, users will need to enter the new keys in the app's Settings.

---

### Phase 2: Upload Privacy Policy

#### 2.1 Publish Privacy Policy to Website

1. Copy content from `PRIVACY_POLICY.md` (created in this repo)
2. Create page at: `https://365weapons.com/privacy`
3. Publish the page
4. Verify it's accessible

**Alternative:** Use a hosted service like:
- Termly (termly.io)
- iubenda (iubenda.com)
- GetTerms (getterms.io)

---

### Phase 3: Apple Developer Setup

#### 3.1 Ensure Apple Developer Membership

1. Go to https://developer.apple.com
2. Sign in with your Apple ID
3. Verify you have an active membership ($99/year)
4. If not enrolled, enroll at: https://developer.apple.com/programs/enroll/

---

#### 3.2 Create App Record in App Store Connect

1. Go to https://appstoreconnect.apple.com
2. Click "My Apps"
3. Click "+" → "New App"
4. Fill in:

| Field | Value |
|-------|-------|
| Platform | iOS |
| Name | 365Weapons Admin |
| Primary Language | English (U.S.) |
| Bundle ID | com.weapons365.admin |
| SKU | 365weapons-admin-001 |
| User Access | Full Access |

5. Click "Create"

---

#### 3.3 Complete App Information

**App Store Connect → Your App → App Information**

| Field | Value |
|-------|-------|
| Subtitle | Manage your firearms business with AI |
| Category | Business |
| Secondary Category | Productivity |
| Content Rights | Does not contain third-party content |
| Age Rating | Complete questionnaire (likely 12+) |

**Privacy Policy URL:**
```
https://365weapons.com/privacy
```

---

#### 3.4 Complete App Privacy Details

**App Store Connect → Your App → App Privacy**

Click "Get Started" and answer:

**Question 1: Do you or your third-party partners collect data?**
→ Yes

**Contact Info:**
- [x] Name - Collected, Linked to User, App Functionality
- [x] Email Address - Collected, Linked to User, App Functionality

**Identifiers:**
- [x] User ID - Collected, Linked to User, App Functionality

**User Content:**
- [x] Audio Data - Collected, NOT Linked to User, App Functionality

**For each data type, confirm:**
- Used for: App Functionality
- Linked to user: Yes (except Audio)
- Used for tracking: No

---

### Phase 4: Build and Archive

#### 4.1 Verify Build Settings

1. Open Xcode project
2. Select scheme: "365WeaponsAdmin"
3. Select destination: "Any iOS Device (arm64)"
4. Product → Build (⌘B) to verify no errors

---

#### 4.2 Increment Build Number (if re-submitting)

If you've submitted before, increment the build number:

**In Xcode:**
1. Select project → Target → General
2. Change Build from "1" to "2"

**Or via command line:**
```bash
cd /Volumes/Backup_500_Rraid/Software/365Weapons-iOS-Admin
agvtool new-version -all 2
```

---

#### 4.3 Create Archive

1. In Xcode, select: Product → Archive
2. Wait for archive to complete (2-5 minutes)
3. Organizer window opens automatically
4. Verify archive appears with correct version

**If Archive is grayed out:**
- Ensure destination is "Any iOS Device" not a simulator
- Ensure signing is configured

---

#### 4.4 Upload to App Store Connect

1. In Organizer, select your archive
2. Click "Distribute App"
3. Select "App Store Connect" → Next
4. Select "Upload" → Next
5. Keep default options:
   - [x] Upload your app's symbols
   - [x] Manage Version and Build Number
6. Click "Next"
7. Review summary → Click "Upload"
8. Wait for upload to complete (5-15 minutes)

---

#### 4.5 Verify Upload in App Store Connect

1. Go to App Store Connect → Your App → TestFlight
2. Wait for build processing (10-30 minutes)
3. Status changes: "Processing" → "Ready to Submit"
4. If issues found, fix and re-upload with incremented build number

---

### Phase 5: Export Compliance

#### 5.1 Answer Encryption Questions

When build finishes processing, App Store Connect will ask:

**"Does your app use encryption?"**
→ Yes

**"Does your app qualify for any exemptions?"**
→ Yes

Select:
- [x] Uses only standard iOS encryption (HTTPS/TLS)
- [x] Uses encryption for authentication only
- [x] Uses encryption for data protection (Keychain)

This qualifies for mass market exemption - no ERN required.

---

### Phase 6: TestFlight Setup

#### 6.1 Add Test Information

**App Store Connect → TestFlight → Test Information**

| Field | Value |
|-------|-------|
| Beta App Description | Admin dashboard for 365Weapons store management. Manage orders, products, vendors, and use AI-powered chat assistance. |
| Feedback Email | support@365weapons.com |
| Privacy Policy | https://365weapons.com/privacy |
| Marketing URL | https://365weapons.com (optional) |

---

#### 6.2 Create Internal Testing Group

1. TestFlight → Internal Testing → Click "+"
2. Name: "Admin Team"
3. Add testers (must be App Store Connect users)
4. Enable automatic distribution (optional)
5. Click "Create"

---

#### 6.3 Add Build to Testing Group

1. Select your Internal Testing group
2. Click "+" next to Builds
3. Select your processed build
4. Click "Add"
5. Testers receive email invitation

---

#### 6.4 External Testing (Optional)

For testers outside your team:

1. TestFlight → External Testing → Click "+"
2. Create group name
3. Add build
4. Complete Beta App Review information
5. Submit for Beta App Review (first build requires review)
6. After approval, add external testers via email or public link

---

### Phase 7: Testing

#### 7.1 Install TestFlight App

Testers need:
1. Install "TestFlight" from App Store on their device
2. Accept email invitation OR
3. Use public link (external testing only)

---

#### 7.2 Run Smoke Tests

Use `BETA_SMOKETEST.md` checklist:
- [ ] App launches
- [ ] API key setup works
- [ ] Authentication works
- [ ] Dashboard loads
- [ ] Orders display
- [ ] Products display
- [ ] AI Chat responds
- [ ] Voice mode works
- [ ] Settings save

---

### Phase 8: App Store Submission (After Beta)

When ready for public release:

1. **Prepare App Store Listing:**
   - Screenshots (required sizes below)
   - App description
   - Keywords
   - Support URL
   - What's New text

2. **Screenshot Sizes Required:**
   - 6.7" (iPhone 15 Pro Max): 1290 x 2796
   - 6.5" (iPhone 11 Pro Max): 1242 x 2688
   - 5.5" (iPhone 8 Plus): 1242 x 2208
   - 12.9" iPad Pro: 2048 x 2732

3. **Submit for Review:**
   - App Store Connect → Your App → App Store
   - Fill all required fields
   - Add build
   - Submit for Review

4. **Review Time:** Typically 24-48 hours

---

## Troubleshooting

### Archive Fails
- Verify signing team is set
- Check for Swift compiler errors
- Ensure all frameworks are embedded

### Upload Fails
- Check internet connection
- Verify Apple ID has correct permissions
- Try Xcode → Settings → Accounts → refresh

### Build Processing Stuck
- Wait up to 1 hour
- Check App Store Connect system status
- Re-upload if no progress after 2 hours

### TestFlight Invitation Not Received
- Check spam folder
- Verify email address is correct
- Resend invitation from App Store Connect

---

## Quick Reference

### Important URLs
| Resource | URL |
|----------|-----|
| App Store Connect | https://appstoreconnect.apple.com |
| Apple Developer | https://developer.apple.com |
| TestFlight App | App Store on device |
| App Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |

### Key Files in This Repo
| File | Purpose |
|------|---------|
| `LAUNCH_TESTFLIGHT.md` | Status checklist |
| `SECURITY_PRIVACY_REPORT.md` | Security audit |
| `BETA_SMOKETEST.md` | Testing checklist |
| `PRIVACY_POLICY.md` | Privacy policy template |
| `TESTFLIGHT_INSTRUCTIONS.md` | This file |

### Support Contacts
| Role | Contact |
|------|---------|
| App Support | support@365weapons.com |
| Privacy | privacy@365weapons.com |

---

## Summary: What You Need To Do

### Immediate Actions (Before Archive)
1. [ ] **Add app icon** (1024x1024 PNG to Assets.xcassets)
2. [ ] **Set development team** in Xcode Signing & Capabilities
3. [ ] **Rotate API keys** (OpenRouter, OpenAI, Backend)
4. [ ] **Publish privacy policy** to https://365weapons.com/privacy

### App Store Connect Setup
5. [ ] **Create app record** (if first time)
6. [ ] **Add privacy policy URL**
7. [ ] **Complete App Privacy Details** questionnaire

### Build & Upload
8. [ ] **Archive** in Xcode (Product → Archive)
9. [ ] **Upload** to App Store Connect
10. [ ] **Answer export compliance** questions

### TestFlight Distribution
11. [ ] **Create internal testing group**
12. [ ] **Add build to group**
13. [ ] **Invite testers**
14. [ ] **Run smoke tests**

---

**You're ready to proceed! Start with Phase 1: Fix Blockers.**
