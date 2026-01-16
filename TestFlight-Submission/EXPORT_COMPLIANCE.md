# Export Compliance Information

## Does your app use encryption?

**Answer: YES** - The app uses HTTPS for network communication

## Encryption Type

The app uses **standard iOS encryption** through:
- HTTPS/TLS for all network requests
- iOS Keychain for secure credential storage
- Standard URLSession networking

## Export Compliance Questionnaire Answers

When uploading to App Store Connect, answer as follows:

### Question 1: Does your app use encryption?
**Yes**

### Question 2: Does your app qualify for any exemptions?
**Yes** - The app qualifies for exemption under:
- Uses standard iOS/Apple encryption APIs only
- Uses HTTPS for network communication
- No custom encryption algorithms

### Question 3: Is your app available in France?
If yes, you may need to submit a declaration to ANSSI (French security agency).
For initial US-only release, select **No**.

## Documentation

### Encryption Used:
1. **TLS 1.2/1.3** - Via URLSession for API calls
2. **iOS Keychain** - For storing API keys securely
3. **HTTPS** - All external communications

### No Custom Encryption:
- No proprietary encryption algorithms
- No custom cryptographic code
- Standard Apple frameworks only

## ECCN Classification

This app qualifies for **ECCN 5D992** exemption as it:
- Uses mass-market encryption
- Is freely available
- Uses standard encryption for authentication only

## Required Actions

1. When uploading build, select "Yes" for encryption
2. Select "Yes" for exemption qualification
3. No additional documentation required for US release
