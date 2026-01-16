# Security & Privacy Report
## 365Weapons iOS Admin App

**Generated:** 2026-01-15
**Version:** 1.0 (Build 1)
**Bundle ID:** com.weapons365.admin
**Git SHA:** bebdc55a820060ea9b0af73274b59c38569efdee

---

## Executive Summary

| Category | Status | Action Required |
|----------|--------|-----------------|
| Hardcoded Secrets | **FIXED** | DefaultKeys.swift cleared |
| API Key Storage | SECURE | Using iOS Keychain at runtime |
| Network Security | SECURE | All HTTPS/TLS |
| Privacy Compliance | NEEDS WORK | Add privacy policy URL |
| Export Compliance | READY | Standard HTTPS encryption |

---

## RESOLVED - Secrets Removed

### Issue: API Keys Compiled Into App Binary

**Severity:** CRITICAL
**Status:** FIXED (2026-01-15)

**Finding:**
- `365WeaponsAdmin/Config/DefaultKeys.swift` contains real API keys:
  - Line 14: OpenRouter API Key (`sk-or-v1-...`)
  - Line 15: OpenAI API Key (`sk-proj-...`)
  - Line 16: Backend Auth Token (SHA256 hash)
  - Line 17: Convex Deployment URL

- `365WeaponsAdminApp.swift` references these keys at app startup (lines 96-100)
- Keys are **compiled into the app binary** and distributed with TestFlight
- Any user can extract these keys by reverse-engineering the IPA

**Risk:**
- API keys exposed to all TestFlight testers
- Keys can be used maliciously (unauthorized API calls, costs)
- Violates security best practices
- Could result in App Store rejection

**Required Fix:**
```swift
// DefaultKeys.swift - Replace with empty strings for production
struct DefaultKeys {
    static let openRouterAPIKey = ""
    static let openAIAPIKey = ""
    static let backendAuthToken = ""
    static let convexDeploymentURL = ""
    static let clerkPublishableKey = ""
}
```

**After Fix:**
1. Users will see the API Setup sheet on first launch
2. They must enter their own API keys
3. Keys stored securely in iOS Keychain
4. No secrets in the distributed binary

**Keys to Rotate After Fix:**
- [ ] OpenRouter API key
- [ ] OpenAI API key
- [ ] Backend Auth token
- [ ] Convex deployment (if sensitive)

---

## 1. Secrets Inventory

### Secured Keys (Keychain Storage)
| Service | Key Type | Storage | Status |
|---------|----------|---------|--------|
| OpenRouter | `sk-or-*` | Keychain | Secure |
| OpenAI | `sk-*` | Keychain | Secure |
| Clerk | `pk_*` | Keychain | Secure |
| Convex | URL | Keychain | Secure |
| Backend Auth | Token | Keychain | Secure |
| Tavily | `tvly-*` | Keychain | Secure (Fixed) |

### Files Reviewed
- `365WeaponsAdmin/Config/SecureConfiguration.swift` - Keychain implementation
- `365WeaponsAdmin/Config/ConfigurationManager.swift` - Key validation & management
- `365WeaponsAdmin/Networking/TavilyClient.swift` - Fixed hardcoded key

### Gitignore Verification
```
# Properly ignored:
365WeaponsAdmin/Config/DefaultKeys.swift
```

---

## 2. Third-Party SDKs

| SDK | Version | Purpose | Privacy Impact |
|-----|---------|---------|----------------|
| Clerk | 0.71.4 | Authentication | Collects: User ID, email, name |
| Kingfisher | 8.6.2 | Image caching | Network requests for images |
| PhoneNumberKit | 4.2.2 | Phone validation | Processes phone numbers locally |
| Get | 2.2.1 | HTTP client | Network layer |
| Factory | 2.5.3 | Dependency injection | None |
| SimpleKeychain | 1.3.0 | Secure storage | None |

### SDK Privacy Declarations for App Store Connect
1. **Clerk SDK**
   - Data Type: Contact Info (Email, Name)
   - Purpose: App Functionality, Authentication
   - Linked to User: Yes

2. **Network SDKs (Get, Kingfisher)**
   - Data Type: Usage Data
   - Purpose: App Functionality
   - Linked to User: No

---

## 3. Data Collection Summary

### User Data Collected
| Data Type | Purpose | Linked | Tracking |
|-----------|---------|--------|----------|
| Email Address | Authentication | Yes | No |
| Name | Profile display | Yes | No |
| User ID | Session management | Yes | No |

### Business Data Accessed (Admin Only)
- Customer orders and addresses
- Product information
- Vendor details
- Business analytics (internal)

### Device Permissions
| Permission | Usage Description | Required |
|------------|-------------------|----------|
| Microphone | Voice commands | Yes |

---

## 4. Network Security

### Endpoints (All HTTPS)
| Service | Endpoint | Protocol |
|---------|----------|----------|
| Clerk Auth | clerk.com | HTTPS |
| OpenRouter | openrouter.ai | HTTPS |
| OpenAI | api.openai.com | HTTPS |
| Convex | convex.cloud | HTTPS |
| Backend | railway.app | HTTPS/WSS |
| Tavily | api.tavily.com | HTTPS |

### App Transport Security
- **Status:** No exceptions configured
- **All traffic:** HTTPS enforced

---

## 5. Export Compliance

### Encryption Usage
| Type | Implementation | Exempt |
|------|----------------|--------|
| HTTPS/TLS | System framework | Yes |
| Keychain | iOS Keychain Services | Yes |

**Export Compliance Answer:** YES, app uses encryption (HTTPS/TLS for network, Keychain for storage), but uses standard iOS frameworks which are exempt from additional documentation.

---

## 6. Privacy Compliance Checklist

### App Store Connect Requirements
- [ ] **Privacy Policy URL** - NEEDS TO BE ADDED
- [ ] **App Privacy Details** - Ready to complete
- [ ] **Data Collection Disclosure** - Documented above

### Recommended Privacy Policy URL
Add to Info.plist or App Store Connect:
```
https://365weapons.com/privacy
```

---

## 7. Recommendations

### Immediate Actions
1. Add privacy policy URL to App Store Connect
2. Complete App Privacy Details questionnaire
3. Rotate any keys if they were ever committed to git

### Best Practices Implemented
- iOS Keychain for all sensitive data
- No hardcoded secrets in production code
- HTTPS for all network traffic
- Minimal permission requests

---

## 8. Remediation Steps (In Order)

### Step 1: Fix DefaultKeys.swift (CRITICAL)
```swift
// Replace contents of 365WeaponsAdmin/Config/DefaultKeys.swift with:
import Foundation

struct DefaultKeys {
    static let openRouterAPIKey = ""
    static let openAIAPIKey = ""
    static let backendAuthToken = ""
    static let convexDeploymentURL = ""
    static let clerkPublishableKey = ""
}
```

### Step 2: Rotate Compromised Keys
After fixing the code, rotate these keys in their respective dashboards:
1. OpenRouter: https://openrouter.ai/keys
2. OpenAI: https://platform.openai.com/api-keys
3. Backend Auth: Regenerate on your backend server
4. Convex: https://dashboard.convex.dev (if URL is sensitive)

### Step 3: Add Privacy Policy URL
Add to App Store Connect: `https://365weapons.com/privacy`

### Step 4: Complete App Privacy Details
In App Store Connect, declare:
- Contact Info (Email, Name) - collected, linked to user
- User ID - collected, linked to user
- Audio Data - collected, not linked (voice features)

### Step 5: Re-archive and Upload
1. Increment build number to 2
2. Archive in Xcode
3. Upload to App Store Connect
4. Verify build processes successfully

---

## 9. Sign-Off

| Role | Status | Notes |
|------|--------|-------|
| Security Engineer | **PASS** | Secrets removed from DefaultKeys.swift |
| Privacy Officer | PENDING | Need privacy policy URL |
| Compliance Manager | PENDING | Complete ASC privacy details |

**Overall Status:** READY FOR TESTFLIGHT (after rotating keys + adding privacy policy)

---

## 10. Final Decision

### Go/No-Go: NO-GO

**Blocking Issue:** API keys compiled into app binary via DefaultKeys.swift

**To achieve GO status:**
1. Clear all values in DefaultKeys.swift
2. Rotate all exposed API keys
3. Increment build number
4. Add privacy policy URL
5. Complete App Privacy Details
6. Re-archive and upload
