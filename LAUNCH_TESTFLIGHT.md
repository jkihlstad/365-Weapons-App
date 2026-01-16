# TestFlight Launch Checklist
## 365Weapons iOS Admin App

**App Name:** 365 Weapons Admin
**Bundle ID:** com.weapons365.admin
**Version:** 1.0
**Build:** 1
**Repository:** 365-Weapons-IOS-Admin
**Assessment Date:** 2026-01-15

---

## CURRENT STATUS: CONDITIONAL GO

### Remaining Items
| Issue | Severity | Owner | Status |
|-------|----------|-------|--------|
| ~~Hardcoded secrets in DefaultKeys.swift~~ | ~~CRITICAL~~ | Security Engineer | **FIXED** |
| Rotate exposed API keys | High | Security Engineer | PENDING |
| Privacy Policy URL not added | Medium | Compliance Manager | PENDING |
| App Privacy Details not completed | Medium | Compliance Manager | PENDING |

**Security blocker resolved.** Proceed with key rotation and compliance items.

---

## Release Manifest

| Field | Value |
|-------|-------|
| Marketing Version | 1.0 |
| Build Number | 1 |
| Git SHA | bebdc55a820060ea9b0af73274b59c38569efdee |
| Environment | Production |
| Min iOS | 17.0 |
| Supported Devices | iPhone, iPad |

### Feature Flags
- Clerk Auth: Enabled (optional, graceful fallback)
- AI Chat: Enabled
- Voice Mode: Enabled
- Offline Mode: Basic support

---

## Pre-Flight Checklist

### Phase 1: Repo Readiness
| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Remove hardcoded secrets | Security Engineer | **PASS** | DefaultKeys.swift cleared |
| Verify .gitignore | Security Engineer | PASS | DefaultKeys.swift is gitignored |
| Confirm Release config | Build Engineer | PASS | Release is default |
| Set Bundle ID | Build Engineer | PASS | com.weapons365.admin |
| Set Version/Build | Build Engineer | PASS | 1.0 / 1 |

### Phase 2: Signing & Archive
| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Configure Development Team | Build Engineer | PENDING | Need Team ID in Xcode |
| Set signing style | Build Engineer | DONE | Automatic (or Manual for prod) |
| Archive succeeds | Build Engineer | PENDING | |
| Upload succeeds | Build Engineer | PENDING | |
| Build visible in ASC | Build Engineer | PENDING | |

### Phase 3: App Store Connect Setup
| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| App record exists | Compliance Manager | PENDING | Create if first time |
| Bundle ID matches | Compliance Manager | PENDING | com.weapons365.admin |
| Internal group created | Compliance Manager | PENDING | |
| Testers invited | Compliance Manager | PENDING | |

### Phase 4: Compliance & Privacy
| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Export compliance answered | Compliance Manager | PENDING | Yes, uses HTTPS |
| Privacy policy URL added | Compliance Manager | PENDING | https://365weapons.com/privacy |
| App Privacy Details completed | Compliance Manager | PENDING | See SECURITY_PRIVACY_REPORT.md |

### Phase 5: Beta Testing
| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Install via TestFlight | QA Lead | PENDING | |
| Run smoke tests | QA Lead | PENDING | See BETA_SMOKETEST.md |
| Log known issues | QA Lead | PENDING | |
| Fix blockers | Dev Team | PENDING | |

### Phase 6: External Testing (Optional)
| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Beta description added | Compliance Manager | PENDING | |
| Beta review info complete | Compliance Manager | PENDING | |
| External group created | Compliance Manager | PENDING | |
| Submit for Beta App Review | Compliance Manager | PENDING | |

---

## Archive & Upload Instructions

### Option A: Xcode GUI
```
1. Open 365WeaponsAdmin.xcodeproj
2. Select "Any iOS Device (arm64)" as destination
3. Product → Archive
4. Wait for archive to complete
5. Organizer opens → Select archive
6. Distribute App → App Store Connect → Upload
7. Wait for processing in App Store Connect
```

### Option B: Command Line
```bash
# Clean build folder
xcodebuild clean -scheme 365WeaponsAdmin

# Archive
xcodebuild archive \
  -scheme 365WeaponsAdmin \
  -archivePath ./build/365WeaponsAdmin.xcarchive \
  -configuration Release

# Export for App Store
xcodebuild -exportArchive \
  -archivePath ./build/365WeaponsAdmin.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist ExportOptions.plist

# Upload (requires App Store Connect API key)
xcrun altool --upload-app \
  -f ./build/export/365WeaponsAdmin.ipa \
  -t ios \
  --apiKey <KEY_ID> \
  --apiIssuer <ISSUER_ID>
```

---

## App Store Connect: App Privacy Details

### Data Types to Declare

| Data Type | Collected | Linked | Tracking | Purpose |
|-----------|-----------|--------|----------|---------|
| Email Address | Yes | Yes | No | App Functionality |
| Name | Yes | Yes | No | App Functionality |
| User ID | Yes | Yes | No | App Functionality |
| Audio Data | Yes | No | No | App Functionality (Voice) |

### Third-Party SDK Disclosures
- **Clerk:** Contact Info (Email, Name) for authentication
- **OpenAI:** Audio data for speech-to-text (not linked to user)

---

## Rollback Plan

### If Build is Rejected
1. Read rejection reason in App Store Connect
2. Create fix branch: `git checkout -b fix/testflight-rejection`
3. Fix issues
4. Increment build number: 1 → 2
5. Re-archive and upload
6. Merge fix to main after approval

### If Critical Bug Found
1. Remove build from TestFlight
2. Create hotfix branch
3. Fix and increment build
4. Re-upload
5. Re-invite testers

---

## Go/No-Go Criteria

### Must Pass (Blockers)
- [x] **No secrets in app binary** (FIXED - DefaultKeys.swift cleared)
- [ ] Archive succeeds without signing errors
- [ ] Upload succeeds to App Store Connect (NOT TESTED)
- [ ] Build appears in TestFlight (NOT TESTED)
- [ ] Internal testers can install (NOT TESTED)
- [ ] App launches without crash (NOT TESTED)
- [ ] Authentication works (NOT TESTED)
- [ ] Core features functional (NOT TESTED)

### Should Pass (Warnings)
- [ ] Privacy policy URL added
- [ ] App Privacy Details completed
- [ ] All smoke tests pass
- [ ] No console errors in release build
- [ ] Memory usage acceptable
- [ ] UI renders correctly on all device sizes

---

## Final Sign-Off

| Role | Name | Status | Date |
|------|------|--------|------|
| Build & Signing Engineer | | BLOCKED | 2026-01-15 |
| Compliance Manager | | PENDING | 2026-01-15 |
| QA Lead | | BLOCKED | 2026-01-15 |
| Security Engineer | | **PASS** | 2026-01-15 |
| **Orchestration Agent** | Claude | **CONDITIONAL GO** | 2026-01-15 |

### Decision
- [x] **CONDITIONAL GO** - Proceed after rotating keys and adding privacy policy
- [ ] **NO-GO** - Address blockers first

**Resolved:** DefaultKeys.swift cleared of all secrets.

**Remaining before archive:**
1. Rotate exposed API keys (OpenRouter, OpenAI, Backend Auth)
2. Add privacy policy URL to App Store Connect
3. Complete App Privacy Details

---

## Post-Launch Tasks

1. Monitor TestFlight feedback
2. Check crash reports in Xcode Organizer
3. Collect tester feedback
4. Plan for App Store submission (if external testing passes)

---

## Contact Information

| Role | Contact |
|------|---------|
| Support Email | support@365weapons.com |
| Developer | (add contact) |
| Apple Developer Account | (add team admin) |
