# iOS Distribution Guide for Imagine App

## Overview

iOS requires all apps to be code-signed before they can run on devices. Unlike Android, you cannot simply install an unsigned `.ipa` file on an iPhone. This guide explains your options for distributing the app to iPhone users.

## Distribution Options

### 1. **App Store Distribution** (Recommended for Public Release)
**Cost:** $99/year (Apple Developer Program)

**Best for:** Public distribution to all iPhone users

**Requirements:**
- Apple Developer account ($99/year)
- App Store review process
- Compliance with App Store guidelines

**Steps:**
1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/)
2. Open the project in Xcode: `open ios/Runner.xcworkspace`
3. In Xcode, select the Runner target → Signing & Capabilities
4. Select your Team (your Apple Developer account)
5. Xcode will automatically manage provisioning profiles
6. Change the Bundle Identifier from `com.example.imagineApp` to something unique (e.g., `com.yourcompany.imagineapp`)
7. Build for release: `flutter build ipa --release`
8. Upload to App Store Connect using Xcode or `xcrun altool`

### 2. **TestFlight Beta Testing**
**Cost:** $99/year (Apple Developer Program)

**Best for:** Beta testing with up to 10,000 external testers

**Steps:**
1. Follow steps 1-6 from App Store Distribution above
2. Build and upload to TestFlight: `flutter build ipa --release`
3. Upload to App Store Connect
4. Add testers in App Store Connect
5. Testers install via TestFlight app

### 3. **Ad-Hoc Distribution** (Limited Devices)
**Cost:** $99/year (Apple Developer Program)

**Best for:** Testing with specific devices (up to 100 devices per year)

**Steps:**
1. Register device UDIDs in Apple Developer Portal
2. Create Ad-Hoc provisioning profile
3. Build: `flutter build ipa --release --export-method ad-hoc`
4. Distribute the `.ipa` file to registered devices
5. Users install via iTunes/Finder or TestFlight

### 4. **Development Builds** (Personal Devices Only)
**Cost:** Free (with limitations) or $99/year (full features)

**Best for:** Testing on your own devices during development

**Free Account Limitations:**
- Apps expire after 7 days
- Limited to 3 apps per device
- Requires re-signing weekly

**Paid Account Benefits:**
- Apps last 1 year
- No app limit
- Better for development workflow

**Steps:**
1. Open Xcode: `open ios/Runner.xcworkspace`
2. Connect your iPhone via USB
3. Select your device in Xcode
4. Select your Apple ID as the Team (Signing & Capabilities)
5. Xcode will create a free development certificate
6. Build and run: `flutter run` or use Xcode's Run button

## Important Notes

### Bundle Identifier
The current bundle identifier is `com.example.imagineApp`. You **must** change this to a unique identifier before distribution:
- Format: `com.yourcompany.appname` (reverse domain notation)
- Must be unique across the App Store
- Cannot be changed after first App Store submission

### Code Signing
The project is now configured with `CODE_SIGN_STYLE = Automatic`, which means:
- Xcode will automatically manage certificates and provisioning profiles
- You just need to select your Team in Xcode
- No manual certificate management required

### Location Permissions
The app requests location permissions (for Best Buy store finder). Make sure:
- `NSLocationWhenInUseUsageDescription` is set in `Info.plist` ✅ (already configured)
- `NSLocationAlwaysAndWhenInUseUsageDescription` is set ✅ (already configured)
- You explain why location is needed in App Store review

## Quick Start: Testing on Your iPhone

1. **Install Xcode** (if not already installed)
   ```bash
   # On macOS, install from App Store or:
   xcode-select --install
   ```

2. **Open the project in Xcode**
   ```bash
   cd /mnt/main/Software2025/Flutter/ImagineApp
   open ios/Runner.xcworkspace
   ```

3. **Configure Signing**
   - Select "Runner" in the project navigator
   - Go to "Signing & Capabilities" tab
   - Check "Automatically manage signing"
   - Select your Apple ID from the Team dropdown
   - Xcode will create a development certificate automatically

4. **Connect Your iPhone**
   - Connect via USB
   - Trust the computer on your iPhone
   - Select your device in Xcode's device dropdown

5. **Build and Run**
   ```bash
   flutter run
   ```
   Or click the Run button in Xcode

## Troubleshooting

### "No signing certificate found"
- Solution: Select your Team in Xcode's Signing & Capabilities
- Xcode will automatically create a certificate

### "App installation failed"
- Check that your device is registered (for paid accounts)
- For free accounts, apps expire after 7 days - rebuild and reinstall

### "Untrusted Developer" error on device
- Go to Settings → General → VPN & Device Management
- Trust your developer certificate

### Bundle identifier conflicts
- Change the bundle identifier in Xcode (Signing & Capabilities)
- Or edit `ios/Runner.xcodeproj/project.pbxproj` and change `PRODUCT_BUNDLE_IDENTIFIER`

## Next Steps

1. **For Development:** Use the free development signing to test on your devices
2. **For Beta Testing:** Enroll in Apple Developer Program ($99/year) and use TestFlight
3. **For Public Release:** Submit to the App Store through App Store Connect

## Resources

- [Apple Developer Program](https://developer.apple.com/programs/)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Xcode Signing Documentation](https://developer.apple.com/documentation/xcode/managing-signing-assets)

