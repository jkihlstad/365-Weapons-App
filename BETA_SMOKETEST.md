# Beta Smoke Test Plan
## 365Weapons iOS Admin App

**Version:** 1.0 (Build 1)
**Test Environment:** TestFlight Internal Testing
**Minimum iOS:** 17.0

---

## Pre-Test Setup

1. Install app via TestFlight
2. Ensure device has internet connectivity
3. Have test admin credentials ready
4. Configure API keys in Settings (first launch)

---

## Test Cases

### 1. App Launch & First Run
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1.1 | Launch app | Splash screen appears | [ ] |
| 1.2 | First run setup | API key configuration screen shows | [ ] |
| 1.3 | Enter valid keys | Keys save to Keychain | [ ] |
| 1.4 | App proceeds | Main dashboard loads | [ ] |

### 2. Authentication (Clerk)
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 2.1 | Tap login | Clerk auth sheet appears | [ ] |
| 2.2 | Enter credentials | Authentication succeeds | [ ] |
| 2.3 | View profile | User info displays correctly | [ ] |
| 2.4 | Tap logout | Returns to login state | [ ] |
| 2.5 | Re-login | Session persists correctly | [ ] |

### 3. Dashboard
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 3.1 | View dashboard | Stats cards load | [ ] |
| 3.2 | Pull to refresh | Data refreshes | [ ] |
| 3.3 | View revenue | Today's revenue displays | [ ] |
| 3.4 | View orders count | Order count is accurate | [ ] |

### 4. Orders Management
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 4.1 | Navigate to Orders | Orders list loads | [ ] |
| 4.2 | Pull to refresh | List refreshes | [ ] |
| 4.3 | Tap an order | Order details open | [ ] |
| 4.4 | View customer info | Address/contact displays | [ ] |
| 4.5 | Filter by status | Filter works correctly | [ ] |

### 5. Products Management
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 5.1 | Navigate to Products | Products list loads | [ ] |
| 5.2 | Search for product | Search returns results | [ ] |
| 5.3 | View product detail | Product info displays | [ ] |
| 5.4 | Edit product | Changes save | [ ] |

### 6. AI Chat
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 6.1 | Navigate to AI Chat | Chat view loads | [ ] |
| 6.2 | Type message | Input field works | [ ] |
| 6.3 | Send message | Message sends, response appears | [ ] |
| 6.4 | Ask about orders | AI responds with business data | [ ] |
| 6.5 | Clear history | Chat clears | [ ] |

### 7. Voice Mode (AI Chat)
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 7.1 | Tap mic button | Microphone permission prompt | [ ] |
| 7.2 | Grant permission | Voice mode opens | [ ] |
| 7.3 | Record voice | Audio visualizer animates | [ ] |
| 7.4 | Stop recording | Transcription appears | [ ] |
| 7.5 | AI response | TTS speaks response | [ ] |

### 8. Vendors
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 8.1 | Navigate to Vendors | Vendor list loads | [ ] |
| 8.2 | View vendor detail | Vendor info displays | [ ] |

### 9. Customers
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 9.1 | Navigate to Customers | Customer list loads | [ ] |
| 9.2 | Search customer | Search works | [ ] |
| 9.3 | View customer detail | Customer info displays | [ ] |

### 10. Settings
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 10.1 | Navigate to Settings | Settings screen loads | [ ] |
| 10.2 | View API key status | Key statuses show (masked) | [ ] |
| 10.3 | Update API key | Key updates in Keychain | [ ] |
| 10.4 | Toggle setting | Setting persists | [ ] |

### 11. Tab Bar Navigation
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 11.1 | Scroll tab bar | Horizontal scroll works | [ ] |
| 11.2 | Tap each tab | Navigation works | [ ] |
| 11.3 | Glass effect | Tab bar has blur effect | [ ] |

### 12. Offline Behavior
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 12.1 | Disable network | Offline indicator shows | [ ] |
| 12.2 | Try to load data | Error message displays | [ ] |
| 12.3 | Re-enable network | Data loads on retry | [ ] |

### 13. Error Handling
| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 13.1 | Invalid API key | Clear error message | [ ] |
| 13.2 | Network timeout | Timeout error shown | [ ] |
| 13.3 | Auth expired | Re-auth prompt | [ ] |

---

## Device Testing Matrix

| Device | iOS Version | Status |
|--------|-------------|--------|
| iPhone 15 Pro | iOS 17.0+ | [ ] |
| iPhone 14 | iOS 17.0+ | [ ] |
| iPad Pro | iOS 17.0+ | [ ] |

---

## Known Issues

1. _List any known issues here before release_
2. _Example: Voice mode may not work on iPad_

---

## Test Results Summary

| Category | Pass | Fail | Blocked |
|----------|------|------|---------|
| Authentication | /5 | | |
| Dashboard | /4 | | |
| Orders | /5 | | |
| Products | /4 | | |
| AI Chat | /5 | | |
| Voice Mode | /5 | | |
| Settings | /4 | | |
| Navigation | /3 | | |
| **Total** | /35 | | |

---

## Sign-Off

| Tester | Date | Build | Result |
|--------|------|-------|--------|
| | | 1.0 (1) | |

**Go/No-Go:** [ ] GO / [ ] NO-GO

**Notes:**
